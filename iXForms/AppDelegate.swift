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

// MARK : global constants
let APP = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
let DATETIMEFORMAT = "yyyy-MM-dd'T'HH:mm:ss.SZ"
let DATEFORMAT = "yyyy-MM-dd"
let TIMEFORMAT = "HH:mm:ss.SZ"
let DEFAULTAPI: ServerAPI = .openrosa_aggregate

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var formsController: GSBFormListViewController!
    var projectsController: GSBProjectListViewController!
    var submissionsController: GSBListTableViewController!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        os_log("%s.%s APP=%s", #file, #function, APP)

        // Check for previously saved server
        let api: ServerAPI = ServerAPI(rawValue: UserDefaults.standard.integer(forKey: "api")) ?? DEFAULTAPI // note: UserDefaults will return 0 if key doesnt exist
        UserDefaults.standard.set(api.rawValue, forKey: "api")
        
        let url: URL?
        if let previous = UserDefaults.standard.string(forKey: "server") {
            url = URL(string: previous)
        } else {
            url = api.server // use default server
        }
        UserDefaults.standard.set(url?.absoluteString, forKey: "server")

        switch api {
        case .openrosa_aggregate: server = GSBOpenRosaServer(url: url)
        case .openrosa_central: server = GSBOpenRosaServer(url: url)
        case .openrosa_kobo: server = GSBOpenRosaServer(url: url) // must append username after login
        case .rest_central : server = GSBRESTServer(url: url)
        case .rest_gomobile: server = GSBRESTServer(url: url)
        }
        
        // Show current database size
        let _ = try! Realm()
        if let path = Realm.Configuration.defaultConfiguration.fileURL, let value = try? path.resourceValues(forKeys: [.fileSizeKey]) {
            os_log("Realm database = %dkB", value.fileSize!/1024)
        }
        
        ValueTransformer.setValueTransformer(GSBGeopointTransformer(), forName: NSValueTransformerName("GSBGeopointTransformer"))

        formsController = GSBFormListViewController()
        formsController.title = "Forms"
        formsController.dataSource = server
        formsController.tableView.register(GSBFormTableViewCell.self, forCellReuseIdentifier: formsController.reuseIdentifier)
        let formsTab = UINavigationController(rootViewController:formsController)
        formsTab.tabBarItem = UITabBarItem(title: formsController.title, image: UIImage(named: "icons8-paste-33"), selectedImage: UIImage(named: "icons8-paste-filled-33"))
        formsTab.tabBarItem.tag = 0

        projectsController = GSBProjectListViewController()
        projectsController.title = "Groups"
        projectsController.dataSource = server
        projectsController.tableView.register(GSBProjectTableViewCell.self, forCellReuseIdentifier: projectsController.reuseIdentifier)
        let projectsTab = UINavigationController(rootViewController:projectsController)
        projectsTab.tabBarItem = UITabBarItem(title: projectsController.title, image: UIImage(named: "icons8-paste-33"), selectedImage: UIImage(named: "icons8-paste-filled-33"))
        projectsTab.tabBarItem.tag = 4

        submissionsController = GSBListTableViewController()
        submissionsController.title = "Submissions"
        submissionsController.dataSource = server
        submissionsController.tableView.backgroundColor = UIColor.red
        let submissionsTab = UINavigationController(rootViewController:submissionsController)
        submissionsTab.tabBarItem = UITabBarItem(title: submissionsController.title, image: UIImage(named: "icons8-documents-33"), selectedImage: UIImage(named: "icons8-documents-filled-33"))
        submissionsTab.tabBarItem.tag = 1
        
        let settingsController = GSBSettingsViewController()
        settingsController.tabBarItem = UITabBarItem(title: nil, image: UIImage(named: "icons8-settings-33"), selectedImage: UIImage(named: "icons8-settings-filled-33"))
        settingsController.tabBarItem.tag = 2
        settingsController.title = "Settings"
        
        let helpController = UIViewController()
        helpController.view.backgroundColor = UIColor.blue
        helpController.tabBarItem = UITabBarItem(title: nil, image: UIImage(named: "icons8-help-33"), selectedImage: UIImage(named: "icons8-help-filled-33"))
        helpController.tabBarItem.tag = 3
        helpController.title = "Help"

        let mainTabController = UITabBarController();
        mainTabController.viewControllers = [formsTab, projectsTab, submissionsTab, settingsController, helpController]
        mainTabController.selectedViewController = settingsController;
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = mainTabController
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

}

