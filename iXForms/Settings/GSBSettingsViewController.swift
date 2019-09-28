//
//  GSBSettingsViewController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import os.log

import Eureka
import KeychainSwift
import RealmSwift

class GSBSettingsViewController: FormViewController {
    
    var api: ServerAPI!
    var urlComponents: URLComponents!
    
    // MARK: Eureka Form

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let device = UIDevice.current
        var section: Section
        var tag: String
        
        // ---------- Server ----------
        
        section = Section("Server")
        section.tag = "server"
        form.append(section)
        
        // Note: ServerAPI enum starts at 1!
        section.append(ActionSheetRow<String>("api") {
            $0.title = "API"
            $0.options = ServerAPI.allCases.map{ $0.description }
            }
            .onChange { row in
                if let selected = row.value, let index = row.options!.index(of: selected) {
                    self.api = ServerAPI(rawValue: index+1)!

                    // initialize url to the default server for new API
                    self.urlComponents = URLComponents(url: self.api.server!, resolvingAgainstBaseURL: true)
                    self.refresh()
                }
            }
        )

        section.append(TextRow("host") {
            $0.title = "Host"
            $0.placeholder = "hostname/path"
            $0.onCellHighlightChanged { (cell, row) in // finished editting
                if !row.isHighlighted {
                    // https://stackoverflow.com/questions/25678373
                    self.urlComponents.host = nil
                    self.urlComponents.path = ""
                    if let value = row.value {
                        let path = value.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
                        if (path.count > 0) {self.urlComponents.host = path[0]}
                        if (path.count > 1) {self.urlComponents.path = "/" + path[1]} // CRITICAL path must start with "/..."
                    }
                }
            }}
        )
        
        section.append(SegmentedRow<String>("protocol") {
            $0.options = ["https", "http"]
            $0.title = "Protocol"
            }
            .onChange { row in
                row.title = (row.value == "https") ? "Protocol (secure)" :  "Protocol (insecure)"
                row.reload()
                
                self.urlComponents.scheme = row.value
                self.urlComponents.port = (row.value == "https") ? 443 : 80 // initialize default port: 80 (http) or 443 (https)
                self.refresh()
            }
        )

        section.append(IntRow("port") {
            $0.title = "Port"
            $0.onCellHighlightChanged { (cell, row) in // finished editting
                if !row.isHighlighted {
                    self.urlComponents.port = row.value
                }
            }}
        )
        
        section.append(ButtonRow("login") {
            $0.title = "Login"
            }
            .onCellSelection { cell, row in
                if !row.isDisabled {
                    self.login()
                }
            }
        )
        
        // ---------- App settings ----------
        
        //section = Section(header: "App", footer: "created by Xiphware")
        section = Section("App")
        form.append(section)
        
        section.append(TextRow("version") {
            $0.title = "Version"
            $0.disabled = true
            
            if let bundle = Bundle.main.infoDictionary {
                $0.value = (bundle[kCFBundleNameKey as String] as! String) + " " + // app
                    (bundle["CFBundleShortVersionString"] as! String) + "-" + // major.minor.patch
                    (bundle[kCFBundleVersionKey as String] as! String) // build
            }
        })
        
