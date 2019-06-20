//
//  GSBFormViewController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import os.log

import Eureka

class GSBFormViewController: FormViewController {
    
    var xform: XForm!
    
    convenience init(_ xform: XForm) {
        self.init()
        self.xform = xform
        hidesBottomBarWhenPushed = true

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sendButton = UIBarButtonItem(image: UIImage(named: "icons8-upload-30"), style: .plain, target: self, action: #selector(send))
        let shareButton = UIBarButtonItem(image: UIImage(named: "icons8-smartphone-tablet-30"), style: .plain, target: self, action: #selector(share))
        navigationItem.rightBarButtonItems = [sendButton,shareButton]
        
        
        //navigationItem.leftBarButtonItem = UIBarButtonItem(image: xform.icon(), style: .plain, target: nil, action: nil)

        title = xform.id
        
        // -----

        var section = Section("Summary")
        form.append(section)

        section.append(TextRow("name") {
            $0.title = "Title"
            $0.value = xform.name
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
            .cellUpdate { cell, row in
                cell.textField.textColor = UIColor.gray
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
                cell.textField.textColor = UIColor.gray
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
                cell.textField.textColor = UIColor.gray
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
                cell.textField.textColor = UIColor.gray
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
                cell.textField.textColor = UIColor.gray
            }
        )
        
        // -----

        section = Section("Submissions")
        form.append(section)
        
        section.append(IntRow("submissions") {
            $0.title = "Total submissions"
            $0.value = xform.records.intValue
            }
            .cellSetup { cell, row in
                cell.isUserInteractionEnabled = false // disabled
            }
            .cellUpdate { cell, row in
                cell.textField.textColor = UIColor.gray
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
            $0.title = "Show All Submissions"
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
            $0.title = "Start New Form"
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
        // TODO
    }

}
