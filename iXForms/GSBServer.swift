//
//  GSBServer.swift
//  iXForms
//
//  Created by MBS GoGet on 8/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import os.log

import RealmSwift
import KeychainSwift

enum ServerAPI: String, CaseIterable {
    case openrosa_aggregate = "OpenRosa (ODK Aggregate)"
    case openrosa_central = "OpenRosa (ODK Central)"
    case openrosa_kobo = "OpenRosa (KoboToolbox)"
    case rest_central = "REST (ODK Central)"
    case rest_gomobile = "REST (GoMobile)"
    case custom_gomobile = "Custom (GoMobile)"
}

protocol GSBServer {
    var url: URL! {get set}
    var token: String? {get set}
    
    init(url: URL!)
    func login(username: String!, password: String!)
    func getGroupList(completion: @escaping (Error?) -> Void)
    func getFormList(groupID: String!, completion: @escaping (Error?) -> Void)
    func getForm(formID: String!, groupID: String!, completion: @escaping (Error?) -> Void)
    func getSubmissionList(formID: String!, groupID: String!, completion: @escaping (Error?) -> Void)
    func getSubmission(submissionID: String!, formID: String!, groupID: String!, completion: @escaping (Error?) -> Void)
}

var server: GSBServer! // singleton

class GSBRESTServer: GSBServer, GSBListTableViewDataSource {
    var url: URL!
    var token: String?
    private let dateFormat = DateFormatter()

    required init(url: URL!) {
        os_log("%s.%s url=%s", #file, #function, url.absoluteString)
        self.url = url
        UserDefaults.standard.set(url.absoluteString, forKey: "server")
        
        dateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.S'Z'" // eg 2018-11-02T00:44:22.322Z
        dateFormat.locale = Locale.current
    }
    
    // <GSBListTableViewDataSource>
    func refresh(controller: GSBListTableViewController, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s", #file, #function)
        
        // Check controller type to determine what to refresh
        if let _ = controller as? GSBGroupListViewController {
            getGroupList(completion: completion)
        } else if let ctrl = controller as? GSBFormListViewController {
            getFormList(groupID: ctrl.groupID, completion: completion)
        } else {
            assertionFailure("unrecognized controller")
        }
    }

    // MARK: - API

    func login(username: String!, password: String!) {
        os_log("%s.%s username=%s", #file, #function, username)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/sessions")
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let json = ["email":username, "password":password]
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                let session = URLSession.shared.uploadTask(with: request, from: jsonData) { data, response, error in
                    do {
                        if (error != nil || (response as! HTTPURLResponse).statusCode != 200) {
                            throw NSError(domain: "login failed", code: 0, userInfo: [:])
                        }
                        
                        let result = try JSONSerialization.jsonObject(with: data!, options: []) as! Dictionary<String,String>
                        self.token = result["token"]
                        os_log("token=%s", self.token ?? "")
                        
                        // save username and password on successful login
                        let keychain = KeychainSwift()
                        keychain.set(username, forKey: "username")
                        keychain.set(password, forKey: "password")
                        
                        let db = try! Realm()
                        try! db.write {
                            db.deleteAll()
                        }
                    } catch {
                        os_log("ERROR login failed")
                    }
                }
                session.resume()
            } catch {
                os_log("ERROR malformed request")
            }
        }
    }
    
    func getGroupList(completion: @escaping (Error?) -> Void) {
        os_log("%s.%s", #file, #function)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects") // REST endpoint
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("true", forHTTPHeaderField: "X-Extended-Metadata") // include number of forms

            if let token = self.token {
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            }

            let session = URLSession.shared.dataTask(with: request) { data, response, error in
                do {
                    if (error != nil || (response as! HTTPURLResponse).statusCode != 200) {
                        throw NSError(domain: "iXForms", code: 0, userInfo: [:])
                    }
                    
                    let results = try JSONSerialization.jsonObject(with: data!, options: [.mutableContainers]) as! Array<Dictionary<String,Any>> // must be Any to handle possible null values!
                    os_log("%lu projects", results.count)
                    
                    let db = try! Realm()
                    for result in results {
                        os_log("result: %@", result)
                        
                        try db.write {
                            var group = db.object(ofType: Group.self, forPrimaryKey: String(result["id"] as! Int)) // FIX
                            if (group == nil) {
                                // if not, create new form
                                group = Group()
                                group!.id = String(result["id"] as! Int)
                            }
                            self.updateGroupWithDictionary(group: group!, dict: result)
                            db.create(Group.self, value: group!, update: .all) // replace existing group
                        }
                    }
                    completion(nil) // Success!
                } catch {
                    os_log("ERROR getGroupList failed")
                    completion(NSError(domain: "iXForms", code: 0, userInfo: [NSLocalizedDescriptionKey: "getGroupList failed"]))
                }
            }
            session.resume()
        } else {
            os_log("Bad URL")
            completion(NSError(domain: "iXForms", code: 0, userInfo: [NSLocalizedDescriptionKey: "bad URL"]))
        }
    }
    
    func getFormList(groupID: String!, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s groupID=%s", #file, #function, groupID)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects/" + groupID + "/forms") // REST endpoint; "groups" -> projects
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = self.token {
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            }
            
