//
//  GSBXFormParser.swift
//  iXForms
//
//  Created by MBS GoGet on 28/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import os.log

import RealmSwift

enum XFormElement: String, CaseIterable {
    case model = "model"
    case instance = "instance"
    case binding = "bind"
    case group = "group"
    case repeatgroup = "repeat"
    case input = "input"
    case output = "output"
    case label = "label"
    case value = "value"
    case hint = "hint"
    case selectone = "select1"
    case select = "select"
    case item = "item"
    case upload = "upload"
    case range = "range"
    case trigger = "trigger"
    case secret = "secret"
    case rank = "rank"
}

private class GSBParserDelegate: NSObject, XMLParserDelegate {
    
    var element: String
    var parentElement: GSBParserDelegate?
    var childElement: GSBParserDelegate?
    var attributes: [String:String]?
    var items: [[String:String]] = [] // optional choice list for select/select1 elements (eg label, value, picture, ...)
    var cdata = ""
    var inner = ""
    var groupID: String? // optional UUID for group element
    
    init(element: String) {
        self.element = element
        super.init()
    }
    
    func markup() -> String {
        var markup = "<" + element
        
        // Add element attributes, if applicable
        if let attributeString = (attributes?.reduce("") { $0 + " " + $1.key + "=\"" + $1.value + "\""}) {
            markup += attributeString
        }
        
        // Add any CDATA or nested XML elements, if applicable
        if (inner.count > 0) {
            markup += ">" + inner + "</" + element + ">"
        } else {
            markup += "/>"
        }
        return markup
    }
    
    // MARK: XMLParserDelegate
    
    func parserDidStartDocument(_ parser: XMLParser)
    {
        os_log("parserDidStartDocument")
    }
    
