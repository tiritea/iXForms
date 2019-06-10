//
//  GSBServer.swift
//  iXForms
//
//  Created by MBS GoGet on 8/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import os.log
import KeychainSwift
import RealmSwift

var currentServer: GSBServer? // singleton

class GSBServer {
    var url: URL!
    var api: Int!
    var token: String?
    
    init(url: URL!, api: Int!) {
        os_log("%s.%s url=%s", #file, #function, url.absoluteString)

        self.url = url
        self.api = api
    }
    
    func login(username: String!, password: String!) {
        os_log("%s.%s username=%s", #file, #function, username)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/sessions") // login against /sessions REST endpoint
            
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

                        // TEST
                        //self.getCategoryList()
                        self.getFormList(categoryID: "1") // 1=Default Project
                        //self.getForm(formID: "earthquake", categoryID: "1") // 1=Default Project

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
    
    func getCategoryList() {
        os_log("%s.%s", #file, #function)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects") // REST endpoint
            
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
                    
                    let results = try JSONSerialization.jsonObject(with: data!, options: [.mutableContainers]) as! Array<Any>
                    os_log("%lu projects", results.count)
                } catch {
                    os_log("ERROR getCategoryList failed")
                }
            }
            session.resume()
        }
    }
    
    func getFormList(categoryID: String!) {
        os_log("%s.%s", #file, #function)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects/" + categoryID + "/forms") // REST endpoint
            
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
                    os_log("%lu forms in %s", results.count, categoryID)
                    
                    let db = try! Realm()
                    for result in results {
                        os_log("result: %@", result)

                        try db.write {
                            let form = XForm()
                            form.id = result["xmlFormId"] as! String
                            form.name = result["name"] as? String
                            form.version = result["version"] as? String
                            db.create(XForm.self, value: form, update: .all) // over-write if id already exists
                        }
                    }
                    // TODO remove forms that no longer exist
                } catch {
                    os_log("ERROR getFormList failed")
                }
            }
            session.resume()
        }
    }

    func getForm(formID: String!, categoryID: String!) {
        os_log("%s.%s", #file, #function)
        
        if var components = URLComponents.init(url: self.url, resolvingAgainstBaseURL: false) {
            components.path.append("/projects/" + categoryID + "/forms/" + formID) // REST endpoint
            
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

                    let results = try JSONSerialization.jsonObject(with: data!, options: [.mutableContainers]) as! Dictionary<String,Any> // must be Any to handle possible null values!
                    os_log("name=%s", results["name"] as! String)
                } catch {
                    os_log("ERROR getForm failed")
                }
            }
            session.resume()
        }
    }

}
