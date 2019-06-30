//
//  GSBSpinner.swift
//  iXForms
//
//  Created by MBS GoGet on 21/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//
// adapted from https://codereview.stackexchange.com/questions/150300

import UIKit

class GSBSpinner: NSObject {
    
    static let shared = GSBSpinner() // singleton
    private let spinner = UIActivityIndicatorView()
    
    override init() {
        super.init()
        spinner.style = .whiteLarge
        spinner.color = .gray
        spinner.autoresizingMask = [.flexibleBottomMargin, .flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin] // keep centered
    }
    
    func start() {
        stop() // just in case we didnt stop previous spinner...
        let window = UIApplication.shared.keyWindow!
        spinner.center = window.center
        DispatchQueue.main.async {
            window.addSubview(self.spinner)
            self.spinner.startAnimating()
            UIApplication.shared.beginIgnoringInteractionEvents()
        }
    }
    
    func stop() {
        DispatchQueue.main.async {
            UIApplication.shared.endIgnoringInteractionEvents()
            self.spinner.stopAnimating()
            self.spinner.removeFromSuperview()
        }
    }
}
