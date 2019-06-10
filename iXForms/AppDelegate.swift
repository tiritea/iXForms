//
//  AppDelegate.swift
//  iXForms
//
//  Created by MBS GoGet on 27/01/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import RealmSwift
import os.log

// Realm object classes

enum FormStatus: Int {
    case open, closed, closing
}

class XForm: Object {
    @objc dynamic var id: String!
    @objc dynamic var name: String!
    @objc dynamic var version: String!

    override static func primaryKey() -> String? {return "id"}
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GSBListTableViewDataSource {
    
    var window: UIWindow?
    var forms: Array<XForm> = []
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
 
        let realm = try! Realm()
        
        try! realm.write {
            realm.deleteAll()
        }
        
        try! realm.write {
            let form = XForm()
            form.id = "1"
            form.name = "My First XForm"
            form.version = "1.0.0"
            realm.create(XForm.self, value: form, update: .error)

            form.id = "2"
            form.name = "My Second XForm"
            form.version = "1.0.1"
            realm.create(XForm.self, value: form, update: .error)
        }
        
        forms = Array(realm.objects(XForm.self))
        
        let formsViewController = GSBListTableViewController()
        formsViewController.tabBarItem = UITabBarItem(title: "Forms", image: UIImage(named: "icons8-paste-33"), tag: 0)
        formsViewController.dataSource = self
        formsViewController.cellType = GSBFormTableViewCell.self
        
        let submissionsViewController = SecondViewController()
        submissionsViewController.tabBarItem = UITabBarItem(title: "Submissions", image: UIImage(named: "icons8-documents-33"), tag: 1)

        let settingsController = GSBSettingsViewController()
        settingsController.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(named: "icons8-settings-33"), tag: 2)
        
        let mainTabController = UITabBarController();
        mainTabController.viewControllers = [formsViewController, submissionsViewController, settingsController]

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: mainTabController)
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

    // GSBListTableViewDataSource
    var list: Array<Any> {
        //return self.forms
        let realm = try! Realm()
        return Array(realm.objects(XForm.self))
    }
}

