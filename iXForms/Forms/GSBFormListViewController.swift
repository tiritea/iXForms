//
//  GSBFormListViewController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/02/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

import RealmSwift

class GSBFormListViewController: GSBListTableViewController {
    
    let projectID = "1"
    
    private let dateFormat = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        let downloadButton = UIBarButtonItem(image: UIImage(named: "icons8-download-30"), style: .plain, target: self, action: #selector(download))
        let receiveButton = UIBarButtonItem(image: UIImage(named: "icons8-smartphone-tablet-to-30"), style: .plain, target: self, action: #selector(receive))
        navigationItem.rightBarButtonItems = [downloadButton,receiveButton]

        dateFormat.dateStyle = .medium
        dateFormat.locale = Locale.current
    }

    override func reload() {
        os_log("%s.%s", #file, #function)
        if (dataSource as! GSBServer).hasProjects {
            list = Array(db.objects(XForm.self)) // FIX only get form in project
        } else {
            list = Array(db.objects(XForm.self)) // all forms
        }
        super.reload()
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

    override func refreshHeader() {
        let open = list.filter {($0 as! XForm).state.value == FormState.open.rawValue}
        let closed = list.filter {($0 as! XForm).state.value == FormState.closed.rawValue}
        let closing = list.filter {($0 as! XForm).state.value == FormState.closing.rawValue}
        header = String(format: "%d open, %d closed, %d closing", open.count, closed.count, closing.count)
    }
    
    // MARK: - Row selection

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let form = list[indexPath.row] as! XForm
        
        if (form.xml == nil) {
            GSBSpinner.shared.start()
            server!.getForm(formID: form.id, projectID: projectID, completion: { error in
                DispatchQueue.main.async {
                    let formController = GSBFormViewController(form)
                    self.navigationController?.pushViewController(formController, animated: true)
                    GSBSpinner.shared.stop()
                    tableView.deselectRow(at: indexPath, animated: true)
                }
            })
        } else {
            let formController = GSBFormViewController(form)
            navigationController?.pushViewController(formController, animated: true)
            tableView.deselectRow(at: indexPath, animated: true)
        }
     }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let form = list[indexPath.row] as! XForm
        
        let message = NSMutableAttributedString()
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byTruncatingTail

        if let name = form.name {
            message.append(NSAttributedString.init(string: "\nName: \t\t" + name, attributes: [.paragraphStyle: style]))
        }
        
        message.append(NSAttributedString.init(string: "\nID: \t\t\t" + form.id, attributes: [.paragraphStyle: style]))

        if let version = form.version, version.count > 0 {
            message.append(NSAttributedString.init(string: "\nVersion: \t" + version, attributes: [.paragraphStyle: style]))
        }

        if let created = form.created {
            message.append(NSAttributedString.init(string: "\nCreated: \t" + dateFormat.string(from: created), attributes: [.paragraphStyle: style]))
        }

        if let updated = form.updated {
            message.append(NSAttributedString.init(string: "\nUpdated: \t" + dateFormat.string(from: updated), attributes: [.paragraphStyle: style]))
        }
        
        message.append(NSAttributedString.init(string: "\nStatus: \t" + FormState(rawValue: form.state.value!)!.description, attributes: [.paragraphStyle: style]))

        let info = UIAlertController(title: "Form Info", message: nil, preferredStyle: .alert)
        info.setValue(message, forKey: "attributedMessage")
        info.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(info, animated: true)
    }
    
    // MARK: - Row edit actions

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let form = list[indexPath.row] as! XForm
        
        if (editingStyle == .delete) {
            try! db.write {
                db.delete(form)
            }
            list.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            refreshHeader()
        }
    }
}
