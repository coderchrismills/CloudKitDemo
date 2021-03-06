//
//  Records.swift
//  CloudKitDemo
//
//  Created by Chris on 3/11/18.
//  Copyright © 2018 Chris. All rights reserved.
//

import CloudKit

class Records {
    var records: [Record] = []
    var plantRecords:[PlantRecord] {
        get {
            let plants = records.filter { $0.recordType == Schema.RecordType.plant }
            return plants as! [PlantRecord]
        }
    }
    
    static let shared = Records()
    private init() { }
    
    func record(for ckRecord: CKRecord) -> Record? {
        let record = records.first { record in
            guard let ck = record.ckRecord else { return false }
            return ck.recordID == ckRecord.recordID
        }
        return record
    }
}
