//
//  GSBOpenRosaServer.swift
//  iXForms
//
//  Created by MBS GoGet on 8/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import os.log

import RealmSwift
import KeychainSwift
import XMLMapper

class GSBOpenRosaServer: GSBServer {
    var url: URL!
    var basic: String?

    // MARK: <GSBListTableViewDataSource>
    
    func refresh(controller: GSBListTableViewController, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s", #file, #function)
        
        // Check controller type to determine what to refresh
        if let ctrl = controller as? GSBFormListViewController {
            getFormList(projectID: ctrl.projectID, completion: completion)
        } else {
            assertionFailure("unrecognized controller")
        }
    }

    // MARK: <GSBServer>

    required init(url: URL!) {
        os_log("%s.%s url=%s", #file, #function, url.absoluteString)
        self.url = url
    }
    
    func login(username: String!, password: String!, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s username=%s", #file, #function, username)
        
        // Basic authentication
        let str = username + ":" + password
        basic = str.data(using: .utf8)?.base64EncodedString()
        
        // save username and password on successful login
        let keychain = KeychainSwift()
        keychain.set(username, forKey: "username")
        keychain.set(password, forKey: "password")
        
        completion(nil) // 'login' always succeeds
    }
    
    func getProjectList(completion: @escaping (Error?) -> Void) -> Bool {
        os_log("%s.%s", #file, #function)
        return false
    }
    
    func getFormList(projectID: String!, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s projectID=%s", #file, #function, projectID)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/xformsList")
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"

            if let basic = self.basic {
                request.setValue("Basic " + basic, forHTTPHeaderField: "Authorization")
            }
            
            let session = URLSession.shared.dataTask(with: request) { data, response, error in
                do {
                    if (error != nil || (response as! HTTPURLResponse).statusCode != 200) {
                        throw NSError(domain: "iXForms", code: 0, userInfo: [:])
                    }
                    
                    // Decode XML to Array of Dictionary using XMLMapper - https://stackoverflow.com/questions/31083348/parsing-xml-from-url-in-swift
                    let dict = try XMLSerialization.xmlObject(with: data!) as! [String: Any]
                    let results: Array<Dictionary<String,Any>>
                    // WORKAROUND: if single form then XMLSerialization returns xform result as single *Dictionary*, so convert to *single element Array* instead
                    if dict["xform"] is Dictionary<String,Any> {
                        results = [dict["xform"]] as! Array<Dictionary<String,Any>>
                    } else {
                        results = dict["xform"] as! Array<Dictionary<String,Any>>
                    }
                    os_log("%lu forms", results.count)
                    
                    let db = try! Realm()
                    for result in results {
                        os_log("result: %@", result)
                        
                        try db.write {
                            // check if form previously loaded
                            var xform = db.object(ofType: XForm.self, forPrimaryKey: result["formID"] as! String)
                            if (xform == nil) {
                                // if not, create new form
                                xform = XForm()
                                xform!.id = (result["formID"] as! String)
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

    func getForm(formID: String!, projectID: String!, completion: @escaping (Error?) -> Void) {
        os_log("%s.%s projectID=%s formID=%s", #file, #function, projectID, formID)

        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/formXml")
            components.query = "formId=" + formID
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"

            if let basic = self.basic {
                request.setValue("Basic " + basic, forHTTPHeaderField: "Authorization")
            }

            let session = URLSession.shared.dataTask(with: request) { data, response, error in
                do {
                    os_log("response: %d", (response as! HTTPURLResponse).statusCode)

                    if (error != nil || (response as! HTTPURLResponse).statusCode != 200) {
                        throw NSError(domain: "iXForms", code: 0, userInfo: [:])
                    }

                    let result = String.init(data: data!, encoding: .utf8)
                    
                    let db = try! Realm()
                    try db.write {
                        let xform = db.object(ofType: XForm.self, forPrimaryKey: formID)! // must alrady exist
                        xform.xml = result
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

    func getSubmissionList(formID: String!, projectID: String!, completion: @escaping (Error?) -> Void) {}
    
    func getSubmission(submissionID: String!, formID: String!, projectID: String!, completion: @escaping (Error?) -> Void) {}

    // MARK: - Utility functions
    
    private func updateFormWithDictionary(form: XForm, dict: Dictionary<String, Any>) {
        form.name = dict["name"] as? String
        form.version = dict["version"] as? String
        form.xmlHash = dict["hash"] as? String
        form.state.value = FormState.open.rawValue
        form.url = dict["downloadUrl"] as? String // Realm cant store NSURL
    }
}
