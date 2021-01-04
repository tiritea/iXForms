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

enum ServerAPI: Int, CaseIterable, CustomStringConvertible {
    case openrosa_aggregate = 1
    case openrosa_central
    case openrosa_kobo
    case rest_central
    case rest_gomobile
    
    // https://stackoverflow.com/questions/24701075
    var description: String {
        switch self {
        case .openrosa_aggregate: return "OpenRosa (ODK Aggregate)"
        case .openrosa_central: return "OpenRosa (ODK Central)"
        case .openrosa_kobo: return "OpenRosa (KoboToolbox)"
        case .rest_central: return "REST (ODK Central)"
        case .rest_gomobile: return "REST (GoMobile)"
        }
    }
    
    var server: URL? {
        switch self {
        case .openrosa_aggregate: return URL(string: "https://opendatakit.appspot.com:443")
        case .openrosa_central: return URL(string: "https://odk.antinod.es:443/v1")
        case .openrosa_kobo: return URL(string: "https://kc.kobotoolbox.org:443")
        case .rest_central: return URL(string: "https://odk.antinod.es:443/v1")
        case .rest_gomobile: return URL(string: "https://demoapi.goget.nz:19725")
        }
    }
}

protocol GSBServer : GSBListTableViewDataSource {
    var url: URL! {get set}
    var hasProjects: Bool! {get}
    
    init(url: URL!)
    func login(username: String!, password: String!, completion: @escaping (Error?) -> Void)
    func getProjectList(completion: @escaping (Error?) -> Void)
    func getFormList(projectID: String?, completion: @escaping (Error?) -> Void)
    func getForm(formID: String!, projectID: String?, completion: @escaping (Error?) -> Void)
    func getSubmissionList(formID: String!, projectID: String!, completion: @escaping (Error?) -> Void)
    func getSubmission(submissionID: String!, formID: String!, projectID: String!, completion: @escaping (Error?) -> Void)
    func submit(submission: XFormSubmission, completion: @escaping (Error?) -> Void)
}

private var _server: GSBServer?
var server: GSBServer? {
    get {
        return _server
    }
    set {
        os_log("%s.%s server=%s", #file, #function, newValue?.url.absoluteString ?? "(null)")
        if let newserver = newValue {
            // Clear database if new server
            if let oldURL = _server?.url, oldURL.absoluteString != newserver.url.absoluteString {
                let db = try! Realm()
                try! db.write {
                    os_log("clearing database")
                    db.deleteAll()
                }
                UserDefaults.standard.set(nil, forKey: "projectid") // reset selected project when change servers
            }
        }
        _server = newValue
    }
}
