//
//  PlantTableViewCell.swift
//  CloudKitDemo
//
//  Created by Chris on 3/10/18.
//  Copyright © 2018 Chris. All rights reserved.
//

import UIKit

class PlantTableViewCell: UITableViewCell {
    @IBOutlet weak var plantNameLabel: UILabel!
    @IBOutlet weak var plantImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func configure(with plant: PlantRecord) {
        plantNameLabel.text = plant.plant?.name
        //plantImageView
    }

}
