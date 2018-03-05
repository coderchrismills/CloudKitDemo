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
    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var commentsField: UITextView!
    @IBOutlet weak var imageView: UIImageView!
    
    var house: House = House()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        CloudKitSupport.shared.initialize()
        NotificationCenter.default.addObserver(self, selector: #selector(onFetchComplete), name: .onRecordFetchComplete, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc func onFetchComplete() {
        house.update(with: CloudKitSupport.shared.currentRecord)
        refreshView()
    }
    
    func refreshView() {
        DispatchQueue.main.async {
            self.addressField.text = self.house.address
            self.commentsField.text = self.house.comments
            if let url = self.house.photoURL {
                self.imageView.image = UIImage(contentsOfFile: url.path)
            } else {
                self.imageView.image = nil
            }
        }
    }
    
    @IBAction func saveRecord(_ sender: Any) {
        guard let addressText = addressField.text else { return }
        house.address = addressText
        CloudKitSupport.shared.save(house)
    }
    
    @IBAction func queryRecord(_ sender: Any) {
        guard let address = addressField.text else { return }
        CloudKitSupport.shared.query(address: address) { record in
            self.house.update(with: record)
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
        guard let addressText = addressField.text else { return }
        house.address = addressText
        house.comments = commentsField.text
        CloudKitSupport.shared.update(house)
    }
    
    @IBAction func deleteRecord(_ sender: Any) {
        CloudKitSupport.shared.delete()
        addressField.text = ""
        commentsField.text = ""
        imageView.image = nil
    }
    
    @IBAction func shareRecord(_ sender: Any) {
        CloudKitSupport.shared.share(with: self)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        addressField.endEditing(true)
        commentsField.endEditing(true)
    }
}

extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true, completion: nil)
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imageView.image = image
        house.photoURL = image.saveToFile()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: UINavigationControllerDelegate {
    
}

