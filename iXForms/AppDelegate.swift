//
//  AppDelegate.swift
//  iXForms
//
//  Created by MBS GoGet on 27/01/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

import RealmSwift
import Eureka

// MARK : global constants
let APP = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
let DATETIMEFORMAT = "yyyy-MM-dd'T'HH:mm:ss.SZ"
let DATEFORMAT = "yyyy-MM-dd"
let TIMEFORMAT = "HH:mm:ss.SZ"
let DEFAULTAPI: ServerAPI = .rest_central

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var rootController: UITabBarController!
    var formsController: GSBFormListViewController!
    var submissionsController: GSBListTableViewController!
    var currentProject: Project?
    let projectListButton = UIBarButtonItem(image: UIImage(named: "icons8-menu-30"), style: .plain, target: self, action: #selector(changeProject))
    var projectInfoButton = UIBarButtonItem(image: UIImage(named: "icons8-info-25"), style: .plain, target: self, action: #selector(showProject))

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        os_log("%s.%s", #file, #function)
        let _ = try! Realm()
        if let path = Realm.Configuration.defaultConfiguration.fileURL, let value = try? path.resourceValues(forKeys: [.fileSizeKey]) {
            os_log("Realm database = %dkB", value.fileSize!/1024)
        }

        // Appearances
        UIBarButtonItem.appearance().tintColor = .control
        UITabBar.appearance().tintColor = .control

        // Euerka defaults
        TextRow.defaultCellSetup = { (cell, row) in
            cell.textField.keyboardType = .asciiCapable
            cell.textField.autocapitalizationType = .none
            cell.textField.autocorrectionType = .no
        }
        TextRow.defaultCellUpdate = { (cell, row) in
            cell.textField.textColor = .systemDetailTextLabel
            cell.textLabel?.textColor = .black
        }
        
        IntRow.defaultCellSetup = { (cell, row) in
            // remove IntRow separator (eg "1,234" -> "1234")
            row.useFormatterDuringInput = true
            let formatter = NumberFormatter()
            formatter.groupingSeparator = ""
            row.formatter = formatter
        }
        IntRow.defaultCellUpdate = { (cell, row) in
            cell.textField.textColor = .systemDetailTextLabel
        }
        
        SegmentedRow<String>.defaultCellSetup = { (cell, row) in
            // minimize segment width - https://github.com/xmartlabs/Eureka/issues/973
            cell.segmentedControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            cell.segmentedControl.apportionsSegmentWidthsByContent = true
            cell.tintColor = .control
        }
        
        SwitchRow.defaultCellSetup = { (cell, row) in
            cell.switchControl.tintColor = .control
            cell.switchControl.onTintColor = .control
        }
        
        ButtonRow.defaultCellSetup = { (cell, row) in
            cell.tintColor = UIColor.white
            cell.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline) // bold
            cell.backgroundColor = .tomato
        }
        
        ImageRow.defaultCellUpdate = { (cell, row) in
            cell.textLabel?.textColor = .black
        }

        DateRow.defaultCellUpdate = { (cell, row) in
            cell.textLabel?.textColor = .black
            cell.datePicker.tintColor = .red
        }

        ValueTransformer.setValueTransformer(GSBGeopointTransformer(), forName: NSValueTransformerName("GSBGeopointTransformer"))

        // Lookup previously saved API+server, otherwise use default
        let api: ServerAPI = ServerAPI(rawValue: UserDefaults.standard.integer(forKey: "api")) ?? DEFAULTAPI // note: UserDefaults will return 0 integer if key doesn't exist
        UserDefaults.standard.set(api.rawValue, forKey: "api")
        os_log("api = %s", api.description)
        
        let url: URL?
        if let str = UserDefaults.standard.string(forKey: "server") {
            url = URL(string: str)
        } else {
            url = api.server // use default server
            UserDefaults.standard.set(url?.absoluteString, forKey: "server")
        }
        os_log("url = %s", url!.absoluteString)
        
        // Lookup previously saved project
        if let project = UserDefaults.standard.string(forKey: "project") {
            let db = try! Realm()
            currentProject = db.object(ofType: Project.self, forPrimaryKey :project)
        }
        os_log("projectID = %s", currentProject?.id ?? "(null)")

        switch api {
        case .openrosa_aggregate: server = GSBOpenRosaServer(url: url)
        case .openrosa_central: server = GSBOpenRosaServer(url: url)
        case .openrosa_kobo: server = GSBKoboServer(url: url)
        case .rest_central : server = GSBRESTServer(url: url)
        case .rest_gomobile: server = GSBRESTServer(url: url)
        }

        formsController = GSBFormListViewController()
        formsController.dataSource = server
        formsController.navigationItem.leftBarButtonItems = [projectListButton, projectInfoButton]
        formsController.tableView.register(GSBFormTableViewCell.self, forCellReuseIdentifier: formsController.reuseIdentifier)
        let formsTab = UINavigationController(rootViewController:formsController)
        formsTab.tabBarItem = UITabBarItem(title: "Forms", image: UIImage(named: "icons8-paste-33"), selectedImage: UIImage(named: "icons8-paste-filled-33"))
        formsTab.tabBarItem.tag = 0
        
        submissionsController = GSBListTableViewController()
        submissionsController.dataSource = server
        submissionsController.navigationItem.leftBarButtonItems = [projectListButton, projectInfoButton]
        submissionsController.tableView.backgroundColor = UIColor.red
        let submissionsTab = UINavigationController(rootViewController:submissionsController)
        submissionsTab.tabBarItem = UITabBarItem(title: "Submissions", image: UIImage(named: "icons8-documents-33"), selectedImage: UIImage(named: "icons8-documents-filled-33"))
        submissionsTab.tabBarItem.tag = 1
        
        let settingsController = GSBSettingsViewController()
        settingsController.title = "Settings"
        settingsController.tabBarItem = UITabBarItem(title: settingsController.title, image: UIImage(named: "icons8-settings-33"), selectedImage: UIImage(named: "icons8-settings-filled-33"))
        settingsController.tabBarItem.tag = 2
        
        let helpController = UIViewController()
        helpController.title = "Help"
        helpController.view.backgroundColor = UIColor.blue
        helpController.tabBarItem = UITabBarItem(title: helpController.title, image: UIImage(named: "icons8-help-33"), selectedImage: UIImage(named: "icons8-help-filled-33"))
        helpController.tabBarItem.tag = 3

        rootController = UITabBarController();
        rootController.viewControllers = [formsTab, submissionsTab, settingsController, helpController]
        rootController.selectedViewController = settingsController;

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    @objc func changeProject() {
        let picker = UIAlertController(title: "Select Project", message: nil, preferredStyle: .actionSheet)
        
        // Add each project as alert buton
        let db = try! Realm()
        for project in Array(db.objects(Project.self)) {
            var style: UIAlertAction.Style = .default
            // 'highlight' current project
            if let current = currentProject, current.id == project.id {
                style = .cancel
            }
            
            // https://realm.io/blog/obj-c-swift-2-2-thread-safe-reference-sort-properties-relationships/
            let projectRef = ThreadSafeReference(to: project)
            
            let title = project.name ?? project.id // project name is optional in Central
            picker.addAction(UIAlertAction(title: title, style: style, handler: { action in
                // self.currentProject = project
                let db = try! Realm()
                self.currentProject = db.resolve(projectRef)
                UserDefaults.standard.set(self.currentProject!.id, forKey: "project")
                self.refresh()
            }))
        }
        rootController.present(picker, animated: true, completion: nil)
    }

    @objc func showProject() {
        let message = NSMutableAttributedString()
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        
        let dateFormat = DateFormatter()
        dateFormat.dateStyle = .medium
        dateFormat.locale = Locale.current
        
        if let project = currentProject {
            if let name = project.name {
                message.append(NSAttributedString.init(string: "\nName: \t\t" + name, attributes: [.paragraphStyle: style]))
            }
            
            message.append(NSAttributedString.init(string: "\nID: \t\t\t" + project.id, attributes: [.paragraphStyle: style]))

            if (project.created != nil) {
                let created = dateFormat.string(from: project.created!)
                message.append(NSAttributedString.init(string: "\nCreated: \t" + created, attributes: [.paragraphStyle: style]))
            }
            
            if (project.updated != nil) {
                let updated = dateFormat.string(from: project.updated!)
                message.append(NSAttributedString.init(string: "\nUpdated: \t" + updated, attributes: [.paragraphStyle: style]))
            }
            
            if (project.users != nil) { // RealmOptional
                message.append(NSAttributedString.init(string: "\nUsers: \t\t" + String(project.users.value!), attributes: [.paragraphStyle: style]))
            }
            
            if (project.archived != nil) { // RealmOptional
                let archived = (project.archived.value == true) ? "Yes" : "No"
                message.append(NSAttributedString.init(string: "\nArchived: \t" + archived, attributes: [.paragraphStyle: style]))
            }
            
            let info = UIAlertController(title: "Project Info", message: nil, preferredStyle: .alert)
            info.setValue(message, forKey: "attributedMessage")
            info.addAction(UIAlertAction(title: "OK", style: .cancel))
            rootController.present(info, animated: true)
        }
    }

    func restart() {
        os_log("%s.%s", #file, #function)
        
        server!.getProjectList() { error in
            if (error == nil) {
                if (self.currentProject == nil) {
                    self.changeProject() // will refresh
                    return
                }
            }
        }
        refresh()
    }
    
    func refresh() {
        os_log("%s.%s", #file, #function)
        
        if let project = currentProject {
            let title = project.name ?? project.id // project name is optional in Central
            formsController.navigationItem.title = title
            formsController.navigationItem.leftBarButtonItems = [projectListButton, projectInfoButton]
            submissionsController.navigationItem.title = title
            submissionsController.navigationItem.leftBarButtonItems = [projectListButton, projectInfoButton]
        } else {
            formsController.navigationItem.title = formsController.tabBarItem.title
            formsController.navigationItem.leftBarButtonItems = nil
            submissionsController.navigationItem.title = submissionsController.tabBarItem.title
            submissionsController.navigationItem.leftBarButtonItems = nil
        }

        formsController.dataSource = server
        formsController.reload()
        formsController.navigationController?.popToRootViewController(animated: false)
        
        submissionsController.dataSource = server
        submissionsController.reload()
        submissionsController.navigationController?.popToRootViewController(animated: false)
    }

}

