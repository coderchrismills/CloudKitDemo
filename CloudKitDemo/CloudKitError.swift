/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A class to handle CloudKit errors.
 */

import UIKit
import CloudKit

// Due to the asynchronous nature of the CloudKit framework. Every API that needs to reach to the server
// can fail (for networking issue, for example).
// This class is to handle errors as much as possible based on the operation type, or preprocess the error data
// and pass back to caller for further actions.
//
class CloudKitError {
    
    // Operation types that identifying what is doing.
    //
    enum Operation: String {
        case accountStatus = "AccountStatus"// Doing account check with CKContainer.accountStatus.
        case fetchRecords = "FetchRecords"  // Fetching data from the CloudKit server.
        case modifyRecords = "ModifyRecords"// Modifying records (.serverRecordChanged should be handled).
        case deleteRecords = "DeleteRecords"// Deleting records.
        case modifyZones = "ModifyZones"    // Modifying zones (.serverRecordChanged should be handled).
        case deleteZones = "DeleteZones"    // Deleting zones.
        case fetchZones = "FetchZones"      // Fetching zones.
        case modifySubscriptions = "ModifySubscriptions"    // Modifying subscriptions.
        case deleteSubscriptions = "DeleteSubscriptions"    // Deleting subscriptions.
        case fetchChanges = "FetchChanges"  // Fetching changes (.changeTokenExpired should be handled).
        case markRead = "MarkRead"          // Doing CKMarkNotificationsReadOperation.
        case acceptShare = "AcceptShare"    // Doing CKAcceptSharesOperation.
    }
    
    // Dictioanry keys for error handling result that would be returned to clients.
    //
    enum Result {
        case ckError, nsError
    }
    
    static let shared = CloudKitError()
    private init() {} // Prevent clients from creating another instance.
    
    lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    // Error handling: partial failure caused by .serverRecordChanged can normally be ignored.
    // the CKError is returned so clients can retrieve more information from there.
    //
    // Return the ckError when the first partial error is hit, so only handle the first error.
    // Return nil if the error is not handled.
    //
    fileprivate func handlePartialError(nsError: NSError, affectedObjects: [Any]?) -> CKError? {
        
        guard let partialErrorInfo = nsError.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary,
            let editingObjects = affectedObjects else {return nil}
        
        for editingObject in editingObjects {
            
            guard let ckError = partialErrorInfo[editingObject] as? CKError else {continue}
            
            if ckError.code == .serverRecordChanged {
                print("Editing object already exists. Normally use serverRecord and ignore this error!")
            }
            else if ckError.code == .zoneNotFound {
                print("Zone not found. Normally switch the other zone!")
            }
            else if ckError.code == .unknownItem {
                print("Items not found, which happens in the cloud environment. Probably ignore!")
            }
            else if ckError.code == .batchRequestFailed {
                print("Atomic failure!")
            }
            return ckError
        }
        return nil
    }
    
    // Return nil: no error or the error is ignorable.
    // Return a Dictionary: return the preprocessed data so caller can choose to do something.
    //
    func handle(error: Error?, operation: Operation, affectedObjects: [Any]? = nil, alert: Bool = false) -> [Result: Any]? {
        
        // nsError == nil: Everything goes well, callers can continue.
        //
        guard let nsError = error as NSError? else { return nil}
        
        // Partial errors can happen when fetching or changing the database.
        // In the case of modifying zones, records, and subscription:
        // .serverRecordChanged: retrieve the first CKError object and return for callers to use ckError.serverRecord.
        //
        // In the case of .fetchRecords and fetchChanges:
        // the specified items (.unknownItem) or zone (.zoneNotFound)
        // may not be found in database. We just ignore this kind of errors.
        //
        if let ckError = handlePartialError(nsError: nsError, affectedObjects: affectedObjects) {
            
            // Items not found. Ignore for the delete operation.
            //
            if operation == .deleteZones || operation == .deleteRecords || operation == .deleteSubscriptions {
                if ckError.code == .unknownItem {
                    return nil
                }
            }
            return [Result.ckError: ckError]
        }
        
        // In the case of fetching changes:
        // .changeTokenExpired: return for callers to refetch with nil server token.
        // .zoneNotFound: return for callers to switch zone, as the current zone has been deleted.
        // .partialFailure: zoneNotFound will trigger a partial error as well.
        //
        if operation == .fetchChanges {
            if let ckError = error as? CKError {
                if ckError.code == .changeTokenExpired || ckError.code == .zoneNotFound {
                    return [Result.ckError: ckError]
                }
            }
        }
        
        // .markRead: we don't care the errors occuring when marking read as we can do that next time,
        // so return nil to continue the flow.
        //
        if operation == .markRead {
            return nil
        }
        
        // For other errors, simply log it if:
        // 1. clients doen't want an alert.
        // 2. clients want an alert but there is already an alert in the queue.
        //    We only present the first alert in this case, so simply return.
        //
        if alert == false || operationQueue.operationCount > 0 {
            print("!!!!!\(operation.rawValue) operation error: \(nsError)")
            return [Result.nsError: nsError]
        }
        
        // Present alert if necessary.
        //
        var windowVC: UIViewController?
        operationQueue.addOperation {
            DispatchQueue.main.async {
                let window = UIApplication.shared.delegate?.window ?? nil
                windowVC = window?.rootViewController
            }
            guard let vc = windowVC else { return }
            var isAlerting = true
            
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Unhandled error during \(operation.rawValue) operation.",
                    message: "\(nsError)",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { _ in
                    isAlerting = false
                })
                vc.present(alert, animated: true)
            }
            
            // Wait until the alert is dismissed by the user tapping on the OK button.
            //
            while isAlerting {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
            }
        }
        return [Result.nsError: nsError]
    }
}

