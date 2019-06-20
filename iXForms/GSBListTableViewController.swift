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
    let db = try! Realm()
    let dateFormat = DateFormatter()
    let header = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
     
        let downloadButton = UIBarButtonItem(image: UIImage(named: "icons8-download-30"), style: .plain, target: self, action: #selector(download))
        let receiveButton = UIBarButtonItem(image: UIImage(named: "icons8-smartphone-tablet-30"), style: .plain, target: self, action: #selector(receive))
        navigationItem.rightBarButtonItems = [downloadButton,receiveButton]

        if (dataSource != nil) {
            self.refreshControl = UIRefreshControl()
            self.refreshControl?.attributedTitle = NSAttributedString(string: "Reload")
            self.refreshControl!.addTarget(self, action: #selector(refresh), for: .valueChanged)
        }
        
        dateFormat.dateStyle = .medium
        dateFormat.locale = Locale.current
        
        header.backgroundColor = UIColor(white: 0.95, alpha: 0.9)
        header.numberOfLines = 0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        header.textColor = tabBarController?.tabBar.tintColor
        // TODO safe inset to match tableview
        self.reload()
    }

    func reload() {
        os_log("%s.%s", #file, #function)
        list = Array(self.db.objects(XForm.self))
        self.tableView.reloadData()
    }
    
    @objc func refresh(refreshControl: UIRefreshControl) {
        dataSource?.refresh(controller: self, completion: { error in
            DispatchQueue.main.async {
                refreshControl.endRefreshing() // BUG not disappearing
                if (error == nil) {
                    self.reload()
                } else {
                    let alert = UIAlertController(title: "Failed", message: error?.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    self.present(alert, animated: true)
                }
            }
        })
    }
    
    // MARK: - Actions

    @objc func download() {
        os_log("%s.%s", #file, #function)
        // TODO
    }
    
    @objc func receive() {
        os_log("%s.%s", #file, #function)
        // TODO
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.refreshHeader()
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return list.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! GSBListTableViewCell
        return cell.initWith(object: list[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return header
    }

    func refreshHeader() {
        let open = list.filter {($0 as! XForm).state.value == FormState.open.rawValue}
        let closed = list.filter {($0 as! XForm).state.value == FormState.closed.rawValue}
        let closing = list.filter {($0 as! XForm).state.value == FormState.closing.rawValue}
        
        header.text = String(format: "%d open, %d closed, %d closing", open.count, closed.count, closing.count)
        
        //header.attributedText = NSAttributedString(format: "%d open, %d closed, %d closing", args: open.count,closed.count,closing.count)
        
        header.sizeToFit()
    }
    
    // MARK: - Row selection

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let form = list[indexPath.row] as! XForm
        
        if (form.xml != nil) {
            let formController = GSBFormViewController(form)
            navigationController?.pushViewController(formController, animated: true)
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            if let server = currentServer {
                // TODO loading indicator
                server.getForm(formID: form.id, groupID: "1", completion: { error in
                    let formController = GSBFormViewController(form)
                    DispatchQueue.main.async {
                        self.navigationController?.pushViewController(formController, animated: true)
                        tableView.deselectRow(at: indexPath, animated: true)
                    }
                })
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let form = list[indexPath.row] as! XForm
        
        let message = NSMutableAttributedString()
        
        if (form.created != nil) {
            let created = dateFormat.string(from: form.created!)
            message.append(NSAttributedString.init(string: "\nCreated: " + created, attributes: [:]))
        }

        if (form.updated != nil) {
            let updated = dateFormat.string(from: form.updated!)
            message.append(NSAttributedString.init(string: "\nUpdated: " + updated, attributes: [:]))
        }
        
        let state = FormState(rawValue: form.state.value!)
        message.append(NSAttributedString.init(string: "\nStatus: " + state!.description, attributes: [:]))

        let info = UIAlertController(title: "Info", message: nil, preferredStyle: .alert)
        info.setValue(message, forKey: "attributedMessage")
        info.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(info, animated: true)
    }
    
    // MARK: - Row edit actions

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let form = list[indexPath.row] as! XForm
        
        if (editingStyle == .delete) {
            try! self.db.write {
                self.db.delete(form)
            }
            list.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            self.refreshHeader()
        }
    }
}
