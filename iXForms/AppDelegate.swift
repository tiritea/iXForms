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

// Realm object classes

enum FormState: Int, CustomStringConvertible {
    case open = 0
    case closing = 1
    case closed = 2
    case unknown = 3
    
    // https://stackoverflow.com/questions/24701075
    var description : String {
        switch self {
        case .open: return "Open"
        case .closing: return "Closing"
        case .closed: return "Closed"
        case .unknown: return "Unknown"
        }
    }
    
    func color() -> UIColor {
        switch self {
        case .open: return UIColor(hex: 0x008000)
        case .closing: return UIColor(hex: 0xffd700)
        case .closed: return UIColor.red
        case .unknown: return UIColor.darkGray
        }
    }
}

class XForm: Object {
    @objc dynamic var id: String!
    @objc dynamic var name: String?
    @objc dynamic var version: String?
    @objc dynamic var xml: String?
    @objc dynamic var xmlHash: String?
    @objc dynamic var author: String?
    @objc dynamic var created: Date?
    @objc dynamic var updated: Date?
    @objc dynamic var lastSubmission: Date?
    @objc dynamic var records: NSNumber = -1 // cant use Int because might be null (-1 = unknown)

    let state = RealmOptional<Int>() // FormState

    override static func primaryKey() -> String? {return "id"}
    
    func icon() -> UIImage {
        var image: UIImage?
        switch self.state.value {
        case FormState.open.rawValue:
            if (self.xml != nil) { // on device
                image = UIImage(named: "icons8-check-mark-symbol-filled-30")
            } else { // must download from server
                image = UIImage(named: "icons8-download-from-cloud-filled-30")
            }
        case FormState.closing.rawValue:
            if (self.xml != nil) { // on device but can still be submitted
                image = UIImage(named: "icons8-check-mark-symbol-filled-30")
            } else { // on server and cannot be downloaded
                image = UIImage(named: "icons8-cloud-cross-filled-30")
            }
        case FormState.closed.rawValue:
            if (self.xml != nil) { // on device
                image = UIImage(named: "icons8-cancel-filled-30")
            } else { // on server
                image = UIImage(named: "icons8-cloud-cross-filled-30")
            }
        default:
            assertionFailure("unrecognized form state")
        }
        return image!.withRenderingMode(.alwaysTemplate)
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GSBListTableViewDataSource {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        os_log("%s.%s", #file, #function)

        let formsViewController = GSBListTableViewController()
        formsViewController.title = "Forms"
        formsViewController.dataSource = self
        formsViewController.tableView.register(GSBFormTableViewCell.self, forCellReuseIdentifier: formsViewController.reuseIdentifier)
        let formsTab = UINavigationController(rootViewController:formsViewController)
        //formsTab.tabBarItem = UITabBarItem(title: formsViewController.title, image: UIImage(named: "icons8-paste-33"), tag: 0)
        formsTab.tabBarItem = UITabBarItem(title: formsViewController.title, image: UIImage(named: "icons8-paste-33"), selectedImage: UIImage(named: "icons8-paste-filled-33"))
        formsTab.tabBarItem.tag = 0

        let submissionsViewController = UIViewController()
        submissionsViewController.title = "Submissions"
        submissionsViewController.view.backgroundColor = UIColor.red
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
        mainTabController.viewControllers = [formsTab, submissionsTab, settingsController, helpController]
        mainTabController.selectedViewController = settingsController;
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = mainTabController
        window?.makeKeyAndVisible()
        
        if let urlString = UserDefaults.standard.string(forKey: "server"), let url = URL(string: urlString) {
            let api = UserDefaults.standard.integer(forKey: "api")
            currentServer = GSBServer.init(url: url, api: api)
        }

        return true
    }

    // <GSBListTableViewDataSource>
    func refresh(controller: GSBListTableViewController, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s", #file, #function)
        
        // TODO check which controller
        
        if let server = currentServer {
            server.getFormList(groupID: "1", completion: completion)
        } else {
            completion(NSError(domain: "iXForms", code: 0, userInfo: [NSLocalizedDescriptionKey: "no server"]))
        }
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

