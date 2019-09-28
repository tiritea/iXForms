//
//  GSBRESTServer.swift
//  iXForms
//
//  Created by MBS GoGet on 8/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import os.log

import RealmSwift
import KeychainSwift

class GSBRESTServer: NSObject, GSBServer, URLSessionDelegate {
    var url: URL!
    var hasProjects: Bool! = true
    
    private var token: String?
    private let dateFormatter = DateFormatter()
    
    // MARK: <GSBServer>

    required init(url: URL!) {
        os_log("%s.%s url=%s", #file, #function, url.absoluteString)
        self.url = url
        
        token = KeychainSwift().get("token")
        os_log("token = %s", token ?? "(null)")

        dateFormatter.dateFormat = DATETIMEFORMAT
        dateFormatter.locale = Locale.current
    }
    
    func login(username: String!, password: String!, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s username=%s", #file, #function, username)

        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/sessions")
            var request = URLRequest(url: components.url!)
            os_log("url=%s", request.url!.absoluteString)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let json = ["email":username, "password":password]
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                
                // let session = URLSession.shared.uploadTask(with: request, from: jsonData) { data, response, error in
                // ...
                // session.resume()

                // .default configuration will cause subsequent logins to fail with 401
                // see https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1410529-ephemeral
                let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
                let postTask = session.uploadTask(with: request, from: jsonData) { data, response, error in
                    do {
                        let code = (response as! HTTPURLResponse).statusCode
                        if (code != 200) {
                            let error = NSError(domain: Bundle.main.bundleIdentifier!,
                                                code: code,
                                                userInfo: [NSLocalizedDescriptionKey: String(code) + " - " + HTTPURLResponse.localizedString(forStatusCode: code)])
                            os_log("ERROR: %s", error.localizedDescription)
                            throw error
                        }
                        
                        let result = try JSONSerialization.jsonObject(with: data!, options: []) as! Dictionary<String,String>
                        self.token = result["token"]! // always get token back on successful login!
                        os_log("token=%s", self.token!)
                        
                        // save username and password on successful login
                        let keychain = KeychainSwift()
                        keychain.set(username, forKey: "username")
                        keychain.set(password, forKey: "password")
                        keychain.set(self.token!, forKey: "token")
                        
                        completion(nil) // no error
                    } catch {
                        completion(error)
                    }
                }
                postTask.resume()
            } catch {
                assertionFailure("malformed request")
            }
        }
    }
    
    func getProjectList(completion: @escaping (Error?) -> Void) {
        os_log("%s.%s", #file, #function)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects")
            
            var request = URLRequest(url: components.url!)
            os_log("url=%s", request.url!.absoluteString)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("true", forHTTPHeaderField: "X-Extended-Metadata") // include number of forms

            if let token = token {
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            }

            let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
            let getTask = session.dataTask(with: request) { data, response, error in
                do {
                    let status = (response as! HTTPURLResponse).statusCode
                    if (error != nil || status != 200) {
                        let error = NSError(domain: APP, code: 0, userInfo: [NSLocalizedDescriptionKey: "getProjectList failed"])
                        os_log("%d %s", status, error.localizedDescription)
                        throw error
                    }
                    
                    let results = try JSONSerialization.jsonObject(with: data!, options: [.mutableContainers]) as! Array<Dictionary<String,Any>> // must be Any to handle possible null values!
                    os_log("%lu projects", results.count)
                    
                    let db = try! Realm()
                    for result in results {
                        os_log("%@", result)
                        try db.write {
                            var project = db.object(ofType: Project.self, forPrimaryKey: String(result["id"] as! Int)) // FIX
                            if (project == nil) {
                                // if not, create new project
                                project = Project()
                                project!.id = String(result["id"] as! Int)
                            }
                            self.updateProjectWithDictionary(project: project!, dict: result)
                            db.create(Project.self, value: project!, update: .all) // replace existing group
                        }
                    }
                    completion(nil) // no error
                } catch {
                    completion(error)
                }
            }
            getTask.resume()
        } else {
            assertionFailure("malformed request")
        }
    }
    
    func getFormList(projectID: String!, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s projectID=%s", #file, #function, projectID)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects/" + projectID + "/forms")
            
            var request = URLRequest(url: components.url!)
            os_log("url=%s", request.url!.absoluteString)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("true", forHTTPHeaderField: "X-Extended-Metadata") // include submissions, createdBy, ...

            if let token = token {
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            }
            
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let getTask = session.dataTask(with: request) { data, response, error in
                do {
                    let status = (response as! HTTPURLResponse).statusCode
                    if (error != nil || status != 200) {
                        let error = NSError(domain: APP, code: 0, userInfo: [NSLocalizedDescriptionKey: "getFormList failed"])
                        os_log("%d %s", status, error.localizedDescription)
                        throw error
                    }
                    
                    let results = try JSONSerialization.jsonObject(with: data!, options: [.mutableContainers]) as! Array<Dictionary<String,Any>> // must be Any to handle possible null values!
                    os_log("%lu forms", results.count)
                    
                    let db = try! Realm()
                    for result in results {
                        os_log("result: %@", result)
                        let formid = result["xmlFormId"] as! String
                        try db.write {
                            // check if form previously loaded
                            var xform = db.object(ofType: XForm.self, forPrimaryKey: formid)
                            if (xform == nil) {
                                // if not, create new form
                                os_log("adding new form '%s'", formid)
                                xform = XForm()
                                xform!.id = formid
                            }
                            self.updateFormWithDictionary(form: xform!, dict: result)
                            xform?.projectID = projectID
                            db.create(XForm.self, value: xform!, update: .all) // replace existing form
                        }
                    }
                    completion(nil) // no error
                } catch {
                    completion(error)
                }
            }
            getTask.resume()
        } else {
            assertionFailure("malformed request")
        }
    }

    func getForm(formID: String!, projectID: String!, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s projectID=%s formID=%s", #file, #function, projectID, formID)

        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects/" + projectID + "/forms/" + formID) // REST endpoint for XForm definition
            components.path.append(".xml")

            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.setValue("text/xml", forHTTPHeaderField: "Content-Type")
            
            if let token = self.token {
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            }
            
            let session = URLSession.shared.dataTask(with: request) { data, response, error in
                do {
                    if (error != nil || (response as! HTTPURLResponse).statusCode != 200) {
                        throw NSError(domain: "", code: 0, userInfo: [:])
                    }
                    
                    if let result = String(data: data!, encoding: .utf8) {
                        let db = try! Realm()
                        try db.write {
                            let xform = db.object(ofType: XForm.self, forPrimaryKey: formID)! // form must alrady exist
                            xform.xml = result
                        }
                        completion(nil) // Success!
                    }
                } catch {
                    os_log("ERROR getForm failed")
                    completion(NSError(domain: "iXForms", code: 0, userInfo: [NSLocalizedDescriptionKey: "getForm failed"]))
                }
            }
            session.resume()
        } else {
            assertionFailure("malformed request")
        }
    }

    func getSubmissionList(formID: String!, projectID: String!, completion: @escaping (Error?) -> Void) {}
    
    func getSubmission(submissionID: String!, formID: String!, projectID: String!, completion: @escaping (Error?) -> Void) {}

    // MARK: - Utility functions

    private func updateProjectWithDictionary(project: Project, dict: Dictionary<String, Any>) {
        project.name = dict["name"] as? String

        if let created = dict["createdAt"] as? String {
            project.created = dateFormatter.date(from: created)
        }
        
        if let updated = dict["updatedAt"] as? String {
            project.updated = dateFormatter.date(from: updated)
        }
        
        if let updated = dict["lastSubmission"] as? String {
            project.lastSubmission = dateFormatter.date(from: updated)
        }

        if let forms = dict["forms"] as? NSNumber {
            project.forms.value = forms.intValue // RealmOptional
        }
        
        if let users = dict["appUsers"] as? NSNumber {
            project.users.value = users.intValue // RealmOptional
        }

        if let archived = dict["archived"] as? NSNumber {
            project.archived.value = (archived == 1) ? true : false // RealmOptional
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
            form.created = dateFormatter.date(from: created)
        }
        
        if let updated = dict["updatedAt"] as? String {
            form.updated = dateFormatter.date(from: updated)
        }
        
        if let createdBy = dict["createdBy"] as? Dictionary<String,Any> {
            form.author = createdBy["displayName"] as? String
        }
        
        if let lastSubmission = dict["lastSubmission"] as? String {
            form.lastSubmission = dateFormatter.date(from: lastSubmission)
        }
        
        if let submissions = dict["submissions"] as? NSNumber {
            form.numRecords.value = submissions.intValue
        }
    }
    
    // MARK: <GSBListTableViewDataSource>
    
    func refresh(controller: GSBListTableViewController, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s", #file, #function)
        
        // Check controller type to determine what to refresh
        if controller is GSBProjectListViewController {
            getProjectList(completion: completion)
        } else if let ctrl = controller as? GSBFormListViewController {
            getFormList(projectID: ctrl.projectID, completion: completion)
        } else {
            assertionFailure("unrecognized controller")
        }
    }
    
    // MARK: <URLSessionDelegate>

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        os_log("%s.%s count=%d", #file, #function, challenge.previousFailureCount)
        completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust:challenge.protectionSpace.serverTrust!))
    }
}
