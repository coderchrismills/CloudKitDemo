//
//  UIImage+Save.swift
//  CloudKitDemo
//
//  Created by Chris on 3/3/18.
//  Copyright © 2018 Chris. All rights reserved.
//

import UIKit

extension UIImage {
    func saveToFile() -> URL {
        let filemgr = FileManager.default
        let dirPaths = filemgr.urls(for: .documentDirectory, in: .userDomainMask)
        let fileURL = dirPaths[0].appendingPathComponent("currentImage.jpg")
        if let renderedJPEGData = UIImageJPEGRepresentation(self, 0.5) {
            try! renderedJPEGData.write(to: fileURL)
        }
        return fileURL
    }
}
