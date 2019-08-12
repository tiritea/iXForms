//
//  GSBListTableViewController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/02/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

import RealmSwift

protocol GSBListTableViewDataSource {
    func refresh(controller: GSBListTableViewController, completion: @escaping (Error?) -> Void) // https://cocoacasts.com/what-do-escaping-and-noescape-mean-in-swift-3
}

protocol GSBListTableViewCell {
    func initWith(object: Any) -> UITableViewCell
}

class GSBListTableViewController: UITableViewController {
    
    var list: Array<Any>! = []
    var dataSource: GSBListTableViewDataSource?
    let reuseIdentifier = "CELL"
    var db: Realm!
    var header: String?

    override func viewDidLoad() {
        super.viewDidLoad()
     
        if (dataSource != nil) {
            refreshControl = UIRefreshControl()
            refreshControl?.attributedTitle = NSAttributedString(string: "Refresh")
            refreshControl!.addTarget(self, action: #selector(refresh), for: .valueChanged)
        }
        
        db = try! Realm()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    func reload() {
        tableView.reloadData()
    }
    
    @objc func refresh(refreshControl: UIRefreshControl) {
        dataSource?.refresh(controller: self, completion: { error in
            DispatchQueue.main.async {
                refreshControl.endRefreshing()
                if (error == nil) {
                    self.reload()
                } else {
                    let alert = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    self.present(alert, animated: true)
                }
            }
        })
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        refreshHeader()
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return list.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! GSBListTableViewCell
        return cell.initWith(object: list[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return header
    }

    func refreshHeader() {
        header = String(format: "%d found", list.count)
    }

}