    func parserDidEndDocument(_ parser: XMLParser)
    {
        os_log("parserDidEndDocument")
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error)
    {
        os_log("parseErrorOccurred: %s", parseError.localizedDescription)
        parser.abortParsing()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:])
    {
        os_log("didStartElement: %s", elementName)
        let gsbparser = parser as! GSBXFormParser
        
        // Push new handler for this element. Must persist strong reference because parser.delegate is weak...
        childElement = GSBParserDelegate(element: elementName)
        childElement!.attributes = attributeDict
        childElement!.parentElement = self
        parser.delegate = childElement
        
        if gsbparser.isParsingInstance == false {
            switch elementName {
                
            case XFormElement.instance.rawValue :
                gsbparser.isParsingInstance = true

            case XFormElement.group.rawValue, XFormElement.repeatgroup.rawValue :
                // need to assign groupID now so that child controls can identify their enclosing group
                childElement?.groupID = UUID().uuidString

            default :
                break // nothing to do
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    {
        os_log("didEndElement: %s", elementName)
        let gsbparser = parser as! GSBXFormParser
        
        // Check if finished parsing instance
        if gsbparser.isParsingInstance == true {
            if elementName == XFormElement.instance.rawValue {
                gsbparser.isParsingInstance = false
                
                // Add this instance to form
                let instanceXML = inner // Use inner to remove enclosing <instance>...</instance> because nodeset root starts with child (eg usually /data/...)
                os_log("adding instance = %s", instanceXML)
                let db = try! Realm()
                try! db.write {
                    gsbparser.form.instances.append(instanceXML)
                }
            } else {
                // Do nothing! Ignore sub-elements and just add them to current instance...
            }
        } else {
            // Finished parsing instance so process this XForm element accordingly
            switch elementName {
                
            case XFormElement.binding.rawValue:
                let db = try! Realm()
                try! db.write {
                    let binding = XFormBinding()
                    binding.id = self.attributes?["id"]
                    binding.nodeset = self.attributes?["nodeset"]
                    binding.required = self.attributes?["required"]
                    binding.requiredMsg = self.attributes?["jr:requiredMsg"]
                    binding.constraint = self.attributes?["constraint"]
                    binding.constraintMsg = self.attributes?["jr:constraintMsg"]
                    binding.relevant = self.attributes?["relevant"]
                    binding.calculate = self.attributes?["calculate"]
                    binding.readonly = self.attributes?["readonly"]
                    
                    if let type = self.attributes!["type"] {
                        switch type {
                        // XForm binding types
                        case ControlType.string.description :
                            binding.type.value = ControlType.string.rawValue
                        case ControlType.date.description :
                            binding.type.value = ControlType.date.rawValue
                        case ControlType.time.description :
                            binding.type.value = ControlType.time.rawValue
                        case ControlType.datetime.description :
                            binding.type.value = ControlType.datetime.rawValue
                        case ControlType.integer.description :
                            binding.type.value = ControlType.integer.rawValue
                        case ControlType.decimal.description :
                            binding.type.value = ControlType.decimal.rawValue
                        case ControlType.boolean.description :
                            binding.type.value = ControlType.boolean.rawValue
                        case ControlType.barcode.description :
                            binding.type.value = ControlType.barcode.rawValue
                        case ControlType.binary.description :
                            binding.type.value = ControlType.binary.rawValue
                        case ControlType.geopoint.description :
                            binding.type.value = ControlType.geopoint.rawValue
                            gsbparser.form.isGeoreferenced = true
                        case ControlType.geotrace.description :
                            binding.type.value = ControlType.geotrace.rawValue
                            gsbparser.form.isGeoreferenced = true
                        case ControlType.geoshape.description :
                            binding.type.value = ControlType.geoshape.rawValue
                            gsbparser.form.isGeoreferenced = true
                        
                        // ODK-specific binding types
                        case ControlType.rank.description : binding.type.value = ControlType.rank.rawValue
                        case "select", "select1" : binding.type.value = ControlType.string.rawValue
                        case "int" : binding.type.value = ControlType.integer.rawValue
                            
                        default:
                            os_log("unrecognized control type: %s", type)
                            parser.abortParsing()
                        }
                    }
                    os_log("adding binding = %@", binding)
                    gsbparser.form.bindings.append(binding)
                }
            
            // Add as label attribute to parent element
            case XFormElement.label.rawValue :
                parentElement?.attributes!["label"] = cdata
            
            // Add as hint attribute to parent element
            case XFormElement.hint.rawValue :
                parentElement?.attributes!["hint"] = cdata
            
            // Add as value attribute to parent item element
            case XFormElement.value.rawValue :
                parentElement?.attributes!["value"] = cdata
            
            // Add new item to parent select/select1 element's choice list
            case XFormElement.item.rawValue :
                let choice = ["label" : attributes!["label"] ?? "", "value" : attributes!["value"] ?? ""] // are both select labels and values required or optional?
                os_log("adding choice = %@", choice)
                parentElement?.items.append(choice)
            
            case "title" :
                os_log("title = ", cdata)
                // TODO set form title

            default :
                // Must be either a control, group or repeat group. Find its associated binding
                let bindings = gsbparser.form.bindings // TODO - save bindings (as static?) because they wont change thereafter
                let binding: XFormBinding?
                if let ref = attributes!["ref"] {
                    binding = (bindings.filter { $0.nodeset == ref }).first // find binding against same nodeset
                } else if let bind = attributes!["bind"] {
                    binding = (bindings.filter { $0.id == bind }).first // lookup binding id
                } else {
                    binding = nil
                }
                
                // Find enclosing parent group/repeatgroup by walking up parentElement hierarchy
                var group: GSBParserDelegate? = self
                repeat {
                    group = group!.parentElement
                } while group != nil && group!.element != XFormElement.group.rawValue && group!.element != XFormElement.repeatgroup.rawValue
                attributes!["group"] = group?.groupID // if group is nil then there are no enclosing groups
                
                switch elementName {
                    
                // ---------- input control
                case XFormElement.input.rawValue :
                    //let type = ControlType(rawValue: binding!.type.value!) // determine input control type from the associated binding type
                    //let control = XFormControl(attributes: attributes!, type: type, binding: binding!)
                    let type: ControlType
                    if binding != nil {
                        type = ControlType(rawValue: binding!.type.value!)! // determine input control type from the associated binding type
                    } else {
                        type = ControlType.string // default string type when control has no binding
                    }
                    let control = XFormControl(attributes: attributes!, type: type, binding: binding)
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding input control = %@", control)
                        gsbparser.form.controls.append(control)
                    }
                    
                // ---------- select1 control
                case XFormElement.selectone.rawValue :
                    let control = XFormControl(attributes: attributes!, type: ControlType.selectone, binding: binding)
                    for item in items {
                        control.items.append(XFormItem(label: item["label"]!, value: item["value"]!))
                    }
                    
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding select1 control (%d items) = %@", control.items.count, control)
                        gsbparser.form.controls.append(control)
                    }
                    
                // ---------- select control
                case XFormElement.select.rawValue :
                    let control = XFormControl(attributes: attributes!, type: ControlType.select, binding: binding)
                    for item in items {
                        control.items.append(XFormItem(label: item["label"]!, value: item["value"]!))
                    }
                    
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding select control (%d items) = %@", control.items.count, control)
                        gsbparser.form.controls.append(control)
                    }
                    
                // ---------- rank control
                case XFormElement.rank.rawValue :
                    let control = XFormControl(attributes: attributes!, type: ControlType.rank, binding: binding)
                    for item in items {
                        control.items.append(XFormItem(label: item["label"]!, value: item["value"]!))
                    }
                    
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding rank control (%d items) = %@", control.items.count, control)
                        gsbparser.form.controls.append(control)
                    }
                    
                // ---------- range control
                case XFormElement.range.rawValue :
                    let control = XFormControl(attributes: attributes!, type: ControlType.range, binding: binding)
                    control.min.value = Float(attributes!["start"]! as String)
                    control.max.value = Float(attributes!["end"]! as String)
                    control.inc.value = Float(attributes!["step"]! as String)
                    
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding range control = %@", control)
                        gsbparser.form.controls.append(control)
                    }
                    
                // ---------- trigger control
                case XFormElement.trigger.rawValue :
                    let control = XFormControl(attributes: attributes!, type: ControlType.trigger, binding: binding)
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding trigger control = %@", control)
                        gsbparser.form.controls.append(control)
                    }
                    
                // ---------- upload (binary) control
                case XFormElement.upload.rawValue :
                    let control = XFormControl(attributes: attributes!, type: ControlType.binary, binding: binding)
                    control.mediatype = attributes!["mediatype"]
                    // TODO different control types for each mediatype?
                    
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding upload control = %@", control)
                        gsbparser.form.controls.append(control)
                    }
                    
                // ---------- secret control
                case XFormElement.secret.rawValue :
                    let control = XFormControl(attributes: attributes!, type: ControlType.secret, binding: binding)
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding secret control = %@", control)
                        gsbparser.form.controls.append(control)
                    }
                    
                // ---------- group, repeat
                case XFormElement.group.rawValue, XFormElement.repeatgroup.rawValue :
                    let group = XFormGroup(id: groupID, attributes: attributes!, binding: binding, repeatable: (elementName == XFormElement.repeatgroup.rawValue) ? true : false)
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding group = %@", group)
                        gsbparser.form.groups.append(group)
                    }
                    // TODO repeat count, ...
                    
                default:
                    os_log("unrecognized element: %s", elementName)
                } // end control switch
            } // end element switch
        } // end else
        
        // Add this element to parent's inner markup
        parentElement?.inner += markup()
        
        // Pop current element handler
        parser.delegate = parentElement
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String)
    {
        cdata += string
        inner += string
    }
    
}

class GSBXFormParser: XMLParser {
    
    var form: XForm!
    var isParsingInstance = false // when parsing instance XML ignore sub-element names that inadvertently match XForm reserved words ("bind", "input", ...)
    private var parserDelegate: GSBParserDelegate?
    
    convenience init?(xform: XForm, xml: String) {
        if let data = xml.data(using: String.Encoding.utf8, allowLossyConversion: false) {
            self.init(data: data)
            self.shouldProcessNamespaces = true
            self.shouldReportNamespacePrefixes = true
            self.form = xform
            
            // Must persist strong reference because XMLParser.delegate is weak. https://stackoverflow.com/questions/51099860
            parserDelegate = GSBParserDelegate(element:"") // FIX make optional?
            self.delegate = parserDelegate
        } else {
            return nil
        }
    }
    
}

