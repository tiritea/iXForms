//
//  UIAlertController+.swift
//  XiphForms
//
//  Created by MBS GoGet on 24/08/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

extension UIAlertController {
    
    class func showAlert(title: String?, message: String?, button: String!) {
        DispatchQueue.main.async { // showAlert() can be called from background thread
            // https://stackoverflow.com/questions/26554894
            var rootController = UIApplication.shared.keyWindow?.rootViewController
            if let navigationController = rootController as? UINavigationController {
                rootController = navigationController.viewControllers.first
            }
            if let tabBarController = rootController as? UITabBarController {
                rootController = tabBarController.selectedViewController
            }
            if let presentedViewController = rootController?.presentedViewController {
                rootController = presentedViewController
            }
            
            let alert = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: button, style: .default, handler: nil))
            rootController?.present(alert, animated: true, completion: nil)
        }
    }
}
