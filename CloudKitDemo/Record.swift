//
//  Record.swift
//  CloudKitDemo
//
//  Created by Chris on 3/10/18.
//  Copyright © 2018 Chris. All rights reserved.
//

import CloudKit
import UIKit

struct Schema {
    struct RecordType {
        static let note = "Note"
        static let plant = "Plant"
        static let photo = "Photo"
    }
    struct Plant {
        static let name = "name"
    }
    struct Note {
        static let body = "body"
        static let title = "title"
        static let plant = "plant"
    }
    struct Photo {
        static let photoData = "photoData"
        static let photoThumbnail = "photoThumbnail"
        static let note = "note"
    }
}

class Record: Equatable {
    static func ==(lhs: Record, rhs: Record) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    var uuid: String = ""
    var ckRecord: CKRecord?
    var isShared: Bool = false
    var recordType: String { get { return "" } }
    
    init() {
        uuid = UUID().uuidString
    }
    
    func update(with record: CKRecord?) { }
    func save(to record: CKRecord) { }
}

class Plant {
    
    var name: String = ""
    var notes: [Note] = []
    
    init() { }
    init(name: String) {
        self.name = name
    }
}

class PlantRecord: Record {
    var plant: Plant?
    override var recordType: String { get { return Schema.RecordType.plant } }
    
    override func update(with record: CKRecord?) {
        guard let record = record else { return }
        ckRecord = record
        isShared = record.share != nil
        if plant == nil { plant = Plant() }
        if let name = record.object(forKey: Schema.Plant.name) as? String {
            plant?.name = name
        }
    }
    
    override func save(to record: CKRecord) {
        guard let p = plant else { return }
        record.setObject(p.name as CKRecordValue?, forKey: Schema.Plant.name)
    }
}

class Note {
    var title: String = ""
    var body: String = ""
    var images: [Photo] = []
    var plant: Plant?
}

class NoteRecord: Record {
    var note: Note?
    var plantRecord: PlantRecord?
    override var recordType: String { get { return Schema.RecordType.note } }
    
    override func update(with record: CKRecord?) {
        guard let record = record else { return }
        ckRecord = record
        isShared = record.share != nil
        
        if (note == nil) { note = Note() }
        
        if let title = record.object(forKey: Schema.Note.title) as? String {
            note?.title = title
        }
        
        if let body = record.object(forKey: Schema.Note.body) as? String {
            note?.body = body
        }
        
        if let plantRef = record.object(forKey: Schema.Note.plant) as? CKReference {
            let p = Records.shared.records.first {
                return $0.ckRecord?.recordID == plantRef.recordID
            }
            plantRecord = p as? PlantRecord
            note?.plant = plantRecord?.plant
        }
    }
    
    override func save(to record: CKRecord) {
        guard let n = note else { return }
        record.setObject(n.title as CKRecordValue?, forKey: Schema.Note.title)
        record.setObject(n.body as CKRecordValue?, forKey: Schema.Note.body)
        if let plantRecord = plantRecord?.ckRecord {
            let plantRef = CKReference(record: plantRecord, action: .deleteSelf)
            record.setObject(plantRef as CKReference?, forKey: Schema.Note.plant)
        }
        
    }
}

class Photo {
    var photoData: Data?
    var photoThumbnailData: Data?
    var note: Note?
}

class PhotoRecord: Record {
    var photo: Photo?
    var noteRecord: NoteRecord?
    
    override var recordType: String { get { return Schema.RecordType.photo } }
}
