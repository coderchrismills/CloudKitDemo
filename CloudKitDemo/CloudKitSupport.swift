//
//  CloudKitSupport.swift
//  CloudKitDemo
//
//  Created by Chris on 3/3/18.
//  Copyright © 2018 Chris. All rights reserved.
//

import CloudKit
import UIKit

struct CKSubscriptionIdentifiers {
    static let privateDatabase = "Private"
    static let sharedDatabase = "Shared"
    static let customZone = "CustomZone"
}

extension Notification.Name {
    static let onRecordFetchComplete = Notification.Name(rawValue: "OnRecordFetchComplete")
}

class CloudKitSupport {
    static let shared = CloudKitSupport()
    
    let container = CKContainer.default()
    var privateDatabase: CKDatabase
    var sharedDatabase: CKDatabase
    var recordZone: CKRecordZone
    var sharedZone: CKRecordZone?
    
    private init() {
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        recordZone = CKRecordZone(zoneName: CKSubscriptionIdentifiers.customZone)
    }
    
    func initialize(onCompletion: @escaping ()->()) {
        privateDatabase.save(recordZone) { (recordzone, error) in
            guard CloudKitError.shared.handle(error: error, operation: .modifyZones, alert: true) == nil else { return }
            print("Save record zone")
            onCompletion();
            self.subscribeToRemoteNotifications()
        }
    }
    
    func subscribeToRemoteNotifications() {
        let predicate = NSPredicate(value: true)
        let options: CKQuerySubscriptionOptions = [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        
        let types = [Schema.RecordType.plant, Schema.RecordType.note, Schema.RecordType.photo]
        for type in types {
            let subscription = CKQuerySubscription(recordType: type,
                                                   predicate: predicate,
                                                   subscriptionID: type,
                                                   options: options)
            
            subscription.notificationInfo = notificationInfo
            privateDatabase.save(subscription) { record, error in
                guard CloudKitError.shared.handle(error: error, operation: .modifySubscriptions) == nil else { return }
                print("Save record subscription")
            }
        }

        let dbSubscription = CKDatabaseSubscription(subscriptionID: CKSubscriptionIdentifiers.customZone)
        dbSubscription.notificationInfo = notificationInfo
        privateDatabase.save(dbSubscription) { record, error in
            guard CloudKitError.shared.handle(error: error, operation: .modifySubscriptions) == nil else { return }
            print("Save database subscription")
        }
        
        let sharedSubscription = CKDatabaseSubscription(subscriptionID: CKSubscriptionIdentifiers.sharedDatabase)
        sharedSubscription.notificationInfo = notificationInfo
        
        sharedDatabase.save(sharedSubscription) { record, error in
            guard CloudKitError.shared.handle(error: error, operation: .modifySubscriptions) == nil else { return }
            print("Save shared database subscription")
        }

    }
    
    func save(_ record: Record, onCompletion:@escaping ()->()) {
        guard record.recordType != "" else { return }
        let ckRecord = CKRecord(recordType: record.recordType, zoneID: recordZone.zoneID)
        record.save(to: ckRecord)
        
        let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [ckRecord], recordIDsToDelete: nil)
        
        if #available(iOS 11.0, *) {
            let config = CKOperationConfiguration()
            config.qualityOfService = .userInitiated
            config.timeoutIntervalForRequest = 10
            config.timeoutIntervalForResource = 10
            modifyRecordsOperation.configuration = config
        } else {
            modifyRecordsOperation.timeoutIntervalForRequest = 10
            modifyRecordsOperation.timeoutIntervalForResource = 10
            modifyRecordsOperation.qualityOfService = .userInitiated
        }
        