            let session = URLSession.shared.dataTask(with: request) { data, response, error in
                do {
                    if (error != nil || (response as! HTTPURLResponse).statusCode != 200) {
                        throw NSError(domain: "iXForms", code: 0, userInfo: [:])
                    }
                    
                    let results = try JSONSerialization.jsonObject(with: data!, options: [.mutableContainers]) as! Array<Dictionary<String,Any>> // must be Any to handle possible null values!
                    os_log("%lu forms", results.count)
                    
                    let db = try! Realm()
                    for result in results {
                        os_log("result: %@", result)
                        
                        try db.write {
                            // check if form previously loaded
                            var xform = db.object(ofType: XForm.self, forPrimaryKey: result["xmlFormId"] as! String)
                            if (xform == nil) {
                                // if not, create new form
                                xform = XForm()
                                xform!.id = (result["xmlFormId"] as! String)
                            }
                            self.updateFormWithDictionary(form: xform!, dict: result)
                            db.create(XForm.self, value: xform!, update: .all) // replace existing form
                        }
                    }
                    completion(nil) // Success!
                } catch {
                    os_log("ERROR getFormList failed")
                    completion(NSError(domain: "iXForms", code: 0, userInfo: [NSLocalizedDescriptionKey: "getFormList failed"]))
                }
            }
            session.resume()
        } else {
            os_log("Bad URL")
            completion(NSError(domain: "iXForms", code: 0, userInfo: [NSLocalizedDescriptionKey: "bad URL"]))
        }
    }

    func getForm(formID: String!, groupID: String!, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s groupID=%s formID=", #file, #function, groupID, formID)

        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects/" + groupID + "/forms/" + formID) // REST endpoint
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("true", forHTTPHeaderField: "X-Extended-Metadata") // include XML form definition
            
            if let token = self.token {
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            }
            
            let session = URLSession.shared.dataTask(with: request) { data, response, error in
                do {
                    if (error != nil || (response as! HTTPURLResponse).statusCode != 200) {
                        throw NSError(domain: "iXForms", code: 0, userInfo: [:])
                    }

                    let result = try JSONSerialization.jsonObject(with: data!, options: [.mutableContainers]) as! Dictionary<String,Any> // must be Any to handle possible null values!
                    //os_log("result: %@", result)
                    let db = try! Realm()
                    try db.write {
                        let xform = db.object(ofType: XForm.self, forPrimaryKey: result["xmlFormId"] as! String)! // must alrady exist
                        
                        // TEST reset parser when open form
                        xform.instances.removeAll();
                        xform.bindings.removeAll();
                        xform.controls.removeAll();

                        self.updateFormWithDictionary(form: xform, dict: result)
                        //db.create(XForm.self, value: xform, update: .all)
                    }
                    completion(nil) // Success!
                } catch {
                    os_log("ERROR getForm failed")
                    completion(NSError(domain: "iXForms", code: 0, userInfo: [NSLocalizedDescriptionKey: "getForm failed"]))
                }
            }
            session.resume()
        } else {
            os_log("Bad URL")
            completion(NSError(domain: "iXForms", code: 0, userInfo: [NSLocalizedDescriptionKey: "bad URL"]))
        }
    }

    func getSubmissionList(formID: String!, groupID: String!, completion: @escaping (Error?) -> Void) {
        
    }
    
    func getSubmission(submissionID: String!, formID: String!, groupID: String!, completion: @escaping (Error?) -> Void) {
        
    }

    // MARK: - Utility functions

    private func updateGroupWithDictionary(group: Group, dict: Dictionary<String, Any>) {
        group.name = dict["name"] as? String

        if let created = dict["createdAt"] as? String {
            group.created = dateFormat.date(from: created)
        }
        
        if let updated = dict["updatedAt"] as? String {
            group.updated = dateFormat.date(from: updated)
        }
        
        if let updated = dict["lastSubmission"] as? String {
            group.lastSubmission = dateFormat.date(from: updated)
        }

        if let forms = dict["forms"] as? NSNumber {
            group.forms.value = forms.intValue // RealmOptional
        }
        
        if let users = dict["appUsers"] as? NSNumber {
            group.users.value = users.intValue // RealmOptional
        }

        if let archived = dict["archived"] as? NSNumber {
            group.archived.value = (archived == 1) ? true : false // RealmOptional
        }
    }
    
    private func updateFormWithDictionary(form: XForm, dict: Dictionary<String, Any>) {
        form.name = dict["name"] as? String
        form.version = dict["version"] as? String
        form.xmlHash = dict["hash"] as? String
        
        switch dict["state"] as! String {
        case "open":
            form.state.value = FormState.open.rawValue
        case "closing":
            form.state.value = FormState.closing.rawValue
        case "closed":
            form.state.value = FormState.closed.rawValue
        default:
            assertionFailure("unrecognized state")
        }

        if let created = dict["createdAt"] as? String {
            form.created = dateFormat.date(from: created)
        }
        
        if let updated = dict["updatedAt"] as? String {
            form.updated = dateFormat.date(from: updated)
        }
        
        if let xml = dict["xml"] as? String {
            form.xml = xml
        }

        if let createdBy = dict["createdBy"] as? Dictionary<String,Any> {
            form.author = createdBy["displayName"] as? String
        }
        
        if let lastSubmission = dict["lastSubmission"] as? String {
            form.lastSubmission = dateFormat.date(from: lastSubmission)
        }
        
        if let submissions = dict["submissions"] as? NSNumber {
            form.numRecords.value = submissions.intValue
        }
    }
}
