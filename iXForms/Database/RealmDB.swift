//
//  RealmDB.swift
//  iXForms
//
//  Created by MBS GoGet on 1/07/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import RealmSwift

enum FormState: Int, CustomStringConvertible {
    case open = 0
    case closing = 1
    case closed = 2
    case unknown = 3
    
    // https://stackoverflow.com/questions/24701075
    var description : String {
        switch self {
        case .open: return "Open"
        case .closing: return "Closing"
        case .closed: return "Closed"
        case .unknown: return "Unknown"
        }
    }
    
    func color() -> UIColor {
        switch self {
        case .open: return UIColor(hex: 0x008000) // html green
        case .closing: return UIColor(hex: 0xffd700) // html gold
        case .closed: return UIColor.red
        case .unknown: return UIColor.darkGray
        }
    }
}

enum ControlType: Int, CustomStringConvertible {
    // binding types
    case string = 0
    case date = 1
    case time = 2
    case datetime = 3
    case integer = 4
    case decimal = 5
    case geopoint = 6
    case geotrace = 7
    case geoshape = 8
    case boolean = 9
    case barcode = 10
    case binary = 11 // aka upload control

    // additional (non-input) control types
    case selectone = 12
    case select = 13
    case range = 14
    case trigger = 15
    case secret = 16
    case rank = 17
    
    var description : String {
        switch self {
        case .string: return "string"
        case .date: return "date"
        case .time: return "time"
        case .datetime: return "dateTime"
        case .integer: return "integer"
        case .decimal: return "decimal"
        case .geopoint: return "geopoint"
        case .geotrace: return "geotrace"
        case .geoshape: return "geoshape"
        case .boolean: return "boolean"
        case .barcode: return "barcode"
        case .binary: return "binary"
        case .selectone: return "select1"
        case .select: return "select"
        case .range: return "range"
        case .trigger: return "trigger"
        case .secret: return "secret"
        case .rank: return "odk:rank"
        }
    }
}

class Project: Object {
    @objc dynamic var id: String!
    @objc dynamic var name: String?
    @objc dynamic var created: Date?
    @objc dynamic var updated: Date?
    @objc dynamic var lastSubmission: Date?
    let forms = RealmOptional<Int>() // may be nil
    let users = RealmOptional<Int>() // may be nil
    let archived = RealmOptional<Bool>() // may be nil
    
    override static func primaryKey() -> String? {return "id"}
}

class XForm: Object {
    @objc dynamic var id: String!
    @objc dynamic var name: String?
    @objc dynamic var version: String?
    @objc dynamic var xml: String?
    @objc dynamic var xmlHash: String?
    @objc dynamic var author: String?
    @objc dynamic var created: Date?
    @objc dynamic var updated: Date?
    @objc dynamic var lastSubmission: Date?
    @objc dynamic var url: String?
    let numRecords = RealmOptional<Int>() // may be nil
    let state = RealmOptional<Int>() // FormState
    var instances = List<String>()
    var bindings = List<XFormBinding>()
    var controls = List<XFormControl>()
    
    override static func primaryKey() -> String? {return "id"}
    
    // Icon representing form state
    func icon() -> UIImage {
        var image: UIImage?
        switch self.state.value {
        case FormState.open.rawValue:
            if (self.xml != nil) { // on device
                image = UIImage(named: "icons8-check-mark-symbol-filled-30")
            } else { // must be downloaded
                image = UIImage(named: "icons8-download-from-cloud-filled-30")
            }
        case FormState.closing.rawValue:
            if (self.xml != nil) { // on device but can still be submitted
                image = UIImage(named: "icons8-check-mark-symbol-filled-30")
            } else { // must be downloaded
                image = UIImage(named: "icons8-download-from-cloud-filled-30")
            }
        case FormState.closed.rawValue:
            if (self.xml != nil) { // closed
                image = UIImage(named: "icons8-cancel-filled-30")
            } else { // cannot be downloaded
                image = UIImage(named: "icons8-cloud-cross-filled-30")
            }
        default:
            assertionFailure("unrecognized form state")
        }
        return image!.withRenderingMode(.alwaysTemplate)
    }
}

class XFormBinding: Object {
    @objc dynamic var id: String?
    @objc dynamic var nodeset: String?
    @objc dynamic var required: String?
    @objc dynamic var requiredMsg: String?
    @objc dynamic var constraint: String?
    @objc dynamic var constraintMsg: String?
    @objc dynamic var relevant: String?
    @objc dynamic var calculate: String?
    @objc dynamic var readonly: String?
    let type = RealmOptional<Int>() // ControlType
}

class XFormControl: Object {
    @objc dynamic var label: String?
    @objc dynamic var hint: String?
    @objc dynamic var appearance: String?
    @objc dynamic var binding: XFormBinding? // must be optional; see https://stackoverflow.com/questions/50874280
    let type = RealmOptional<Int>() // ControlType
    
    // control-specific properties
    var items = List<XFormItem>() // select/select1 only
    let min = RealmOptional<Float>() // range only
    let max = RealmOptional<Float>() // range only
    let inc = RealmOptional<Float>() // range only
    @objc dynamic var mediatype: String? // upload only
    
    convenience init(attributes: [String : String], type: ControlType, binding: XFormBinding!) {
        self.init()
        label = attributes["label"]
        hint = attributes["hint"]
        appearance = attributes["appearance"]
        self.type.value = type.rawValue
        self.binding = binding
    }

}

class XFormItem: Object {
    @objc dynamic var label: String! // always required?
    @objc dynamic var value: String! // always required?
    
    convenience init(label: String, value: String) {
        self.init()
        self.label = label
        self.value = value
    }
}

class XFormSubmission: Object {
    @objc dynamic var id: String!
    @objc dynamic var xml: String!
    @objc dynamic var xform: XForm! // vs formid?
    
    override static func primaryKey() -> String? {return "id"}

    convenience init(xform: XForm!) {
        self.init()
        self.id = UUID().uuidString
        self.xform = xform
        self.xml = xform.instances.first!
    }
}