        section.append(TextRow("device") {
            $0.title = "Device"
            $0.disabled = true
            $0.value = device.model
            
            // https://stackoverflow.com/questions/26028918
            var sysinfo = utsname()
            uname(&sysinfo)
            if let model = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii) {
                $0.value?.append(" (" + model + ")")
            }
        })
        
        section.append(TextRow("os") {
            $0.title = "Operating System"
            $0.disabled = true
            $0.value = device.systemName + " " + device.systemVersion
        })
        
        section.append(ImageRow("github") {
            $0.title = "Source code"
            $0.value = UIImage.init(named: "icons8-github-33")?.withRenderingMode(.alwaysTemplate)
            $0.disabled = true // will disable image functions, but can still select cell to open URL
            }
            .cellSetup { cell, row in
                cell.tintColor = .control
            }
            .onCellSelection { cell, row in
                UIApplication.shared.open(URL(string: "https://github.com/tiritea")!, options: [:], completionHandler: nil)
            }
        )

        section.append(ImageRow("icons8") {
            $0.title = "Icons by Icons8™"
            $0.value = UIImage.init(named: "icons8-icons8-filled-33")?.withRenderingMode(.alwaysTemplate)
            $0.disabled = true // will disable image functions, but can still select cell to open URL
            }
            .cellSetup { cell, row in
                cell.tintColor = .control
            }
            .onCellSelection { cell, row in
                UIApplication.shared.open(URL(string: "https://icons8.com")!, options: [:], completionHandler: nil)
            }
        )

        // ---------- Other settings ----------
        
        section = Section("Settings")
        form.append(section)

        tag = "guidance"
        section.append(SwitchRow(tag) {
            $0.title = "Show guidance hints"
            $0.value = UserDefaults.standard.bool(forKey: tag)
            }
            .onChange { row in
                UserDefaults.standard.set(row.value, forKey: tag)
            }
        )
        
        tag = "auditlog"
        section.append(SwitchRow(tag) {
            $0.title = "Audit form changes"
            $0.value = UserDefaults.standard.bool(forKey: tag)
            }
            .onChange { row in
                UserDefaults.standard.set(row.value, forKey: tag)
            }
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // (re)populate server API and URL from defaults
        api = ServerAPI(rawValue: UserDefaults.standard.integer(forKey: "api")) // or 0 if not set

        if let urlString = UserDefaults.standard.string(forKey: "server") {
            urlComponents = URLComponents(string: urlString)
        } else {
            urlComponents = URLComponents() // initialize empty URL to be populated from rows
        }
        refresh()
    }
    
    // Update server section with current API & URL
    func refresh() {
        let loginRow = form.rowBy(tag: "login") as! ButtonRow
        loginRow.disabled = false

        let row = (form.rowBy(tag: "api") as! ActionSheetRow<String>)
        if api.rawValue != 0 {
            row.value = row.options![api.rawValue - 1]
        } else {
            row.value = nil
            loginRow.disabled = true // disable login if API not set
        }

        if let urlComponents = urlComponents {
            (form.rowBy(tag: "port") as! IntRow).value = urlComponents.port
            (form.rowBy(tag: "protocol") as! SegmentedRow<String>).value = urlComponents.scheme
            (form.rowBy(tag: "host") as! TextRow).value = urlComponents.host! + urlComponents.path
        } else {
            (form.rowBy(tag: "port") as! IntRow).value = nil
            (form.rowBy(tag: "protocol") as! SegmentedRow<String>).value = nil
            (form.rowBy(tag: "host") as! TextRow).value = nil
        }
        
        if urlComponents.url == nil {
            loginRow.disabled = true // disable login if invalid URL
        }
        
        form.sectionBy(tag: "server")!.reload()
        loginRow.evaluateDisabled() // https://github.com/xmartlabs/Eureka/issues/559
    }
  
    // MARK: Actions

    func login() {
        let loginController = UIAlertController(title: urlComponents.host,
                                                message: "\u{26A0} Changing servers will clear all saved forms and submissions.",
                                                preferredStyle: .alert)
        let keychain = KeychainSwift()

        loginController.addTextField(configurationHandler: { textField in
            textField.placeholder = "username"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.text = keychain.get("username")
        })
        
        loginController.addTextField(configurationHandler: { textField in
            textField.placeholder = "password"
            textField.keyboardType = .asciiCapable
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.isSecureTextEntry = true
            textField.text = keychain.get("password")
        })
        
        loginController.addAction(UIAlertAction(title: "Login", style: .destructive, handler: { action in
            let username = (loginController.textFields![0] as UITextField).text
            let password = (loginController.textFields![1] as UITextField).text
            let url = self.urlComponents.url
            
            let newserver: GSBServer
            switch self.api! { // must have valid API otherwise login disabled
            case .openrosa_aggregate: newserver = GSBOpenRosaServer(url: url)
            case .openrosa_central: newserver = GSBOpenRosaServer(url: url)
            case .openrosa_kobo: newserver = GSBKoboServer(url: url) // Kobo will append username to URL after login
            case .rest_central : newserver = GSBRESTServer(url: url)
            case .rest_gomobile: newserver = GSBRESTServer(url: url)
            }
            
            newserver.login(username: username, password: password, completion: { error in
                if (error == nil) {
                    os_log("login successful")
                    UserDefaults.standard.set(self.api.rawValue, forKey: "api")
                    UserDefaults.standard.set(url!.absoluteString, forKey: "server") // URL must be valid because login succeeded
                    server = newserver // switch to new server!
                } else {
                    UIAlertController.showAlert(title: "Login Failed", message: error?.localizedDescription, button: "Cancel")
                }
            })
        }))

        loginController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(loginController, animated: true)
    }
}
