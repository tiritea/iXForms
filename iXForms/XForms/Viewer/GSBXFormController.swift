//
//  GSBXFormController.swift
//  iXForms
//
//  Created by MBS GoGet on 2/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import os.log

import Eureka
import libxml2
import CoreLocation
import RealmSwift

// ---------------------

// Push custom view controller
// https://github.com/xmartlabs/Eureka/issues/1282
open class PresenterRow<Cell: CellType, PresentedControllerType: TypedRowControllerType>: OptionsRow<Cell>, PresenterRowType where Cell: BaseCell, PresentedControllerType: UIViewController, PresentedControllerType.RowValue == Cell.Value {

    public var presentationMode: PresentationMode<PresentedControllerType>?
    public var onPresentCallback: ((FormViewController, PresentedControllerType) -> Void)?

    required public init(tag: String?) {
        super.init(tag: tag)
        presentationMode = .show(controllerProvider: ControllerProvider.callback {
            return PresentedControllerType.init()
            }, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
        })
    }
    
    open override func customDidSelect() {
        super.customDidSelect()
        guard let presentationMode = presentationMode, !isDisabled else { return }
        if let controller = presentationMode.makeController() {
            controller.row = self
            controller.title = selectorTitle ?? controller.title
            onPresentCallback?(cell.formViewController()!, controller)
            presentationMode.present(controller, row: self, presentingController: self.cell.formViewController()!)
        } else {
            presentationMode.present(nil, row: self, presentingController: self.cell.formViewController()!)
        }
    }
}

// ---------------------

final class MyCustomPresenterRow: PresenterRow<PushSelectorCell<String>, MyCustomViewController>, RowType {}

class MyCustomViewController: UIViewController, TypedRowControllerType {
    var row: RowOf<String>!
    var onDismissCallback: ((UIViewController) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        row.value = "Foo"
        view.backgroundColor = .red
    }
}

// ---------------------

