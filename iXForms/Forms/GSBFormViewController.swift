//
//  GSBFormViewController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import os.log

import Eureka
import RealmSwift

class GSBFormViewController: FormViewController {
    
    var xform: XForm!
    let detailColor = UITableViewCell.init(style: .value1, reuseIdentifier: nil).detailTextLabel?.textColor
    
    convenience init(_ xform: XForm) {
        self.init()
        self.xform = xform
        hidesBottomBarWhenPushed = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sendButton = UIBarButtonItem(image: UIImage(named: "icons8-upload-30"), style: .plain, target: self, action: #selector(send))
        let shareButton = UIBarButtonItem(image: UIImage(named: "icons8-smartphone-tablet-from-30"), style: .plain, target: self, action: #selector(share))
        navigationItem.rightBarButtonItems = [sendButton,shareButton]
        
        title = xform.id
        
        // -----

        var section = Section("Summary")
        form.append(section)

        section.append(TextRow("name") {
            $0.title = "Name"
            $0.value = xform.name
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
            .cellUpdate { cell, row in
                cell.textField.textColor = self.detailColor
            }
        )

        section.append(TextRow("id") {
            $0.title = "ID"
            $0.value = xform.id
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
            .cellUpdate { cell, row in
                cell.textField.textColor = self.detailColor
            }
        )
        
        section.append(TextRow("version") {
            $0.title = "Version"
            $0.value = xform.version
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
            .cellUpdate { cell, row in
                cell.textField.textColor = self.detailColor
            }
        )

        section.append(TextRow("state") {
            $0.title = "Status"
            let state = FormState(rawValue: xform.state.value!)
            $0.value = state!.description
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
            .cellUpdate { cell, row in
                cell.textField.textColor = self.detailColor
            }
        )

        // -----

        section = Section()
        form.append(section)

        section.append(DateRow("created") {
            $0.title = "Created"
            $0.value = xform.created
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
        )

        section.append(DateRow("updated") {
            $0.title = "Updated"
            $0.value = xform.updated
            $0.hidden = Condition.predicate(NSPredicate(format: "$updated == nil"))
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
        )

        section.append(TextRow("author") {
            $0.title = "Author"
            $0.value = xform.author
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
            .cellUpdate { cell, row in
                cell.textField.textColor = self.detailColor
            }
        )
        
        // -----

        section = Section("Submissions")
        form.append(section)
        
        section.append(IntRow("submissions") {
            $0.title = "Total submissions"
            $0.value = xform.numRecords.value
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
            .cellUpdate { cell, row in
                cell.textField.textColor = self.detailColor
            }
        )

        section.append(DateRow("lastsubmission") {
            $0.title = "Last submission"
            $0.value = xform.lastSubmission
            $0.hidden = Condition.predicate(NSPredicate(format: "$submissions == 0"))
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
        )

        section.append(ButtonRow("showsubmissions") {
            $0.title = "View Submissions"
            $0.hidden = Condition.predicate(NSPredicate(format: "$submissions == 0"))
            }
            .cellSetup { cell, row in
                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline) // bold
            }
            .onCellSelection { cell, row in
                self.submissions()
            }
        )

        // -----
        
        section = Section()
        form.append(section)

        section.append(ButtonRow("start") {
            $0.title = "New Submission"
            $0.disabled = Condition(booleanLiteral: xform.xml == nil) // form hasnt been downloaded yet
            }
            .cellSetup { cell, row in
                cell.tintColor = UIColor.white
                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline) // bold
                cell.backgroundColor = UIColor.red
            }
            .onCellSelection { cell, row in
                self.start()
            }
        )
    }
    
    // MARK: - Actions

    @objc func send() {
        os_log("%s.%s", #file, #function)
        // TODO
    }

    @objc func share() {
        os_log("%s.%s", #file, #function)
        // TODO
    }

    @objc func submissions() {
        os_log("%s.%s", #file, #function)
        // TODO
    }

    @objc func start() {
        os_log("%s.%s", #file, #function)
        
        // Absence of any instance(s) means form has not been parsed
        if xform.instances.count == 0 {
            // Presence of xml means form has been downloaded and can be parsed
            if let xml = xform.xml, let parser = GSBXFormParser(xform: xform, xml: xml) {
                os_log("parsing form...")
                if (parser.parse() == false) {
                    os_log("parse() failed")
                    return
                }
            } else {
                os_log("xml form definition not found")
                return
            }
        }
        os_log("form has %d instances, %d bindings, %d controls, %d groups", xform.instances.count, xform.bindings.count, xform.controls.count, xform.groups.count)

        let db = try! Realm()
        try! db.write {
            let submission = XFormSubmission.init(xform: xform)
            db.create(XFormSubmission.self, value: submission, update: .all)
            os_log("new submission id=%s",submission.id)
            
            let xformController = GSBXFormController(submission, group: nil) // root group
            navigationController?.pushViewController(xformController, animated: true)
        }
    }

}
