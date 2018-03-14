//
//  PlantTableViewController.swift
//  CloudKitDemo
//
//  Created by Chris on 3/10/18.
//  Copyright © 2018 Chris. All rights reserved.
//

import UIKit

class PlantTableViewController: UITableViewController {
    var plants: [PlantRecord] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        NotificationCenter.default.addObserver(self, selector: #selector(onFetchComplete), name: .onRecordFetchComplete, object: nil)
        CloudKitSupport.shared.initialize() {
            CloudKitSupport.shared.fetchAllOwnedPlants { records in
                Records.shared.records = Records.shared.records + records
                self.plants = records
                self.refreshView()
            }
            
            CloudKitSupport.shared.fetchAllSharedPlants { records in
                Records.shared.records = Records.shared.records + records
                self.refreshView()
            }
        }
    }
    
    @objc func onFetchComplete() {
        self.plants = Records.shared.plantRecords
        refreshView()
    }
    
    func refreshView() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    @IBAction func onAddPressed() {
        let alert = UIAlertController(title: "Add", message: "Enter a name", preferredStyle: .alert)
        
        alert.addTextField { _ in }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert!.textFields![0]
            guard let name = textField.text else { return }
            let plantRecord = PlantRecord()
            let plant = Plant(name: name)
            plantRecord.plant = plant
            CloudKitSupport.shared.save(plantRecord) {
                self.refreshView()
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func deleteItem(at indexPath: IndexPath) {
        let plant = plants[indexPath.row]
        tableView.beginUpdates()
        
        if let index = Records.shared.records.index(of: plant) {
            Records.shared.records.remove(at: index)
        }
        
        plants.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plants.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlantTableViewCell", for: indexPath) as! PlantTableViewCell
        cell.configure(with: plants[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let shareAction = UITableViewRowAction(style: .normal, title: "Share") { (action , indexPath ) -> Void in
            let plant = self.plants[indexPath.row]
            guard let plantName = plant.plant?.name else { return }
            //let title = "Would you like to share \(plantName)"
            CloudKitSupport.shared.share(plant, with: self)
        }
        
        let deleteAction  = UITableViewRowAction(style: .default, title: "Delete") { (rowAction, indexPath) in
            self.deleteItem(at: indexPath)
        }
        
        return [shareAction, deleteAction]
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let vc = segue.destination as? ViewController else { return }
        guard let indexPath = self.tableView.indexPathForSelectedRow else { return }
        vc.plantRecord = plants[indexPath.row]
    }

}
