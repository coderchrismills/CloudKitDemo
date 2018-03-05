//
//  CloudKitSupport.swift
//  CloudKitDemo
//
//  Created by Chris on 3/3/18.
//  Copyright © 2018 Chris. All rights reserved.
//

import CloudKit
import UIKit

struct CKIdentifiers {
    static let house = "House"
    static let houseZone = "HouseZone"
    static let address = "address"
    static let comments = "comments"
    static let photo = "photo"
}

class House {
    var address: String = ""
    var comments: String = ""
    var photoURL: URL?
    var recordID: CKRecordID?
    var isShared: Bool = false
    
    init() { }
    init(address: String, comments: String, photoURL: URL?) {
        self.address = address
        self.comments = comments
        self.photoURL = photoURL
    }
    
    func update(with record: CKRecord?) {
        guard let record = record else { return }
        
        recordID = record.recordID
        isShared = record.share != nil
        
        if let address = record.object(forKey: CKIdentifiers.address) as? String {
            self.address = address
        }
        
        if let comments = record.object(forKey: CKIdentifiers.comments) as? String {
            self.comments = comments
        }

        guard let photo = record.object(forKey: CKIdentifiers.photo) as? CKAsset else { return }
        guard let image = UIImage(contentsOfFile: photo.fileURL.path) else { return }
        
        self.photoURL = image.saveToFile()
    }
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
    var currentRecord: CKRecord?
    
    private init() {
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        recordZone = CKRecordZone(zoneName: CKIdentifiers.houseZone)
    }
    
    func initialize() {
        privateDatabase.save(recordZone) { (recordzone, error) in
            if let err = error {
                print(err.localizedDescription)
                return
            }
            print("Save record zone")
        }
        
        subscribeToRemoteNotifications()
    }
    
    func subscribeToRemoteNotifications() {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: CKIdentifiers.house,
                                               predicate: predicate,
                                               options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let notificationInfo = CKNotificationInfo()
        subscription.notificationInfo = notificationInfo

        privateDatabase.save(subscription) { record, error in
            if let err = error {
                print(err.localizedDescription)
                return
            }
            print("Save record subscription")
        }
        
        sharedDatabase.save(subscription) { record, error in
            if let err = error {
                print(err.localizedDescription)
                return
            }
            print("Save record subscription")
        }

    }
    
    func save(_ house: House) {
        let record = CKRecord(recordType: CKIdentifiers.house, zoneID: recordZone.zoneID)
        record.setObject(house.address as CKRecordValue?, forKey: CKIdentifiers.address)
        record.setObject(house.comments as CKRecordValue?, forKey: CKIdentifiers.comments)
        
        if let url = house.photoURL {
            let asset = CKAsset(fileURL: url)
            record.setObject(asset, forKey: CKIdentifiers.photo)
        }
        
        let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        
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
                if let err = error {
                    print(err.localizedDescription)
                } else {
                    DispatchQueue.main.async {
                        print("Record saved successfully")
                    }
                    self.currentRecord = record
                }
        }
        privateDatabase.add(modifyRecordsOperation)
    }
    
    func update(_ house: House) {
        guard let record = currentRecord else { return }
        
        let database = record.share == nil ? privateDatabase : sharedDatabase
        record.setObject(house.address as CKRecordValue?, forKey: CKIdentifiers.address)
        record.setObject(house.comments as CKRecordValue?, forKey: CKIdentifiers.comments)
        
        if let url = house.photoURL {
            let asset = CKAsset(fileURL: url)
            record.setObject(asset, forKey: CKIdentifiers.photo)
        }
        
        database.save(record) { record, error in
            if let err = error {
                print(err.localizedDescription)
            } else {
                DispatchQueue.main.async {
                    print("Record saved successfully")
                }
                self.currentRecord = record
            }
        }
    }
    
    func delete() {
        guard let record = currentRecord else { return }
        privateDatabase.delete(withRecordID: record.recordID) { record, error in
            if let err = error {
                print(err.localizedDescription)
            } else {
                DispatchQueue.main.async {
                    print("Record saved successfully")
                }
                self.currentRecord = nil
            }
        }
    }
    
    func query(address: String, onCompletion: @escaping (CKRecord)->()) {
        let predicate = NSPredicate(format: "address = %@", address)
        let query = CKQuery(recordType: CKIdentifiers.house, predicate: predicate)
        guard let zid = sharedZone?.zoneID else { return }
        sharedDatabase.perform(query, inZoneWith: zid) { results, error in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            
            guard let results = results else { return }
            guard results.count > 0 else { return }
            
            let record = results[0]
            self.currentRecord = record
            onCompletion(record)
        }
    }
    
    func handleQueryNotification(_ notification: CKQueryNotification) {
        guard let recordID = notification.recordID else { return }
        fetch(for: recordID, shared: notification.databaseScope == .shared)
    }
    
    func fetchRecordZones(for database: CKDatabase, onCompletion: @escaping ([CKRecordZone])->()) {
        database.fetchAllRecordZones { (recordZones, error) in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            
            if let zones = recordZones {
                onCompletion(zones)
            }
        }
    }
    
    func fetch(for recordID: CKRecordID, shared: Bool) {
        let database = shared ? sharedDatabase : privateDatabase
        database.fetch(withRecordID: recordID) { record, error in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            
            self.currentRecord = record
            NotificationCenter.default.post(name: .onRecordFetchComplete, object: nil)
        }
    }
    
    func fetchShare(for recordMetaData: CKShareMetadata) {
        fetch(for: recordMetaData.rootRecordID, shared: true)
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
    
    func share(with vc: ViewController) {
        let controller = UICloudSharingController { controller, preparationCompletionHandler in
            let share = CKShare(rootRecord: self.currentRecord!)
            
            share[CKShareTitleKey] = "An Amazing House" as CKRecordValue
            share.publicPermission = .readWrite
            
            let modifyRecordsOperation = CKModifyRecordsOperation(
                recordsToSave: [self.currentRecord!, share],
                recordIDsToDelete: nil)
            
            modifyRecordsOperation.timeoutIntervalForRequest = 10
            modifyRecordsOperation.timeoutIntervalForResource = 10
            
            modifyRecordsOperation.modifyRecordsCompletionBlock = {
                records, recordIDs, error in
                guard error == nil else {
                    print(error!.localizedDescription)
                    return
                }
                preparationCompletionHandler(share, self.container, error)
            }
            self.privateDatabase.add(modifyRecordsOperation)
        }
        
        controller.availablePermissions = [.allowPublic, .allowReadOnly]
        //controller.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        
        vc.present(controller, animated: true)
    }
}
