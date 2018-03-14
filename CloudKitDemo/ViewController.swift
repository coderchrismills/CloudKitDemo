//
//  ViewController.swift
//  CloudKitDemo
//
//  Created by Chris on 3/3/18.
//  Copyright © 2018 Chris. All rights reserved.
//

import UIKit
import CloudKit
import MobileCoreServices

class ViewController: UIViewController {
    @IBOutlet weak var titleText: UITextField!
    @IBOutlet weak var bodyText: UITextView!
    @IBOutlet weak var imageView: UIImageView!
    
    var plantRecord = PlantRecord()
    var noteRecord = NoteRecord()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(onFetchComplete), name: .onRecordFetchComplete, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc func onFetchComplete() {
        refreshView()
    }
    
    func refreshView() {
        DispatchQueue.main.async {
            guard let note = self.noteRecord.note else { return }
            self.titleText.text = note.title
            self.bodyText.text = note.body
            self.imageView.image = nil
            
            guard note.images.count > 0 else { return }
            guard let photoThumbData = note.images[0].photoThumbnailData else { return }
            self.imageView.image = UIImage(data: photoThumbData)
        }
    }
    
    @IBAction func saveRecord(_ sender: Any) {
        guard let title = titleText.text else { return }
        if noteRecord.note == nil {
            noteRecord.note = Note()
            noteRecord.plantRecord = plantRecord
        }
        noteRecord.note?.title = title
        noteRecord.note?.body = bodyText.text
        CloudKitSupport.shared.save(noteRecord) {
            self.refreshView()
        }
    }
    
    @IBAction func queryRecord(_ sender: Any) {
        guard let title = titleText.text else { return }
        let predicate = NSPredicate(format: "name CONTAINS %@", title)
        CloudKitSupport.shared.query(predicate: predicate) { record in
            self.noteRecord.update(with: record)
            self.refreshView()
        }
    }
    
    @IBAction func selectPhoto(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [kUTTypeImage as String]
        
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func updateRecord(_ sender: Any) {
        guard let title = titleText.text else { return }
        noteRecord.note?.title = title
        noteRecord.note?.body = bodyText.text
        CloudKitSupport.shared.update(noteRecord)
    }
    
    @IBAction func deleteRecord(_ sender: Any) {
        CloudKitSupport.shared.delete(record: noteRecord)
        noteRecord = NoteRecord()
        titleText.text = ""
        bodyText.text = ""
        imageView.image = nil
    }
    
    @IBAction func shareRecord(_ sender: Any) {
        CloudKitSupport.shared.share(noteRecord, with: self)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        titleText.endEditing(true)
        bodyText.endEditing(true)
    }
}

extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true, completion: nil)
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imageView.image = image
        
        let imageData = UIImageJPEGRepresentation(image, 1.0) as Data?
        let thumbnail = image.resizeImage(targetSize: CGSize(width: 100, height: 100))
        let thumbnailData = UIImageJPEGRepresentation(thumbnail, 1.0) as Data?
        
        let photo = Photo()
        photo.note = noteRecord.note
        photo.photoData = imageData
        photo.photoThumbnailData = thumbnailData
        
        noteRecord.note?.images.append(photo)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: UINavigationControllerDelegate {
    
}

