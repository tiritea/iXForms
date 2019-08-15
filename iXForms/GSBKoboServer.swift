//
//  GSBKoboServer.swift
//  XiphForms
//
//  Created by MBS GoGet on 13/08/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import os.log

class GSBKoboServer: GSBOpenRosaServer {
    
    override func login(username: String!, password: String!, completion: @escaping (Error?) -> Void) {
        // append username to Kobo server URL
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            components.path.append("/" + username)
            url = components.url
        }
        os_log("%s.%s url=%s", #file, #function, url.absoluteString)
        super.login(username: username, password: password, completion: completion)
    }
}
