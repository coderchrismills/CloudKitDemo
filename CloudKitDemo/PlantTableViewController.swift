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
        }
    }
    
    @objc func onFetchComplete() {
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

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let vc = segue.destination as? ViewController else { return }
        guard let indexPath = self.tableView.indexPathForSelectedRow else { return }
        vc.plantRecord = plants[indexPath.row]
    }

}