        modifyRecordsOperation.modifyRecordsCompletionBlock = { records, recordIDs, error in
            guard CloudKitError.shared.handle(error: error, operation: .modifyRecords, affectedObjects: recordIDs) == nil else { return }
            guard let records = records else { return }
            guard records.count > 0 else { return }
            record.update(with: records[0])
            Records.shared.records.append(record)
            onCompletion()
        }
        privateDatabase.add(modifyRecordsOperation)
    }
    
    func update(_ record: Record) {
        guard let ckRecord = record.ckRecord else { return }
        
        let isShared = ckRecord.share != nil
        let isOwner = ckRecord.recordID.zoneID.ownerName == CKCurrentUserDefaultName
        let database = (isShared && !isOwner) ? sharedDatabase : privateDatabase
        
        record.save(to: ckRecord)
        
        database.save(ckRecord) { savedRecord, error in
            guard let savedRecord = savedRecord else { return }
            guard CloudKitError.shared.handle(error: error, operation: .modifyRecords, affectedObjects: [savedRecord]) == nil else { return }
            record.update(with: savedRecord)
        }
    }
    
    func delete(record: Record) {
        guard let ckRecord = record.ckRecord else { return }
        privateDatabase.delete(withRecordID: ckRecord.recordID) { recordId, error in
            guard let recordId = recordId else { return }
            guard CloudKitError.shared.handle(error: error, operation: .deleteRecords, affectedObjects: [recordId]) == nil else { return }
            record.ckRecord = nil
        }
    }
    
    func query(predicate: NSPredicate, onCompletion: @escaping (CKRecord)->()) {
        //let predicate = NSPredicate(format: "address = %@", address)
        let query = CKQuery(recordType: CKSubscriptionIdentifiers.privateDatabase, predicate: predicate)
        
        privateDatabase.perform(query, inZoneWith: recordZone.zoneID) { results, error in
            guard CloudKitError.shared.handle(error: error, operation: .fetchRecords) == nil else { return }
            guard let results = results else { return }
            guard results.count > 0 else { return }
            
            let record = results[0]
            onCompletion(record)
        }
        
        guard let zid = sharedZone?.zoneID else { return }
        sharedDatabase.perform(query, inZoneWith: zid) { results, error in
            guard CloudKitError.shared.handle(error: error, operation: .fetchRecords) == nil else { return }
            guard let results = results else { return }
            guard results.count > 0 else { return }
            
            let record = results[0]
            onCompletion(record)
        }
    }
    
    func handleQueryNotification(_ notification: CKQueryNotification) {
        guard let recordID = notification.recordID else { return }
        fetch(for: recordID, shared: notification.databaseScope == .shared)
    }
    
    var changeToken: CKServerChangeToken?
    var recordChangeToken: CKServerChangeToken?
    func handleDatabaseNotification(_ notification: CKDatabaseNotification) {
        let database = notification.databaseScope == .shared ? sharedDatabase : privateDatabase
        
        let dbChanges = CKFetchDatabaseChangesOperation()
        dbChanges.fetchAllChanges = true
        dbChanges.previousServerChangeToken = changeToken
        dbChanges.fetchDatabaseChangesCompletionBlock = { token, _, error in
            guard CloudKitError.shared.handle(error: error, operation: .fetchChanges) == nil else { return }
            self.changeToken = token
        }
        
        dbChanges.recordZoneWithIDChangedBlock = { recordZoneId in
            let options = CKFetchRecordZoneChangesOptions()
            options.previousServerChangeToken = self.recordChangeToken
            let zoneChanges = CKFetchRecordZoneChangesOperation(recordZoneIDs: [recordZoneId], optionsByRecordZoneID: [recordZoneId:options])
            zoneChanges.fetchRecordZoneChangesCompletionBlock = { error in
                guard CloudKitError.shared.handle(error: error, operation: .fetchChanges) == nil else { return }
            }
            zoneChanges.fetchAllChanges = false
            zoneChanges.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
                self.recordChangeToken = token
            }
            zoneChanges.recordChangedBlock = { ckRecord in
                self.addOrUpdate(ckRecord)
                NotificationCenter.default.post(name: .onRecordFetchComplete, object: nil)
            }
            database.add(zoneChanges)
        }
        database.add(dbChanges)
    }
    
    func fetchRecordZones(for database: CKDatabase, onCompletion: @escaping ([CKRecordZone])->()) {
        database.fetchAllRecordZones { (recordZones, error) in
            guard CloudKitError.shared.handle(error: error, operation: .fetchZones) == nil else { return }
            guard let zones = recordZones else { return }
            onCompletion(zones)
        }
    }
    
    func fetch(for recordID: CKRecordID, shared: Bool) {
        let database = shared ? sharedDatabase : privateDatabase
        database.fetch(withRecordID: recordID) { record, error in
            guard CloudKitError.shared.handle(error: error, operation: .fetchRecords, affectedObjects: [recordID]) == nil else { return }
            guard let record = record else { return }
            self.addOrUpdate(record)
            NotificationCenter.default.post(name: .onRecordFetchComplete, object: nil)
        }
    }
    
    func fetchShare(for recordMetaData: CKShareMetadata) {
        fetch(for: recordMetaData.rootRecordID, shared: true)
    }
    
    func fetchAllOwnedPlants(onFetchComplete: @escaping ([PlantRecord])->()) {
        let query = CKQuery(recordType: Schema.RecordType.plant, predicate: NSPredicate(value: true))
        privateDatabase.perform(query, inZoneWith: recordZone.zoneID) { records, error in
            guard CloudKitError.shared.handle(error: error, operation: .fetchRecords) == nil else { return }
            guard let records = records else { return }

            let plants:[PlantRecord] = records.map {
                let p = PlantRecord()
                p.update(with: $0)
                return p
            }
            onFetchComplete(plants)
        }
    }
    
    func addOrUpdate(_ item: CKRecord) {
        if let record = Records.shared.record(for: item) {
            record.update(with: item)
        } else {
            // TODO: check the type of the incoming record
            if item.recordType == Schema.RecordType.plant {
                let p = PlantRecord()
                p.plant = Plant()
                p.update(with: item)
                Records.shared.records.append(p)
            }
        }
    }
    
    func acceptShare(for recordMetaData: CKShareMetadata) {
        if (sharedZone == nil) {
            fetchRecordZones(for: sharedDatabase) { zones in
                if (zones.count > 0) {
                    self.sharedZone = zones[0]
                }
            }
        }
        
        fetchShare(for: recordMetaData)
    }
    
    func share(_ record: Record, with vc: ViewController) {
        guard let ckRecord = record.ckRecord else { return }
        let controller = UICloudSharingController { controller, preparationCompletionHandler in
            let share = CKShare(rootRecord: ckRecord)
            
            share[CKShareTitleKey] = "An Amazing Plant" as CKRecordValue
            share.publicPermission = .readWrite
            
            let modifyRecordsOperation = CKModifyRecordsOperation(
                recordsToSave: [ckRecord, share],
                recordIDsToDelete: nil)
            
            modifyRecordsOperation.timeoutIntervalForRequest = 10
            modifyRecordsOperation.timeoutIntervalForResource = 10
            
            modifyRecordsOperation.modifyRecordsCompletionBlock = { _, _, error in
                guard CloudKitError.shared.handle(error: error, operation: .fetchRecords) == nil else { return }
                preparationCompletionHandler(share, self.container, error)
            }
            self.privateDatabase.add(modifyRecordsOperation)
        }
        
        controller.availablePermissions = [.allowPublic, .allowReadOnly]
        //controller.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        
        vc.present(controller, animated: true)
    }
}