// geopoint String <--> CLLocation
class GSBGeopointTransformer: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    // CLLocation -> geopoint String
    override func transformedValue(_ value: Any?) -> Any? {
        if let location = value as? CLLocation {
            // TODO drop trailing 0's
            let geopoint = String(format:"%f %f ", location.coordinate.latitude, location.coordinate.longitude)
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

class GSBXFormController: FormViewController {
    
    var xform: XForm!
    var xmlDoc: xmlDocPtr?
    var controls: Array<XFormControl>!
    var bindings: Array<XFormBinding>!
    var numRequired: Int!
    var numAnswered: Int!
    var progress: Float!
    var group: XFormGroup?
    
    private let dateFormatter = DateFormatter()
    private let timeFormatter = DateFormatter()
    private let dateTimeFormatter = DateFormatter()
    private let geopointTransformer = GSBGeopointTransformer()
    
    // Must wait to set target (to self) in init. See https://stackoverflow.com/questions/45153589/selector-in-uibarbuttonitem-not-calling
    private var submitButton = UIBarButtonItem(image: UIImage(named: "0 Degrees Filled-25"), style: .plain, target: nil, action: #selector(submitForm))
    private let resetButton = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action: #selector(resetForm))

    // MARK: Initialization

    convenience init(_ submission: XFormSubmission) {
        self.init()
        form.delegate = self
        
        submitButton.target = self
        resetButton.target = self

        // Initialize libxml2 document with primary instance
        let xmlBuffer: [Int8] = Array(submission.xml.utf8).map(Int8.init)
        xmlDoc = xmlReadMemory(UnsafePointer(xmlBuffer), Int32(xmlBuffer.count), "", "UTF-8", Int32(XML_PARSE_RECOVER.rawValue | XML_PARSE_NOERROR.rawValue))
        if (xmlDoc == nil) {
            assertionFailure("cannot create xml doc")
        }
        xform = submission.xform
        bindings = xform.bindings.map { $0 }
        controls = xform.controls.map { $0 }

        dateFormatter.dateFormat = DATEFORMAT
        dateFormatter.locale = Locale.current
        timeFormatter.dateFormat = TIMEFORMAT
        timeFormatter.locale = Locale.current
        dateTimeFormatter.dateFormat = DATETIMEFORMAT
        dateTimeFormatter.locale = Locale.current
        
        // Use default UITableView.detailTextLabel color for displaying row values
        TextRow.defaultCellUpdate = { (cell, row) in
            cell.textField.textColor = .systemDetailTextLabel
            if !row.isValid {
                cell.titleLabel?.textColor = .red
            }
        }
        IntRow.defaultCellUpdate = { (cell, row) in
            cell.textField.textColor = .systemDetailTextLabel
            if !row.isValid {
                cell.titleLabel?.textColor = .red
            }
        }
        DecimalRow.defaultCellUpdate = { (cell, row) in
            cell.textField.textColor = .systemDetailTextLabel
            if !row.isValid {
                cell.titleLabel?.textColor = .red
            }
        }
        TextAreaRow.defaultCellUpdate = { (cell, row) in
            cell.textView.textColor = .systemDetailTextLabel
            cell.textView.backgroundColor = UIColor(white: 0.98, alpha: 1)
            // TODO change placeholder color?
        }
        
        // Minimize segment width - https://github.com/xmartlabs/Eureka/issues/973
        SegmentedRow<String>.defaultCellSetup = { (cell, row) in
            cell.segmentedControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            cell.segmentedControl.apportionsSegmentWidthsByContent = true
        }
        
        hidesBottomBarWhenPushed = true
    }

    convenience init(_ submission: XFormSubmission, group: XFormGroup?) {
        self.init(submission)
        self.group = group
    }
/*
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var section: Section?
        var currentGroup: XFormGroup?
        
        for (index, control) in controls.enumerated() {

            // If group different than previous, start new section
            if control.group != currentGroup || section == nil {
                currentGroup = control.group
                section = Section(currentGroup?.label ?? "")
                form.append(section!)
            }
            
            let rowid = "control" + String(index)
            if let row = rowForControl(control: control, rowid: rowid) {
                section!.append(row)
            }
        }
    }
*/
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var section: Section?
        var currentGroup: XFormGroup?
        var currentSubpage: XFormGroup?

        for (index, control) in controls.enumerated() {

            // If group different than previous, start new section
            if control.group != currentGroup || section == nil {
                currentGroup = control.group
                section = Section(currentGroup?.label ?? "")
                form.append(section!)
            }
            
            // HACK
            if let group = control.group {
                if let row = rowForGroup(group: group, rowid: "group" + String(index)) {
                    section!.append(row)
                }
            }

            let rowid = "control" + String(index)
            if let row = rowForControl(control: control, rowid: rowid) {
                section!.append(row)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = xform.name
        self.navigationItem.rightBarButtonItems = [submitButton, resetButton]
        
        self.revalidate()
    }
    
    // MARK: UI Actions

    @objc func submitForm() {
        os_log("%s.%s", #file, #function)
        
        var submitController: UIAlertController!
        if progress == 1.0 {
            submitController = UIAlertController(title: "Submit Form",
                                                 message: nil,
                                                 preferredStyle: .alert)
            submitController.addAction(UIAlertAction(title: "Submit", style: .destructive, handler: { action in
                self.submit()
            }))
            submitController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        } else {
            submitController = UIAlertController(title: String.init(format: "Progress : %.0f%% Complete", progress * 100.0),
                                                 message: String.init(format: "You have answered %d of %d required questions (%d remaining).", numAnswered, numRequired, numRequired-numAnswered),
                                                 preferredStyle: .alert)
            submitController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        self.present(submitController, animated: true)
    }
 
    @objc func resetForm() {
        os_log("%s.%s", #file, #function)
        
        let resetController = UIAlertController(title: "Discard Changes",
                                      message: "Discard all changes and reset this form back to its original state?",
                                      preferredStyle: .alert)
        resetController.addAction(UIAlertAction(title: "Discard", style: .destructive, handler: { action in
            self.reset()
        }))
        resetController.addAction(UIAlertAction(title: "Resume", style: .cancel, handler: nil))
        self.present(resetController, animated: true)
    }

    // MARK: XFormGroup -> Row
    
    func rowForGroup(group: XFormGroup, rowid: String) -> BaseRow? {
        let binding = group.binding
        let node = binding?.nodeset

        // https://github.com/xmartlabs/Eureka/issues/1282
        let row = MyCustomPresenterRow() { row in
            row.tag = rowid
            row.title = group.label
        }
        return row
    }

    // MARK: XFormControl -> Row

    func rowForControl(control: XFormControl, rowid: String) -> BaseRow? {
        let binding = control.binding!
        let node = binding.nodeset
        
        let iconInsets = UIEdgeInsets.init(top: 3, left: 6, bottom: 3, right: 0)
        
        // Add required and constraint validation rules
        // See also https://stackoverflow.com/questions/44306449
        var rules = RuleSet<String>()
        if let required = binding.required, required != "false()" {
            if required == "true()" {
                rules.add(rule: RuleRequired(msg: binding.requiredMsg ?? "value required"))
            } else {
                // RuleClosure returns ValidationError if invalid, otherwise nil if valid
                let requiredRule = RuleClosure<String> { rowValue in
                    return rowValue == nil && self.evaluateXPathBoolean(nodeset: node, expression: required) ? ValidationError(msg: binding.requiredMsg ?? "value required") : nil
                }
                rules.add(rule: requiredRule)
            }
        }
        if let constraint = binding.constraint {
            let constraintRule = RuleClosure<String> { rowValue in
                return self.evaluateXPathBoolean(nodeset: node, expression: constraint) ? ValidationError(msg: binding.constraintMsg ?? "invalid value") : nil
            }
            rules.add(rule: constraintRule)
        }

        // Get row widget for control (and appearance)
        var row: BaseRow
        switch control.type.value {
        case ControlType.string.rawValue :
            switch control.appearance {
                
            // ---------- multiline
            case "multiline" :
                row = TextAreaRow() {
                    $0.placeholder = control.label
                    $0.value = getStringForNode(nodeset: node)
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            self.setValueForControl(control: control, value: row.value)
                        }
                    }
                }
                
            // ---------- string
            default:
                row = TextRow() {
                    $0.value = getStringForNode(nodeset: node)
                    $0.add(ruleSet: rules)
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            self.setValueForControl(control: control, value: row.value)
                        }
                    }}
                    .cellSetup { cell, row in
                        if let _ = control.hint {
                            cell.accessoryType = .detailButton
                        }
                        // Italicise Notes (readonly text controls)
                        if let readonly = control.binding?.readonly, readonly == "true()" {
                            cell.textLabel?.font = cell.textLabel?.font.italic()
                        }
                }
            }
            
        // ---------- integer
        case ControlType.integer.rawValue :
            row = IntRow() {
                if let number = getNumberForNode(nodeset: node) {
                    $0.value = number.intValue
                }
                $0.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted { // lost focus (ie finished editing)
                        let value = (row.value != nil) ? String(row.value!) : nil
                        self.setValueForControl(control: control, value: value)
                    }
                }
            }
            
        case ControlType.decimal.rawValue :
            switch control.appearance {
                
            // ---------- bearing
            case "bearing" :
                // TODO compass widget
                os_log("unsupported appearance: %s", control.appearance!)
                row = ImageRow() {
                    $0.disabled = true
                    $0.value = UIImage.init(named: "icons8-north-direction-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                    }
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
                
            // ---------- decimal
            default :
                row = DecimalRow() {
                    if let number = getNumberForNode(nodeset: node) {
                        $0.value = number.doubleValue
                    }
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            let value = (row.value != nil) ? String(row.value!) : nil
                            self.setValueForControl(control: control, value: value)
                        }
                    }
                }
            }
            
        case ControlType.selectone.rawValue :
            switch control.appearance {
                
            // ---------- select1 compact
            case "compact" :
                row = SegmentedRow<String>() {
                    $0.options = control.items.map { $0.label }
                    
                    let selected = control.items.filter { $0.value == self.getStringForNode(nodeset: node) }
                    if let label = selected.first?.label { // only one item value should ever match!
                        $0.value = label
                    }
                    
                    $0.onChange { row in
                        // lookup value for selected label
                        if let label = row.value {
                            let selected = control.items.filter { $0.label == label }
                            if let value = selected.first?.value { // only one item label should ever match!
                                self.setValueForControl(control: control, value: value)
                            }
                        } else {
                            self.setValueForControl(control: control, value: nil) // unselected everything
                        }
                    }}
                
            // ---------- select1 minimal
            case "minimal" :
                row = PickerInlineRow<String>() {
                    $0.options = control.items.map { $0.label }
                    
                    let selected = control.items.filter { $0.value == self.getStringForNode(nodeset: node) }
                    if let label = selected.first?.label { // only one item value should ever match!
                        $0.value = label
                    }
                    
                    $0.onChange { row in
                        // lookup value for selected label
                        if let label = row.value {
                            let selected = control.items.filter { $0.label == label }
                            if let value = selected.first?.value { // only one item label should ever match!
                                self.setValueForControl(control: control, value: value)
                            }
                        } else {
                            self.setValueForControl(control: control, value: nil) // unselected everything
                        }
                    }}
                
            // ---------- select1 full
            default : // "full"
                row = PushRow<String>() {
                    $0.selectorTitle = control.label
                    $0.options = control.items.map { $0.label }
                    
                    let selected = control.items.filter { $0.value == self.getStringForNode(nodeset: node) }
                    if let label = selected.first?.label { // only one item value should ever match!
                        $0.value = label
                    }
                    
                    $0.onChange { row in
                        // lookup value for selected label
                        if let label = row.value {
                            let selected = control.items.filter { $0.label == label }
                            if let value = selected.first?.value { // only one item label should ever match!
                                self.setValueForControl(control: control, value: value)
                            }
                        } else {
                            self.setValueForControl(control: control, value: nil) // unselected everything
                        }
                    }
                    // Set pushed header and footer - see https://github.com/xmartlabs/Eureka/issues/715
                    $0.onPresent({ (form, pushedViewController) in
                        let _ = pushedViewController.view
                        pushedViewController.form.first?.header = HeaderFooterView(title: "Select one")
                        pushedViewController.form.first?.footer = HeaderFooterView(title: control.hint)
                    })
                }
            }
            
        // ---------- select-multi
        case ControlType.select.rawValue :
            row = MultipleSelectorRow<String>() {
                $0.selectorTitle = control.label
                $0.options = control.items.map { $0.label }
                
                if let values = getStringForNode(nodeset: node) {
                    $0.value = Set(values.components(separatedBy: .whitespaces).map { // Array -> Set
                        let value = $0
                        let selected = control.items.filter { $0.value == value } // find matching item(s) - should only be one!
                        let label = selected.first!.label!
                        return label // return matching item label
                        // TODO what if unrecognized value? ie filter = []
                    })
                }
                
                $0.onChange { row in
                    // Lookup values for the selected item labels
                    if let labels: Set<String> = row.value {
                        let labelarray = Array(labels) // Set -> Array
                        let values: [String] = labelarray.map { // Swift bug - must explicitly specify return type!?
                            let label = $0
                            let selected = control.items.filter { $0.label == label }
                            return selected.first!.value
                            // TODO what if unrecognized label? ie filter = []
                        }
                        self.setValueForControl(control: control, value: values.joined(separator: " ")) // Set -> Array
                    } else {
                        self.setValueForControl(control: control, value: nil) // nothing selected
                    }
                }
                // Set pushed header and footer - see https://github.com/xmartlabs/Eureka/issues/715
                $0.onPresent({ (form, pushedViewController) in
                    let _ = pushedViewController.view
                    pushedViewController.form.first?.header = HeaderFooterView(title: "Select all that apply")
                    pushedViewController.form.first?.footer = HeaderFooterView(title: control.hint)
                })
            }
            
        case ControlType.datetime.rawValue :
            row = DateTimeRow(rowid) {
                if let dateTime = getStringForNode(nodeset: node) {
                    $0.value = dateTimeFormatter.date(from: dateTime)
                }
                $0.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted { // lost focus (ie finished editing)
                        if let value = row.value {
                            self.setValueForControl(control: control, value: self.dateTimeFormatter.string(from: value))
                        } else {
                            self.setValueForControl(control: control, value: nil)
                        }
                    }
                }
            }
            
        case ControlType.date.rawValue :
            switch control.appearance {
                
            // ---------- year
            case "year" :
                // TODO custom picker with only year to replace UIDatePicker
                row = DateRow() {
                    $0.dateFormatter = DateFormatter()
                    $0.dateFormatter!.dateFormat = "yyyy"
                    if let date = getStringForNode(nodeset: node) {
                        $0.value = dateFormatter.date(from: date)
                    }
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            if let date = row.value {
                                let calendar = Calendar.current
                                let newdate = calendar.date(from: calendar.dateComponents([.year], from: date))! // Note: this will set day and month to 1!
                                self.setValueForControl(control: control, value: self.dateFormatter.string(from: newdate))
                            } else {
                                self.setValueForControl(control: control, value: nil)
                            }
                        }
                    }
                }
                
            // ---------- month-year
            case "month-year" :
                // TODO custom picker with only year and month to replace UIDatePicker
                row = DateRow() {
                    $0.dateFormatter = DateFormatter()
                    $0.dateFormatter!.dateFormat = "MM/yyyy" // Note: display format only
                    if let date = getStringForNode(nodeset: node) {
                        $0.value = dateFormatter.date(from: date)
                    }
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            if let date = row.value {
                                let calendar = Calendar.current
                                let newdate = calendar.date(from: calendar.dateComponents([.year, .month], from: date))! // Note: this will set day 1!
                                self.setValueForControl(control: control, value: self.dateFormatter.string(from: newdate))
                            } else {
                                self.setValueForControl(control: control, value: nil)
                            }
                        }
                    }
                }
                
            // ---------- date
            default :
                row = DateRow() {
                    if let date = getStringForNode(nodeset: node) {
                        $0.value = dateFormatter.date(from: date)
                    }
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            if let date = row.value {
                                self.setValueForControl(control: control, value: self.dateFormatter.string(from: date))
                            } else {
                                self.setValueForControl(control: control, value: nil)
                            }
                        }
                    }
                }
            }
            
        // ---------- time
        case ControlType.time.rawValue :
            row = TimeRow() {
                if let dateTime = getStringForNode(nodeset: node) {
                    $0.value = timeFormatter.date(from: dateTime)
                }
                $0.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted { // lost focus (ie finished editing)
                        if let value = row.value {
                            self.setValueForControl(control: control, value: self.timeFormatter.string(from: value))
                        } else {
                            self.setValueForControl(control: control, value: nil)
                        }
                    }
                }
            }
            
        case ControlType.geopoint.rawValue :
            row = LocationRow() {
                $0.value = geopointTransformer.reverseTransformedValue(getStringForNode(nodeset: node)) as? CLLocation // XForm geopoint -> CLLocation
                $0.displayValueFor = {
                    if let coord = $0?.coordinate {
                        return String(format:"%.4f, %.4f", coord.latitude, coord.longitude) // Note: display as "lat, long" decimal degrees
                    } else {
                        return nil
                    }
                }
                $0.onChange { row in
                    self.setValueForControl(control: control, value: self.geopointTransformer.transformedValue(row.value) as? String) // CLLocation -> XForm geopoint
                }
            }
            
        case ControlType.geotrace.rawValue :
            // TODO
            os_log("unsupported control type: %d", control.type.value!)
            row = TextRow() {
                $0.disabled = true
            }

        case ControlType.geoshape.rawValue :
            // TODO
            os_log("unsupported control type: %d", control.type.value!)
            row = TextRow() {
                $0.disabled = true
            }

        case ControlType.boolean.rawValue :
            switch control.appearance {
                
            // ---------- checkmark
            case "checkmark" :
                row = SwitchRow() {
                    $0.value = getBoolForNode(nodeset: node) // Note: null -> 0
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            if let value = row.value {
                                self.setValueForControl(control: control, value: (value ? "true" : "false")) // Bool -> "true"/"false"
                            } else {
                                self.setValueForControl(control: control, value: nil)
                            }
                        }
                    }
                }

            // ---------- switch
            default: // "switch"
                row = CheckRow() {
                    $0.value = getBoolForNode(nodeset: node) // Note: null -> 0
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            if let value = row.value {
                                self.setValueForControl(control: control, value: (value ? "true" : "false")) // Bool -> "true"/"false"
                            } else {
                                self.setValueForControl(control: control, value: nil)
                            }
                        }
                    }
                }
            }
            
        // ---------- range
        case ControlType.range.rawValue :
            row = SliderRow() {
                $0.steps = UInt((control.max.value! - control.min.value!) / control.inc.value!)
                $0.value = getNumberForNode(nodeset: node)?.floatValue ?? control.min.value! // BUG WORKAROUND - must always have value otherwise slider not shown
                $0.onChange { row in
                    if let value = row.value {
                        self.setValueForControl(control: control, value: NSNumber(value: value).stringValue) // float -> NSNumber -> String
                    }
                }}
                .cellSetup { cell, row in
                    cell.slider.minimumValue = control.min.value!
                    cell.slider.maximumValue = control.max.value!
                }
            
        // ---------- trigger
        case ControlType.trigger.rawValue :
            row = ButtonRow() {
                $0.onCellSelection { cell, row in
                    self.setValueForControl(control: control, value: "OK")
                }}
                .cellSetup { cell, row in
                    // TODO rounded button
                }
            
        // ---------- secret
        case ControlType.secret.rawValue :
            //section.append(PasswordFloatLabelRow)...
            row = PasswordRow() {
                $0.value = getStringForNode(nodeset: node)
                $0.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted { // lost focus (ie finished editing)
                        self.setValueForControl(control: control, value: row.value)
                    }
                }
            }
            
        case ControlType.binary.rawValue :
            // ---------- Photo
            if control.mediatype!.starts(with: "image") {
                // CRITICAL: Info.plist must contain NSCameraUsageDescription key
                row = ImageRow() {
                    $0.clearAction = .yes(style: .destructive)
                    
                    if let uuid = getStringForNode(nodeset: node) {
                        // TODO get image with uuid
                    } else {
                        $0.value = UIImage.init(named: "icons8-camera-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                    }
                    
                    $0.onChange { row in //4
                        if let image = row.value {
                            // TODO save image with new uuid
                        } else {
                            // Clear previous image
                            self.setValueForControl(control: control, value: nil)
                            row.value = UIImage.init(named: "icons8-camera-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // restore placeholder
                        }
                    }}
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
            } else if control.mediatype!.starts(with: "video") {
                // TODO Use this? https://github.com/EurekaCommunity/VideoRow
                os_log("unsupported media type: %s", control.mediatype!)
                row = ImageRow() {
                    $0.disabled = true
                    $0.value = UIImage.init(named: "icons8-video-call-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                    }
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
            } else if control.mediatype!.starts(with: "audio") {
                // TODO
                os_log("unsupported media type: %s", control.mediatype!)
                row = ImageRow() {
                    $0.disabled = true
                    $0.value = UIImage.init(named: "icons8-voice-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                    }
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
            } else {
                // TODO
                os_log("unsupported media type: %s", control.mediatype!)
                row = ImageRow() {
                    $0.disabled = true
                    $0.value = UIImage.init(named: "icons8-document-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                    }
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
            }
            
        case ControlType.barcode.rawValue :
            // TODO Use this? https://gist.github.com/isaacabdel/adfb54e4f76386d755a18d455334229a
            os_log("unsupported control type: %d", control.type.value!)
            row = ImageRow() {
                $0.disabled = true
                $0.value = UIImage.init(named: "icons8-barcode-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                }
                .cellSetup { cell, row in
                    cell.accessoryView?.tintColor = .systemBlue
                }

        case ControlType.rank.rawValue :
            // TODO
            os_log("unsupported control type: %d", control.type.value!)
            row = TextRow() {
                $0.disabled = true
            }

        default:
            os_log("unrecognized control type: %d", control.type.value!)
            return nil
        }
        
        row.tag = rowid
        row.title = control.label
        row.validationOptions = .validatesOnDemand // validate all rows on form.validate()

        // TODO do this in refresh
        if let readonly = control.binding?.readonly, readonly == "true()" {
            row.disabled = true
        }
        
        return row
    }
    
    func setValueForControl(control: XFormControl!, value: String?) {
        let nodeset = control.binding!.nodeset!
        self.setValueForNode(nodeset: nodeset, value: value)
        self.recalculate(nodeset: nodeset)
        self.revalidate()
        self.refresh()
    }

    // MARK: XForm Events
    
    // See https://www.w3.org/TR/xforms11/#evt-recalculate
    func recalculate(nodeset: String!) {
        os_log("%s.%s nodeset=%s", #file, #function, nodeset)
        var changed = false
        
        // TODO Follow DAG graph to only redo calculations dependent on this nodeset
        
        // HACK: recompute everything!
        for binding in bindings {
            if let calculate = binding.calculate, let nodeset = binding.nodeset {
                if let xpathObject = evaluateXPathExpression(nodeset: nodeset, expression: calculate) {
                    defer { xmlFree(xpathObject) }
                    if let newvalue = xmlXPathCastToString(xpathObject), xmlStrlen(newvalue) > 0 {
                        
                    } else {
                        
                    }
                }
            }
        }
    }
    
    // See https://www.w3.org/TR/xforms11/#evt-revalidate
    func revalidate() {
        os_log("%s.%s", #file, #function)
        form.validate()
        
        // Determine number of required (and relevant) questions, and number of those answered
        numRequired = 10
        numAnswered = 4
        
        if (numRequired > 0) {
            progress = (Float(numAnswered) / Float(numRequired))
        } else {
            progress = 1.0 // if no required questions then form is already 'Complete' and submittable...
        }
        
        // Update submit button icon to show progress
        if progress == 1.0 {
            submitButton.image = UIImage.init(named: "Ok Filled-25") // Complete
        } else {
            let deg = Int(progress * 360.0 / 30.0) * 30 // determine nearest 30deg icon
            submitButton.image = UIImage.init(named: String.init(format: "%d Degrees Filled-25", deg))
        }
    }
    
    // See https://www.w3.org/TR/xforms11/#evt-refresh
    func refresh() {
        os_log("%s.%s", #file, #function)
    }
    
    // See https://www.w3.org/TR/xforms11/#evt-reset
    func reset() {
        os_log("%s.%s", #file, #function)
    }

    func submit() {
        os_log("%s.%s", #file, #function)
    }
    
    // MARK: <UITableViewDelegate>

    // Hint
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let row = form[indexPath.section][indexPath.row]
        let prefix = "control" // row.tag = "controlXXX" where XXX is the index into controls[]
        if let tag = row.tag, tag.hasPrefix(prefix), let index = Int(tag.dropFirst(prefix.count)) {
            let control = controls[index]
            let info = UIAlertController.init(title: "Info", message: control.hint, preferredStyle: .alert)
            info.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(info, animated: true)
        }
    }
    
    // MARK: <FormDelegate>
    
    override func valueHasBeenChanged(for row: BaseRow, oldValue: Any?, newValue: Any?) {
        os_log("%s.%s", #file, #function)
        super.valueHasBeenChanged(for: row, oldValue: oldValue, newValue: newValue)
    }
    
    // MARK: Rotation

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let compact = view.traitCollection.horizontalSizeClass != .regular
        os_log("horizontalSizeClass = %s", compact ? "compact" : "regular")
        // TODO change any TextRows to/from TextFloatLabelRow if horizontalSizeClass different
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if let previous = previousTraitCollection, previous.horizontalSizeClass != traitCollection.horizontalSizeClass {
            if traitCollection.horizontalSizeClass == .compact {
                os_log("%s.%s switching to compact", #file, #function)
            } else {
                os_log("%s.%s switching to regular", #file, #function)
            }
        }
    }
    
    // MARK: libxml2
    // see https://github.com/LumingYin/SpeedReader/blob/master/Kanna/libxmlHTMLDocument.swift
    
    // Optimizations:
    // can reuse xpathContext? - see https://mail.gnome.org/archives/xml/2008-October/msg00053.html
    //     "Make sure to reset the ctxt->node, ctxt->doc before rerunning the
    //      query as they have been modified. Except for that you can reuse a
    //      context."
    // Use xmlXPathContextSetCache?
    
    func getValueForNode(_ nodeset: String!) -> UnsafeMutablePointer<xmlChar>? {
        let xpathContext = xmlXPathNewContext(xmlDoc)!
        defer { xmlFree(xpathContext) }
        if let xpathObject = xmlXPathEvalExpression(nodeset, xpathContext), let value = xmlXPathCastToString(xpathObject), xmlStrlen(value) > 0 {
            defer { xmlFree(xpathObject) }
            return value
        }
        return nil
    }

    func getStringForNode(nodeset: String!) -> String? {
        if let value = getValueForNode(nodeset) {
            return String.init(cString: value) // xmlChar* -> String
        }
        return nil
    }
    
    func getBoolForNode(nodeset: String!) -> Bool? {
        if let value = getValueForNode(nodeset) {
            return xmlXPathCastStringToBoolean(value) != 0 // Int -> Bool
        }
        return nil
    }

    func getNumberForNode(nodeset: String!) -> NSNumber? {
        if let value = getValueForNode(nodeset) {
            return xmlXPathCastStringToNumber(value) as NSNumber // double -> NSNumber
        }
        return nil
    }
 
    func setValueForNode(nodeset: String!, value: String?) {
        os_log("%s.%s nodeset=%s value=%s", #file, #function, nodeset, value ?? "(null)")
        let xpathContext = xmlXPathNewContext(xmlDoc)!
        defer { xmlFree(xpathContext) }

        if let xpathObject = xmlXPathEvalExpression(nodeset, xpathContext), let nodes = xpathObject.pointee.nodesetval {
            defer { xmlFree(xpathObject) }
            if (nodes.pointee.nodeNr > 1) {
                os_log("%s.%s WARNING multiple nodes matching %s", #file, #function, nodeset)
            }
            
            for i in 0..<nodes.pointee.nodeNr { // assign value to *all* matching nodes!
                if let node: xmlNodePtr = nodes.pointee.nodeTab![Int(i)] {
                    //xmlNodeSetContent(node, value)
                    xmlNodeSetContent(node, xmlEncodeSpecialChars(xmlDoc, value))
                }
            }
            os_log("%s.%s XML=%s", #file, #function, xmlString() ?? "(null)")
        }
    }

    func evaluateXPathExpression(nodeset: String!, expression: String!) -> xmlXPathObjectPtr? {
        let xpathContext = xmlXPathNewContext(xmlDoc)!
        defer { xmlFree(xpathContext) }

        // Register XPath extension functions. See http://xmlsoft.org/XSLT/extensions.html#Registerin1
        // TODO
        
        // Set context node (used for relative XPath expressions)
        if let xpathObject = xmlXPathEvalExpression(nodeset, xpathContext), let nodes = xpathObject.pointee.nodesetval {
            defer { xmlFree(xpathObject) }
            if (nodes.pointee.nodeNr == 0) {
                os_log("%s.%s ERROR missing XPath evaluation context %s", #file, #function, nodeset)
            } else {
                if (nodes.pointee.nodeNr > 1) {
                    os_log("%s.%s WARNING ambiguous XPath evaluation context %s", #file, #function, nodeset)
                }
                if let node: xmlNodePtr = nodes.pointee.nodeTab![0] { // use first node as context
                    xpathContext.pointee.node = node
                    return xmlXPathEvalExpression(expression, xpathContext) // CRITICAL: caller must xmlFree result!
                }
            }
        }
        return nil
    }

    func evaluateXPathBoolean(nodeset: String!, expression: String!) -> Bool! {
        if let xpathObject = evaluateXPathExpression(nodeset: nodeset, expression: expression) {
            defer { xmlFree(xpathObject) }
            return xmlXPathCastToBoolean(xpathObject) != 0
        } else {
            return false
        }
    }

    func xmlString() -> String? {
        var xml: UnsafeMutablePointer<xmlChar>? = nil
        defer { xmlFree(xml) }
        let size: UnsafeMutablePointer<Int32>? = nil
        xmlDocDumpMemory(xmlDoc, &xml, size)
        return String(cString: UnsafePointer(xml!)) // xmlChar* -> String
    }
    
}
