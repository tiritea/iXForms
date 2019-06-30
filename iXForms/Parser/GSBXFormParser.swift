//
//  GSBXFormParser.swift
//  iXForms
//
//  Created by MBS GoGet on 28/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import Foundation
import os.log

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
}

enum XFormControl: Int, CustomStringConvertible {
    case string, date, time, datetime, integer, decimal, geopoint, geotrace, geoshape, boolean, barcode
    
    // type name in control's binding
    var description : String {
        switch self {
        case .string: return "string"
        case .date: return "date"
        case .time: return "time"
        case .datetime: return "datetime"
        case .integer: return "integer"
        case .decimal: return "decimal"
        case .geopoint: return "goepoint"
        case .geotrace: return "geotrace"
        case .geoshape: return "geoshape"
        case .boolean: return "boolean"
        case .barcode: return "barcode"
        }
    }
}

// https://gist.github.com/leaves3113/cc836c2a1379a26da9c5

private class GSBParserDelegate: NSObject, XMLParserDelegate {
    
    var element: String
    var parentElement: GSBParserDelegate?
    var childElement: GSBParserDelegate?
    var attributes: [String:String]?
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

        if elementName == XFormElement.instance.rawValue {
            if let gsbparser = parser as? GSBXFormParser, gsbparser.isParsingInstance == false {
                os_log(">>> STARTING NEW INSTANCE")
                gsbparser.isParsingInstance = true
            }
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
 
        if elementName == XFormElement.instance.rawValue {
            if let gsbparser = parser as? GSBXFormParser, gsbparser.isParsingInstance == true {
                os_log("<<< ENDING INSTANCE")
                gsbparser.isParsingInstance = false
            }
        }

        //cdata = cdata.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        //os_log("cdata = %s", cdata)

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
    
    var value: String?
    var isParsingInstance = false // when parsing instance XML we must ignore sub-element names that might inadvertently match XForm keywords ("bind", "input", ...)
    private var parserDelegate: GSBParserDelegate?
    
    convenience init?(xml: String, element: String) {
        if let xmlData = xml.data(using: String.Encoding.utf8, allowLossyConversion: false) {
            self.init(data: xmlData)
            self.shouldProcessNamespaces = true
            self.shouldReportNamespacePrefixes = true
            
            // Must persist strong reference because parser.delegate is weak... see https://stackoverflow.com/questions/51099860
            parserDelegate = GSBParserDelegate(element:element)
            self.delegate = parserDelegate
        } else {
            return nil
        }
    }
    
    override func parse() -> Bool {
        if super.parse() {
            value = (delegate as! GSBParserDelegate).inner
            return true
        } else {
            return false
        }
    }
}
