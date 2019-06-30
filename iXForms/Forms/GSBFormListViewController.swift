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
    
    let groupID = "1"
    
    private let dateFormat = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        let downloadButton = UIBarButtonItem(image: UIImage(named: "icons8-download-30"), style: .plain, target: self, action: #selector(download))
        let receiveButton = UIBarButtonItem(image: UIImage(named: "icons8-smartphone-tablet-30"), style: .plain, target: self, action: #selector(receive))
        navigationItem.rightBarButtonItems = [downloadButton,receiveButton]

        dateFormat.dateStyle = .medium
        dateFormat.locale = Locale.current
    }

    override func reload() {
        os_log("%s.%s", #file, #function)
        list = Array(db.objects(XForm.self))
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
        
        header.text = String(format: "%d open, %d closed, %d closing", open.count, closed.count, closing.count)
        //header.attributedText = NSAttributedString(format: "%d open, %d closed, %d closing", args: open.count,closed.count,closing.count)
        header.sizeToFit()
    }
    
    // MARK: - Row selection

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let form = list[indexPath.row] as! XForm
        
        if (form.xml == nil) {
            GSBSpinner.shared.start()
            server!.getForm(formID: form.id, groupID: groupID, completion: { error in
                let formController = GSBFormViewController(form)
                DispatchQueue.main.async {
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

        if (form.created != nil) {
            let created = dateFormat.string(from: form.created!)
            message.append(NSAttributedString.init(string: "\nCreated: \t\t" + created, attributes: [.paragraphStyle: style]))
        }

        if (form.updated != nil) {
            let updated = dateFormat.string(from: form.updated!)
            message.append(NSAttributedString.init(string: "\nUpdated: \t\t" + updated, attributes: [.paragraphStyle: style]))
        }
        
        let state = FormState(rawValue: form.state.value!)
        message.append(NSAttributedString.init(string: "\nStatus: \t\t" + state!.description, attributes: [.paragraphStyle: style]))

        let info = UIAlertController(title: "Info", message: nil, preferredStyle: .alert)
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
