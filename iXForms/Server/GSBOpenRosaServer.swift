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
    var hasProjects: Bool! = false

    private var basic: String?

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
    
    // MARK: Login

    func login(username: String!, password: String!, completion: @escaping (Error?) -> Void) {
        os_log("[%@ %s] username=%@", String(describing: Self.self), #function, username)

        // Basic authentication
        let str = username + ":" + password
        basic = str.data(using: .utf8)?.base64EncodedString()
        
        // save username and password on successful login
        let keychain = KeychainSwift()
        keychain.set(username, forKey: "username")
        keychain.set(password, forKey: "password")
        
        completion(nil) // login always succeeds
    }
    
    func getProjectList(completion: @escaping (Error?) -> Void) {} // unsupported
    
    // MARK: Form List

    func getFormList(projectID: String?, completion: @escaping (Error?) -> Void) {
        os_log("[%@ %s] projectID='%s'", String(describing: Self.self), #function, projectID ?? "none")

        guard var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) else {
            assertionFailure("bad URL")
            return
        }
        
        components.path.append("/xformsList")
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        os_log("[%@ %s] %@ %@", String(describing: Self.self), #function, request.httpMethod!, request.url!.absoluteString)

        if let basic = self.basic {
            request.setValue("Basic " + basic, forHTTPHeaderField: "Authorization")
        }
        
        let session = URLSession.shared.dataTask(with: request) { data, response, error in
            do {
                guard error == nil else { throw error! }

                let statusCode = (response as! HTTPURLResponse).statusCode
                os_log("[%@ %s] status=%d", String(describing: Self.self), #function, statusCode)
                guard statusCode / 100 == 2 else { // 2xx = Success
                    throw NSError(domain: Bundle.main.bundleIdentifier!, code: statusCode, userInfo: [NSLocalizedDescriptionKey: "getFormList failed"])
                }

                guard data != nil else {
                    throw NSError(domain: Bundle.main.bundleIdentifier!, code: 444, userInfo: [NSLocalizedDescriptionKey: "no response"])
                }
                
                print(String(data: data!, encoding: .utf8)!)

                // Decode XML to Array of Dictionary, one per form
                let xml = try XMLSerialization.xmlObject(with: data!) as! [String: Any]
                let forms: Array<Dictionary<String,Any>>
                // WORKAROUND: if single form then XMLSerialization returns single *Dictionary*, so convert to *single element Array* instead
                if xml["xform"] is Dictionary<String,Any> {
                    forms = [xml["xform"]] as! Array<Dictionary<String,Any>>
                } else {
                    forms = xml["xform"] as! Array<Dictionary<String,Any>>
                }
                print(forms.count, "forms")
                
                let db = try! Realm()
                for form in forms {
                    try db.write {
                        // check if form previously loaded
                        var xform = db.object(ofType: XForm.self, forPrimaryKey: form["formID"] as! String)
                        if (xform == nil) {
                            // if not, create new form
                            xform = XForm()
                            xform!.id = (form["formID"] as! String)
                        }
                        self.updateFormWithDictionary(form: xform!, dict: form)
                        db.create(XForm.self, value: xform!, update: .all) // replace existing form
                    }
                }
                completion(nil) // Success
            } catch let error {
                print(error.localizedDescription)
                completion(error)
            }
        }
        session.resume()
    }

    // MARK: Form

    func getForm(formID: String!, projectID: String?, completion: @escaping (Error?) -> Void) {
        os_log("[%@ %s] projectID='%s' formID='%s'", String(describing: Self.self), #function, projectID ?? "none", formID)

        let db = try! Realm()
        guard let xform = db.object(ofType: XForm.self, forPrimaryKey: formID) else {
            completion(NSError(domain: Bundle.main.bundleIdentifier!, code: 404, userInfo: [NSLocalizedDescriptionKey: "unknown form"]))
            return
        }
        
        guard xform.url != nil, let url = URL(string: xform.url!) else {
            completion(NSError(domain: Bundle.main.bundleIdentifier!, code: 400, userInfo: [NSLocalizedDescriptionKey: "missing or malformed form URL"]))
            return
        }
        
        // ODK Aggregate
        //components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false)
        //components.path.append("/formXml")
        //components.query = "formId=" + formID
        //let url = components.url!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        os_log("[%@ %s] %@ %@", String(describing: Self.self), #function, request.httpMethod!, request.url!.absoluteString)

        if let basic = self.basic {
            request.setValue("Basic " + basic, forHTTPHeaderField: "Authorization")
        }
        
        let session = URLSession.shared.dataTask(with: request) { data, response, error in
            do {
                guard error == nil else { throw error! }
                
                let statusCode = (response as! HTTPURLResponse).statusCode
                os_log("[%@ %s] status=%d", String(describing: Self.self), #function, statusCode)
                guard statusCode / 100 == 2 else { // 2xx = Success
                    throw NSError(domain: Bundle.main.bundleIdentifier!, code: statusCode, userInfo: [NSLocalizedDescriptionKey: "getForm failed"])
                }

                guard data != nil else {
                    throw NSError(domain: Bundle.main.bundleIdentifier!, code: 444, userInfo: [NSLocalizedDescriptionKey: "no response"])
                }
                
                let db = try! Realm()
                try db.write {
                    // XForm must already exist (from earlier formList)
                    if let xform = db.object(ofType: XForm.self, forPrimaryKey: formID) {
                        xform.xml = String(data: data!, encoding: .utf8)
                    } else {
                        os_log("[%@ %s] formID=%@ does not exist!", String(describing: Self.self), #function, formID)
                    }
                }
                completion(nil) // Success
            } catch let error {
                print(error.localizedDescription)
                completion(error)
            }
        }
        session.resume()
    }

    // MARK: Submit

    func submit(submission: XFormSubmission, completion: @escaping (Error?) -> Void) {
        os_log("[%@ %s]", String(describing: Self.self), #function)
        
        guard var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) else {
            assertionFailure("bad URL")
            return
        }
        
        components.path.append("/submission")
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        os_log("[%@ %s] %@ %@", String(describing: Self.self), #function, request.httpMethod!, request.url!.absoluteString)

        if let basic = self.basic {
            request.setValue("Basic " + basic, forHTTPHeaderField: "Authorization")
        }

        request.setValue("100-continue", forHTTPHeaderField: "Expect")
        request.setValue("1.0", forHTTPHeaderField: "X-OpenRosa-Version")

        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "E, dd MMM yyyy HH:mm:ss zz"
        dateFormat.locale = NSLocale.current
        request.setValue(dateFormat.string(from: Date()), forHTTPHeaderField: "Date") // now
        
        if submission.attachments.count == 0 {
            // Simple POST with no attachments
            os_log("[%@ %s] simple POST", String(describing: Self.self), #function)
            request.setValue("text/xml; charset=utf-8", forHTTPHeaderField:"Content-Type")
            request.httpBody = submission.xml.data(using: .utf8)
        } else {
            // Multi-part POST
            os_log("[%@ %s] multi-part POST with %d attachments", String(describing: Self.self), #function, submission.attachments.count)
            let boundaryString = UUID().uuidString
            request.setValue(String(format: "multipart/form-data; boundary=%@", boundaryString), forHTTPHeaderField:"Content-Type")
            var body = Data()

            // XML instance
            body.append(String(format: "\r\n--%@\r\n", boundaryString).data(using: .utf8)!)
            body.append(String("Content-Disposition: form-data; name=\"xml_submission_file\"; filename=\"foo.xml\"\r\n").data(using: .utf8)!)
            body.append(String("Content-Type: text/xml\r\n\r\n").data(using: .utf8)!)
            body.append(submission.xml.data(using: .utf8)!)
            
            // Attachments
            for urlString in submission.attachments {
                do {
                    print(urlString)
                    guard let url = URL(string: urlString), let data = try? Data(contentsOf: url) else { throw NSError() }
                    
                    var contentType: String
                    switch (urlString as NSString).pathExtension {
                    // TODO other attachment types
                    default:
                        contentType = "image/jpeg"
                    }
                    
                    let filename = url.lastPathComponent
                    os_log("[%@ %s] adding %@ (%d kB)", String(describing: Self.self), #function, filename, data.count/1024)
                    body.append(String(format: "\r\n--%@\r\n", boundaryString).data(using: .utf8)!)
                    body.append(String(format: "Content-Disposition: form-data; name=\"%@\"; filename=\"foo.jpg\"\r\n", filename).data(using: .utf8)!) // ODK Aggregate requires a filename!
                    body.append(String(format: "Content-Type: %@\r\n\r\n", contentType).data(using: .utf8)!)
                    body.append(data)
                } catch {
                    print("cannot read file data")
                }
            }
            
            body.append(String(format: "\r\n--%@--\r\n", boundaryString).data(using: .utf8)!)
            request.httpBody = body
        }

        let session = URLSession.shared.dataTask(with: request) { data, response, error in
            do {
                guard error == nil else { throw error! }
                
                let statusCode = (response as! HTTPURLResponse).statusCode
                os_log("[%@ %s] status=%d", String(describing: Self.self), #function, statusCode)
                guard statusCode / 100 == 2 else { // 2xx = Success
                    throw NSError(domain: Bundle.main.bundleIdentifier!, code: statusCode, userInfo: [NSLocalizedDescriptionKey: "submission failed"])
                }
                
                guard data != nil else {
                    throw NSError(domain: Bundle.main.bundleIdentifier!, code: 444, userInfo: [NSLocalizedDescriptionKey: "no response"])
                }

                print(String(data: data!, encoding: .utf8)!)

                // Check OpenRosaResponse for isComplete
                let xml = try XMLSerialization.xmlObject(with: data!) as! [String: Any]
                // Note: the <submissionMetadata> element attributes are prefixed with '_'
                guard let metadata = xml["submissionMetadata"] as? [String: Any], metadata["_isComplete"] as? String == "true" else {
                    throw NSError(domain: Bundle.main.bundleIdentifier!, code: 422, userInfo: [NSLocalizedDescriptionKey: "incomplete submission"])
                }
                
                if let metadata = xml["submissionMetadata"] as? [String: Any], let submissionID = metadata["_instanceID"] as? String {
                    os_log("[%@ %s] submissionID=%@", String(describing: Self.self), #function, submissionID)
                }
                completion(nil) // Success
            } catch let error {
                print(error.localizedDescription)
                completion(error)
            }
        }
        session.resume()
    }

    // MARK: - Submission List

    func getSubmissionList(formID: String!, projectID: String!, completion: @escaping (Error?) -> Void) {}
    
    // MARK: - Submission

    func getSubmission(submissionID: String!, formID: String!, projectID: String!, completion: @escaping (Error?) -> Void) {}

    // MARK: - Misc
    
    private func updateFormWithDictionary(form: XForm, dict: Dictionary<String, Any>) {
        form.name = dict["name"] as? String
        form.version = dict["version"] as? String
        form.xmlHash = dict["hash"] as? String
        form.state.value = FormState.open.rawValue
        form.url = dict["downloadUrl"] as? String // Realm cant store URL
    }
}
