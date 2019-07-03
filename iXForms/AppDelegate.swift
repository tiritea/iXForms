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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var formsViewController: GSBFormListViewController!
    var groupsViewController: GSBGroupListViewController!
    var submissionsViewController: GSBListTableViewController!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        os_log("%s.%s", #file, #function)

        let url = URL(string: UserDefaults.standard.string(forKey: "server") ?? "https://odk.antinod.es:443/v1")
        //let api = UserDefaults.standard.integer(forKey: "api")
        let api = 3
        if (api == 3) {
            server = GSBRESTServer(url: url)
        }
        
        // Current database size
        let _ = try! Realm()
        if let path = Realm.Configuration.defaultConfiguration.fileURL, let value = try? path.resourceValues(forKeys: [.fileSizeKey]) {
            os_log("Realm database = %dkB", value.fileSize!/1024)
        }
        
        formsViewController = GSBFormListViewController()
        formsViewController.title = "Forms"
        formsViewController.dataSource = (server as? GSBListTableViewDataSource)
        formsViewController.tableView.register(GSBFormTableViewCell.self, forCellReuseIdentifier: formsViewController.reuseIdentifier)
        let formsTab = UINavigationController(rootViewController:formsViewController)
        formsTab.tabBarItem = UITabBarItem(title: formsViewController.title, image: UIImage(named: "icons8-paste-33"), selectedImage: UIImage(named: "icons8-paste-filled-33"))
        formsTab.tabBarItem.tag = 0

        groupsViewController = GSBGroupListViewController()
        groupsViewController.title = "Groups"
        groupsViewController.dataSource = (server as? GSBListTableViewDataSource)
        groupsViewController.tableView.register(GSBGroupTableViewCell.self, forCellReuseIdentifier: groupsViewController.reuseIdentifier)
        let groupsTab = UINavigationController(rootViewController:groupsViewController)
        groupsTab.tabBarItem = UITabBarItem(title: groupsViewController.title, image: UIImage(named: "icons8-paste-33"), selectedImage: UIImage(named: "icons8-paste-filled-33"))
        groupsTab.tabBarItem.tag = 4

        submissionsViewController = GSBListTableViewController()
        submissionsViewController.title = "Submissions"
        submissionsViewController.dataSource = (server as? GSBListTableViewDataSource)
        submissionsViewController.tableView.backgroundColor = UIColor.red
        let submissionsTab = UINavigationController(rootViewController:submissionsViewController)
        submissionsTab.tabBarItem = UITabBarItem(title: submissionsViewController.title, image: UIImage(named: "icons8-documents-33"), selectedImage: UIImage(named: "icons8-documents-filled-33"))
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
        mainTabController.viewControllers = [formsTab, groupsTab, submissionsTab, settingsController, helpController]
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

