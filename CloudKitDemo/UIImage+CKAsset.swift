//
//  UIImage+CKAsset.swift
//  CloudKitDemo
//
//  Created by Chris on 2/1/18.
//  Copyright © 2018 Chris. All rights reserved.
//
import UIKit
import CloudKit

extension CKAsset {
    convenience init(image: UIImage) throws {
        let url = try image.saveToTempLocation()
        self.init(fileURL: url)
    }
    
    var image: UIImage? {
        do {
            let data = try Data(contentsOf: fileURL)
            guard let image = UIImage(data: data) else { return nil }
            return image
        } catch {
            return nil
        }
    }
}

extension UIImage {
    func saveToTempLocation() throws -> URL {
        let imageData = UIImageJPEGRepresentation(self, 70)
        let filename = ProcessInfo.processInfo.globallyUniqueString + ".jpg"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        try imageData?.write(to: url, options: .atomicWrite)
        return url
    }
}

