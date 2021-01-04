//
//  RealmDB.swift
//  iXForms
//
//  Created by MBS GoGet on 1/07/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import RealmSwift
import CoreLocation

// geopoint String <--> CLLocation
class GSBGeopointTransformer: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    func displayValue(_ value: Any?) -> String? {
        if let location = value as? CLLocation {
            let format: String
            if location.horizontalAccuracy < 100 {
                format = "%.4f°%@, %.4f°W" // 4 decimal places is approx 11m
            } else {
                format = "%.3f°%@, %.3f°W" // 3 decimal places is approx 111m
            }
            let dir = location.coordinate.latitude > 0 ? "N" : "S"
            let str = String(format:format, abs(location.coordinate.latitude), dir, location.coordinate.longitude)
            if (location.horizontalAccuracy != 0) {
                return str + String(format:" (±%.0fm)", location.horizontalAccuracy)
            } else {
                return str
            }
        }
        return nil
    }
    
    // CLLocation -> geopoint String
    override func transformedValue(_ value: Any?) -> Any? {
        if let location = value as? CLLocation {
            let geopoint = String(format:"%5f %5f ", location.coordinate.latitude, location.coordinate.longitude)  // 5 decimal places is approx 1m
            if (location.altitude == 0 && location.horizontalAccuracy == 0) {
                return geopoint + "0 0"
            } else {
                return geopoint + String(format:"%f %f", location.altitude, location.horizontalAccuracy)
            }
        }
        return nil
    }
    
    // geopoint String -> CLLocation
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        if let geopoint = value as? String {
            let coords = geopoint.split(separator: " ").compactMap { Double($0) } // compactMap will remove nil results!
            if coords.count >= 2 {
                return CLLocation(latitude: coords[0], longitude: coords[1]) // ignore altitude and accuracy
            }
        }
        return nil
    }
}

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
    @objc dynamic var projectID: String? // may be nil if projects unsupported
    @objc dynamic var isGeoreferenced = false
    let numRecords = RealmOptional<Int>() // may be nil
    let state = RealmOptional<Int>() // see FormState
    var instances = List<String>()
    var bindings = List<XFormBinding>()
    var controls = List<XFormControl>()
    var groups = List<XFormGroup>()

    override static func primaryKey() -> String? {return "id"}
    
    static let geopointTransformer = GSBGeopointTransformer()

    static let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale.current
        return formatter
    }()
    
    static let timeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SZ"
        formatter.locale = Locale.current
        return formatter
    }()
    
    static let dateTimeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SZ"
        formatter.locale = Locale.current
        return formatter
    }()
    
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
    let type = RealmOptional<Int>() // see ControlType
}

class XFormControl: Object {
    @objc dynamic var label: String?
    @objc dynamic var hint: String?
    @objc dynamic var appearance: String?
    @objc dynamic var binding: XFormBinding? // although all controls must have a binding, in Realm this must still be made an 'optional'; see https://stackoverflow.com/questions/50874280
    let type = RealmOptional<Int>() // see ControlType
    @objc dynamic var ref: String? // only need original ref when control doesn't have an associated binding (otherwise the binding provides the nodeset)

    // control-specific properties
    var items = List<XFormItem>() // needed for select/select1 only
    let min = RealmOptional<Float>() // needed for range only
    let max = RealmOptional<Float>() // needed for range only
    let inc = RealmOptional<Float>() // needed for range only
    @objc dynamic var mediatype: String? // needed for upload only
    
    // DEPRECATE in favor of assigning XFormGroup during parsing
    @objc dynamic var groupID: String?
    var group: XFormGroup? {
        get {
            let db = try! Realm()
            return db.object(ofType: XFormGroup.self, forPrimaryKey: self.groupID)
        }
    }
    
    convenience init(attributes: [String : String], type: ControlType, binding: XFormBinding!) {
        self.init()
        self.type.value = type.rawValue
        self.binding = binding
        label = attributes["label"]
        hint = attributes["hint"]
        appearance = attributes["appearance"]
        ref = attributes["ref"]
        groupID = attributes["group"] // DEPRECATE
    }
}

class XFormGroup: Object {
    @objc dynamic var label: String?
    @objc dynamic var appearance: String?
    @objc dynamic var binding: XFormBinding? // group will only have a binding when it has a relevant expression
    let repeatable = RealmOptional<Bool>() // false=group, true=repeat
    let fieldlist = RealmOptional<Bool>()

    // DEPRECATE in favor of assigning parent XFormGroup during parsing
    @objc dynamic var id: String!
    override static func primaryKey() -> String? {return "id"}
    @objc dynamic var groupID: String?
    var parent: XFormGroup? {
        get {
            let db = try! Realm()
            return db.object(ofType: XFormGroup.self, forPrimaryKey: self.groupID)
        }
    }

    convenience init(id: String!, attributes: [String : String], binding: XFormBinding?, repeatable: Bool!) {
        self.init()
        self.id = id // DEPRECATE?
        self.binding = binding
        self.repeatable.value = repeatable
        self.fieldlist.value = attributes["appearance"]?.contains("field-list") ?? false
        label = attributes["label"]
        appearance = attributes["appearance"]
        groupID = attributes["group"] // DEPRECATE
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
    // https://stackoverflow.com/questions/38806852
    dynamic let attachments = List<String>() // filenames
    
    override static func primaryKey() -> String? {return "id"}

    convenience init(xform: XForm!) {
        self.init()
        self.id = UUID().uuidString
        self.xform = xform
        self.xml = xform.instances.first!
    }
}
