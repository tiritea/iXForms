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
    // range
    // trigger
}

private class GSBParserDelegate: NSObject, XMLParserDelegate {
    
    var element: String
    var parentElement: GSBParserDelegate?
    var childElement: GSBParserDelegate?
    var attributes: [String:String]?
    var items: [[String:String]] = [] // optional choice list for select/select1 elements (eg label, value, picture, ...)
    var cdata = ""
    var inner = ""
    
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
        
        // Check if start parsing new instance
        if gsbparser.isParsingInstance == false, elementName == XFormElement.instance.rawValue {
            gsbparser.isParsingInstance = true
        }
        
        // Push new handler for this element. Must persist strong reference because parser.delegate is weak...
        childElement = GSBParserDelegate(element: elementName)
        childElement!.attributes = attributeDict
        childElement!.parentElement = self
        parser.delegate = childElement
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    {
        os_log("didEndElement: %s", elementName)
        let gsbparser = parser as! GSBXFormParser
        
        // Check if finished parsing instance
        if gsbparser.isParsingInstance == true {
            if elementName == XFormElement.instance.rawValue {
                gsbparser.isParsingInstance = false
                
                // Add instance to form
                let instanceXML = markup()
                os_log("adding instance = %s", instanceXML)
                let db = try! Realm()
                try! db.write {
                    gsbparser.form.instances.append(instanceXML)
                }
            } else {
                // continue ignoring sub-elements and just add them to current instance
            }
        } else {
            // Finished element so process as required
            switch elementName {
            case XFormElement.binding.rawValue :
                // Add new binding to form
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
                        case ControlType.string.description : binding.type.value = ControlType.string.rawValue
                        case ControlType.date.description : binding.type.value = ControlType.date.rawValue
                        case ControlType.time.description : binding.type.value = ControlType.time.rawValue
                        case ControlType.datetime.description : binding.type.value = ControlType.datetime.rawValue
                        case ControlType.integer.description : binding.type.value = ControlType.integer.rawValue
                        case ControlType.decimal.description : binding.type.value = ControlType.decimal.rawValue
                        case ControlType.geopoint.description : binding.type.value = ControlType.geopoint.rawValue
                        case ControlType.geotrace.description : binding.type.value = ControlType.geotrace.rawValue
                        case ControlType.geoshape.description : binding.type.value = ControlType.geoshape.rawValue
                        case ControlType.boolean.description : binding.type.value = ControlType.boolean.rawValue
                        case ControlType.barcode.description : binding.type.value = ControlType.barcode.rawValue
                        case ControlType.binary.description : binding.type.value = ControlType.binary.rawValue
                            
                        // ODK-specific binding types
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
                
            // input control
            case XFormElement.input.rawValue :
                // Add new control to form
                
                // Find associated binding to determine input control type
                var binding: XFormBinding?
                if let ref = attributes!["ref"] {
                    binding = (gsbparser.form.bindings.filter { $0.nodeset == ref }).first
                } else if let bind = attributes!["bind"] {
                    binding = (gsbparser.form.bindings.filter { $0.id == bind }).first
                }
                
                if binding != nil {
                    let type = ControlType(rawValue: binding!.type.value!)!
                    let control = XFormControl(attributes: attributes!, type: type)
                    let db = try! Realm()
                    try! db.write {
                        os_log("adding control = %@", control)
                        gsbparser.form.controls.append(control)
                    }
                } else {
                    os_log("no binding for control")
                    parser.abortParsing()
                }
                
            // select1 control
            case XFormElement.selectone.rawValue :
                // Add new select1 control to form
                let control = XFormControl(attributes: attributes!, type: ControlType.selectone)
                // TODO add choices to control
                let db = try! Realm()
                try! db.write {
                    os_log("adding select1 control (%d items) = %@", items.count, control)
                    gsbparser.form.controls.append(control)
                }
                
            // select control
            case XFormElement.select.rawValue :
                // Add new select control to form
                let control = XFormControl(attributes: attributes!, type: ControlType.select)
                // TODO add choices to control
                let db = try! Realm()
                try! db.write {
                    os_log("adding select control (%d items) = %@", items.count, control)
                    gsbparser.form.controls.append(control)
                }
                
            case XFormElement.label.rawValue :
                // Add as label attribute to parent element
                parentElement?.attributes!["label"] = cdata
                
            case XFormElement.hint.rawValue :
                // Add as hint attribute to parent element
                parentElement?.attributes!["hint"] = cdata
                
            case XFormElement.value.rawValue :
                // Add as value attribute to parent item element
                parentElement?.attributes!["value"] = cdata
  
            case XFormElement.item.rawValue :
                // Add new item to parent select/select1 element's choice list
                let choice = ["label" : attributes!["label"] ?? "", "value" : attributes!["value"] ?? ""]
                os_log("adding choice = %@", choice)
                parentElement?.items.append(choice)
                
            // upload control
            //case XFormElement.upload.rawValue :
                
            // case XFormElement.group.rawValue :
            // case XFormElement.repeatgroup.rawValue :
                
            default:
                os_log("unrecognized element: %s", elementName)
                //parser.abortParsing()
            }
        }
        
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
            parserDelegate = GSBParserDelegate(element:"") // FIX make nil
            self.delegate = parserDelegate
        } else {
            return nil
        }
    }
}

