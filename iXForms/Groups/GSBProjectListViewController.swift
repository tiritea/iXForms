//
//  GSBProjectListViewController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/02/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

class GSBProjectListViewController: GSBListTableViewController {
    
    private let dateFormat = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        dateFormat.dateStyle = .medium
        dateFormat.locale = Locale.current
    }

    override func reload() {
        os_log("%s.%s", #file, #function)
        list = Array(db.objects(Project.self))
        os_log("%s.%s num groups %lu", #file, #function,list.count)
        super.reload()
    }
    
    override func refreshHeader() {
        header = String(format: "%d projects", list.count)
    }
    
    // MARK: - Row selection

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //let group = list[indexPath.row] as! Group
        tableView.deselectRow(at: indexPath, animated: true)
     }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let project = list[indexPath.row] as! Project
        
        let message = NSMutableAttributedString()
        let style = NSMutableParagraphStyle()
        style.alignment = .left

        if (project.created != nil) {
            let created = dateFormat.string(from: project.created!)
            message.append(NSAttributedString.init(string: "\nCreated: \t\t" + created, attributes: [.paragraphStyle: style]))
        }
        
        if (project.updated != nil) {
            let updated = dateFormat.string(from: project.updated!)
            message.append(NSAttributedString.init(string: "\nUpdated: \t\t" + updated, attributes: [.paragraphStyle: style]))
        }
        
        if (project.users != nil) { // RealmOptional
            message.append(NSAttributedString.init(string: "\nApp Users: \t" + String(project.users.value!), attributes: [.paragraphStyle: style]))
        }
        
        if (project.archived != nil) { // RealmOptional
            let archived = (project.archived.value == true) ? "Yes" : "No"
            message.append(NSAttributedString.init(string: "\nArchived: \t\t" + archived, attributes: [.paragraphStyle: style]))
        }
        
        let info = UIAlertController(title: "Info", message: nil, preferredStyle: .alert)
        info.setValue(message, forKey: "attributedMessage")
        info.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(info, animated: true)
    }
}
