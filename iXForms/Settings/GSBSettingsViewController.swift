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
    
    let controlColor = UIColor(hex: 0x4682B4) // HTML SteelBlue
    
    // MARK: Eureka Form

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let device = UIDevice.current
        var section: Section
        
        TextRow.defaultCellSetup = { (cell, row) in
            cell.textField.keyboardType = .asciiCapable
            cell.textField.autocapitalizationType = .none
            cell.textField.autocorrectionType = .no
        }
        TextRow.defaultCellUpdate = { (cell, row) in
            cell.textField.textColor = .systemDetailTextLabel
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
            cell.tintColor = self.controlColor
        }

        SwitchRow.defaultCellSetup = { (cell, row) in
            cell.switchControl.tintColor = self.controlColor
            cell.switchControl.onTintColor = self.controlColor
        }

        ButtonRow.defaultCellSetup = { (cell, row) in
            cell.tintColor = UIColor.white
            cell.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline) // bold
            cell.backgroundColor = UIColor.red
        }

        // ---------- Server section ----------
        
        section = Section("Server")
        form.append(section)
        
        // Note: ServerAPI enum starts a 1!
        section.append(ActionSheetRow<String>("api") {
            $0.title = "API"
            $0.options = ServerAPI.allCases.map{ $0.description }
            if let api = ServerAPI(rawValue: UserDefaults.standard.integer(forKey: "api")) {
                $0.value = $0.options![api.rawValue - 1]
            }}
            .onChange { row in
                if let selected = row.value, let index = row.options!.index(of: selected) {
                    let api = ServerAPI(rawValue: index+1)!
                    UserDefaults.standard.set(api.rawValue, forKey: "api")

                    // also initialize url to the default server for this API
                    let url = api.server
                    UserDefaults.standard.set(url?.absoluteString, forKey: "server")
                    self.refresh()
                }
            }
        )

        section.append(TextRow("host") {
            $0.title = "Host"
            $0.placeholder = "hostname/path"
            $0.onCellHighlightChanged { (cell, row) in // finished editting
                if !row.isHighlighted {
                    self.save()
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
                
                // also initialize default port: 80 (http) or 443 (https)
                let port = self.form.rowBy(tag: "port") as! IntRow
                port.value = (row.value == "https") ? 443 : 80
                port.reload()
                
                self.save()
            }
        )

        section.append(IntRow("port") {
            $0.title = "Port"
            $0.onCellHighlightChanged { (cell, row) in // finished editting
                if !row.isHighlighted {
                    self.save()
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
        
        // ---------- App section ----------
        
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
        
        section.append(ImageRow("icons8") {
            $0.title = "Icons by icons8"
            $0.value = UIImage.init(named: "icons8-icons8-33")?.withRenderingMode(.alwaysTemplate)
            $0.disabled = true // will disable image functions, but can still select cell to open URL
            }
            .cellSetup { cell, row in
                cell.tintColor = self.controlColor
                cell.accessoryView = UIImageView(image: UIImage.init(named: "icons8-33")?.withRenderingMode(.alwaysTemplate))
            }
            .onCellSelection { cell, row in
                UIApplication.shared.open(URL(string: "https://icons8.com")!, options: [:], completionHandler: nil)
            }
        )

        // ---------- Settings section ----------
        
        section = Section("Settings")
        form.append(section)

        section.append(SwitchRow("guidance") {
            $0.title = "Show guidance hints"
            $0.value = UserDefaults.standard.bool(forKey: "showguidance")
            }
            .onChange { row in
                UserDefaults.standard.set(row.value, forKey: "showguidance")
            }
        )

        
        refresh() // load URL to populate server settings
    }
    
    // MARK: UserDefaults

    // Load server settings from UserDefaults
    func refresh() {
        var disableLogin = false
        if let urlString = UserDefaults.standard.string(forKey: "server"), let components = URLComponents(string: urlString) {
            os_log("%s.%s server=%s", #file, #function, urlString)

            (form.rowBy(tag: "port") as! IntRow).value = components.port
            (form.rowBy(tag: "protocol") as! SegmentedRow<String>).value = components.scheme // ??? not sure why this doesnt trigger onChange save/refresh infinite loop...
            
            let hostRow = form.rowBy(tag: "host") as! TextRow
            hostRow.value = components.host
            hostRow.value!.append(components.path)
        } else {
            disableLogin = true
        }
        form.sectionBy(tag: "Server")?.reload()
        
        // Enable login only if have valid URL and API
        let loginRow = form.rowBy(tag: "login") as! ButtonRow
        loginRow.disabled = Condition(booleanLiteral: disableLogin || ServerAPI(rawValue: UserDefaults.standard.integer(forKey: "api")) == nil) // https://github.com/xmartlabs/Eureka/issues/1393
        loginRow.evaluateDisabled() // https://github.com/xmartlabs/Eureka/issues/559
    }

    // Save server settings to UserDefaults
    func save() {
        var components = URLComponents()
        components.port = (form.rowBy(tag: "port") as! IntRow).value
        components.scheme = (form.rowBy(tag: "protocol") as! SegmentedRow).value
        
        if let host = (form.rowBy(tag: "host") as! TextRow).value {
            // https://stackoverflow.com/questions/25678373
            let paths = host.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            if (paths.count > 0) {components.host = paths[0]}
            if (paths.count > 1) {components.path = "/" + paths[1]} // CRITICAL path must start with "/..."
            if let url = components.url {
                let urlString = url.absoluteString
                UserDefaults.standard.set(urlString, forKey: "server")
                os_log("%s.%s server=%s", #file, #function, urlString)
            }
        }
        refresh()
    }
  
    // MARK: Actions

    func login() {
        // Should never get here unless have URL and API
        let url = URL(string: UserDefaults.standard.string(forKey: "server")!)!
        let api = ServerAPI(rawValue: UserDefaults.standard.integer(forKey: "api"))!
        
        let loginController = UIAlertController(title: url.host,
                                                message: "\u{26A0} Changing the server will clear all previous forms and submissions.",
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
            
            let newserver: GSBServer
            switch api {
            case .openrosa_aggregate: newserver = GSBOpenRosaServer(url: url)
            case .openrosa_central: newserver = GSBOpenRosaServer(url: url)
            case .openrosa_kobo: newserver = GSBKoboServer(url: url) // will append username to URL after login
            case .rest_central : newserver = GSBRESTServer(url: url)
            case .rest_gomobile: newserver = GSBRESTServer(url: url)
            }
            
            newserver.login(username: username, password: password, completion: { error in
                if (error == nil) {
                    // clear database if changing server
                    if (newserver.url.absoluteString != server?.url.absoluteString) {
                        let db = try! Realm()
                        try! db.write {
                            os_log("clearing database")
                            db.deleteAll()
                        }
                    }
                    server = newserver
                }
            })
        }))

        loginController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(loginController, animated: true)
    }
}
