//
//  GSBSettingsViewController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Eureka
import os.log
import KeychainSwift

enum ServerAPI: String, CaseIterable {
    case openrosa_aggregate = "OpenRosa (ODK Aggregate)"
    case openrosa_central = "OpenRosa (ODK Central)"
    case openrosa_kobo = "OpenRosa (KoboToolbox)"
    case rest_central = "REST (ODK Central)"
    case rest_gomobile = "REST (GoMobile)"
    case custom_gomobile = "Custom (GoMobile)"
}

class GSBSettingsViewController: FormViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (self.tabBarItem != nil) {self.title = self.tabBarItem.title} // BUG not working?

        var section: Section
        
        // ---------- Client section ----------
        
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
        
        let device = UIDevice.current
        
        section.append(TextRow("device") {
            $0.title = "Device"
            $0.disabled = true

            // https://stackoverflow.com/questions/26028918
            var sysinfo = utsname()
            uname(&sysinfo)
            if let model = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii) {
                $0.value = device.model + " (" + model + ")"
            }
        })
        
        section.append(TextRow("os") {
            $0.title = "Operating System"
            $0.disabled = true
            $0.value = device.systemName + " " + device.systemVersion
        })
        
        // ---------- Server section ----------
        
        section = Section("Server")
        form.append(section)
        
        var url: URL?
        if let urlString = UserDefaults.standard.string(forKey: "server") {
            url = URL(string: urlString)
        }
        
        section.append(TextRow("server") {
            $0.title = "Host"
            $0.placeholder = "hostname/path"
            $0.value = url?.host
            }
            .cellSetup { cell, row in
                cell.textField.keyboardType = .asciiCapable
                cell.textField.autocapitalizationType = .none
                cell.textField.autocorrectionType = .no
            }
            .onChange { row in
                self.updateURL()
            }
        )
        
        section.append(ActionSheetRow<String>("api") {
            $0.title = "API"
            $0.options = ServerAPI.allCases.map{ $0.rawValue }
            
            let api = UserDefaults.standard.integer(forKey: "api") // will default to 0 if not found
            $0.value = $0.options![api]
            }
            .onChange { row in
                // save to defaults
                if let selected = row.value, let index = row.options!.index(of: selected) {
                    UserDefaults.standard.set(index, forKey: "api")
                    os_log("server API=%s [%lu]", selected, index)
                }
            }
        )

        section.append(SegmentedRow<String>("protocol") {
            $0.options = ["https", "http"]
            $0.title = "Protocol"
            $0.value = url?.scheme
            }
            .cellSetup { cell, row in
                // Minimize segment width - https://github.com/xmartlabs/Eureka/issues/973
                cell.segmentedControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            }
            .onChange { row in
                // Update title: http=insecure https=secure
                row.title = (row.value == "https") ? "Protocol (secure)" :  "Protocol (insecure)"
                row.updateCell()
                
                // Update port: http=80 https=443
                let port = self.form.rowBy(tag: "port") as! IntRow
                port.value = (row.value == "https") ? 443 : 80
                port.updateCell()
                
                self.updateURL()
            }
        )
        
        section.append(IntRow("port") {
            $0.title = "Port"
            $0.value = url?.port
            
            // remove separator (eg "1,234" -> "1234")
            $0.useFormatterDuringInput = true
            let formatter = NumberFormatter()
            formatter.groupingSeparator = ""
            $0.formatter = formatter
            }
            .onChange { row in
                self.updateURL()
            }
        )
        
        // ---------- Login section ----------
        
        section = Section("")
        form.append(section)

        section.append(ButtonRow("login") {
            $0.title = "Login"
            }
            .cellSetup { cell, row in
                cell.tintColor = UIColor.red
                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline) // bold
            }
            .onCellSelection { cell, row in
                self.login()
            }
        )
    }
    
    func updateURL() {
        var components = URLComponents()
        components.port = (self.form.rowBy(tag: "port") as! IntRow).value
        components.scheme = (self.form.rowBy(tag: "protocol") as! SegmentedRow).value
        
        if let server = (self.form.rowBy(tag: "server") as! TextRow).value {
            // https://stackoverflow.com/questions/25678373
            let paths = server.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)

            if (paths.count > 0) {components.host = paths[0]}
            if (paths.count > 1) {components.path = "/" + paths[1]} // CRITICAL url path must start with "/..."
            
            if let url = components.url {
                // save to defaults
                let urlString = url.absoluteString
                UserDefaults.standard.set(urlString, forKey: "server")
                os_log("server URL=%s", urlString)
            }
        }
    }
    
    func login() {
        if let urlString = UserDefaults.standard.string(forKey: "server"),
            let url = URL(string: urlString),
            let host = url.host
        {
            let api = UserDefaults.standard.integer(forKey: "api")
            let keychain = KeychainSwift()

            let loginController = UIAlertController(title: nil, message: host, preferredStyle: .alert)
            
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
            
            loginController.addAction(UIAlertAction(title: "Login",
                                                    style: .destructive, // red
                handler: { action in
                    let username = (loginController.textFields![0] as UITextField).text
                    let password = (loginController.textFields![1] as UITextField).text
                    currentServer = GSBServer.init(url: url, api: api)
                    currentServer!.login(username: username, password: password)
            }))
            
            loginController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            self.present(loginController, animated: true)
        }
    }
}
