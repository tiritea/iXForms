//
//  GSBListTableViewController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/02/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

protocol GSBListTableViewDataSource {
    var list: Array<Any> {get}
}

protocol GSBListTableViewCell {
    func initWith(object: Any) -> UITableViewCell
}

class GSBListTableViewController: UITableViewController {
    
    var dataSource: GSBListTableViewDataSource?
    var cellType = GSBFormTableViewCell.self
    var headerFormat: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(cellType, forCellReuseIdentifier: "reuseIdentifier")
        
        if let _ = dataSource {
            self.refreshControl = UIRefreshControl()
            self.refreshControl?.attributedTitle = NSAttributedString(string: "Load Forms")
            self.refreshControl!.addTarget(self, action: #selector(refresh), for: .valueChanged)
        }
    }

    @objc func refresh(refreshControl: UIRefreshControl) {
        os_log("%s.%s", #file, #function)
        self.tableView.reloadData()
        refreshControl.endRefreshing()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let num = dataSource!.list.count
        return num
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath) as! GSBListTableViewCell
        let form = dataSource!.list[indexPath.row] as! XForm
        return cell.initWith(object: form)
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let message = "Created: \nBy: \nLast Update: \nSubmissions: \nLast Submission: "
        let info = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
        info.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(info, animated: true)
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
