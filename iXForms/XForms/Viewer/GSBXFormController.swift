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
import ImageRow
import VideoRow

import TLPhotoPicker
import Photos

// Custom formatter for integers with a thousands separator. Adapted from Eureka DecimalFormatter.swift
class ThousandsIntegerFormatter: NumberFormatter, FormatterProtocol {
    override init() {
        super.init()
        locale = Locale.current
        numberStyle = .decimal
        maximumFractionDigits = 0
        minimumFractionDigits = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, range rangep: UnsafeMutablePointer<NSRange>?) throws {
        let str = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        obj?.pointee = NSNumber(value: Int(str) ?? 0)
    }
    
    func getNewPosition(forPosition position: UITextPosition, inTextInput textInput: UITextInput, oldValue: String?, newValue: String?) -> UITextPosition {
        return textInput.position(from: position, offset:((newValue?.count ?? 0) - (oldValue?.count ?? 0))) ?? position
    }
}

// Custom formatter for decimals *without* a thousands separator (the default for ODK). Adapted from Eureka DecimalFormatter.swift
class NonThousandsDecimalFormatter: DecimalFormatter {
    override init() {
        super.init()
        //locale = Locale.current
        //numberStyle = .decimal
        groupingSeparator = ""
        //decimalSeparator = "."
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
/*
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, range rangep: UnsafeMutablePointer<NSRange>?) throws {
        let str = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        obj?.pointee = NSNumber(value: Int(str) ?? 0)
    }
    
    func getNewPosition(forPosition position: UITextPosition, inTextInput textInput: UITextInput, oldValue: String?, newValue: String?) -> UITextPosition {
        return textInput.position(from: position, offset:((newValue?.count ?? 0) - (oldValue?.count ?? 0))) ?? position
    }
 */
}
    
public extension NSAttributedString {
    // https://stackoverflow.com/questions/4217820
    convenience init?(html str: String, font: UIFont) {
        var html = str.replacingOccurrences(of: "\n", with: "<br>")
        html = String(format:"<span style=\"font-family: '-apple-system', 'HelveticaNeue'; font-size:12\">%@</span>", html)
        //html = String(format:"<span style=\"font-family:%@; font-size:%f\">%@</span>", font.fontName, font.pointSize, html)
        guard let data = html.data(using: .unicode) else { return nil }
        try? self.init(data: data,
                       options: [.documentType: NSAttributedString.DocumentType.html,
                                 .characterEncoding: String.Encoding.utf8.rawValue],
                       documentAttributes: nil)
    }
}

// https://stackoverflow.com/questions/28661938/retrieve-alasset-or-phasset-from-file-url
func PHAssetForFileURL(url: NSURL) -> PHAsset? {
    let imageRequestOptions = PHImageRequestOptions()
    imageRequestOptions.version = .current
    imageRequestOptions.deliveryMode = .fastFormat
    imageRequestOptions.resizeMode = .fast
    imageRequestOptions.isSynchronous = true

    let fetchResult = PHAsset.fetchAssets(with: nil)
    for index in 0...fetchResult.count-1 {
        if let asset = fetchResult[index] as PHAsset? {
            var found = false
            PHImageManager.default().requestImageData(for: asset,
                options: imageRequestOptions) { (_, _, _, info) in
                if let urlkey = info!["PHImageFileURLKey"] as? NSURL {
                        if urlkey.absoluteString! == url.absoluteString! {
                            found = true
                        }
                    }
            }
            if (found) {
                return asset
            }
        }
    }

    return nil
}

/*
 Add UIControl closure for Eureka SliderRow end events
 */
// https://stackoverflow.com/questions/25919472/adding-a-closure-as-target-to-a-uibutton
@objc class ClosureSleeve: NSObject {
    let closure: ()->()

    init (_ closure: @escaping ()->()) {
        self.closure = closure
    }

    @objc func invoke () {
        closure()
    }
}

extension UIControl {
    func addAction(for controlEvents: UIControl.Event = .touchUpInside, _ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: controlEvents)
        objc_setAssociatedObject(self, "[\(UUID())]", sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
}

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
/*
final class GSBXFormRow: PresenterRow<PushSelectorCell<String>, GSBXFormController>, RowType {}

class GSBXFormController: UIViewController, TypedRowControllerType {
    var row: RowOf<String>!
    var onDismissCallback: ((UIViewController) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        row.value = "Foo"
        view.backgroundColor = .red
    }
}
*/

class GSBXFormController: FormViewController {
    
    var submission: XFormSubmission!
    var xform: XForm!
    var xmlDoc: xmlDocPtr?
    var controls: Array<XFormControl>!
    var bindings: Array<XFormBinding>!
    var numRequired: Int!
    var numAnswered: Int!
    var progress: Float!
    var group: XFormGroup?
    var attachments: List<String>?
    
    // Must wait to set target (to self) in init. See https://stackoverflow.com/questions/45153589/selector-in-uibarbuttonitem-not-calling
    private var submitButton = UIBarButtonItem(image: UIImage(named: "0 Degrees Filled-25"), style: .plain, target: nil, action: #selector(submitForm))
    private let resetButton = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action: #selector(resetForm))

    // MARK: Initialization

    convenience init(_ submission: XFormSubmission) {
        self.init()
        form.delegate = self
        
        submitButton.target = self
        resetButton.target = self

        self.submission = submission
        
        // Initialize libxml2 document with primary instance
        let xmlBuffer: [Int8] = Array(submission.xml.utf8).map(Int8.init)
        xmlDoc = xmlReadMemory(UnsafePointer(xmlBuffer), Int32(xmlBuffer.count), "", "UTF-8", Int32(XML_PARSE_RECOVER.rawValue | XML_PARSE_NOERROR.rawValue))
        if (xmlDoc == nil) {
            assertionFailure("cannot create xml doc")
        }
        xform = submission.xform
        bindings = xform.bindings.map { $0 }
        controls = xform.controls.map { $0 }
        attachments = submission.attachments
        
        if xform.isGeoreferenced == true {
            print("This form is georeferenced!")
        }
        
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
        os_log("[%@ %s]", String(describing: Self.self), #function)
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
            
            // HACK to test pushing subpage
            /*
            if let group = control.group {
                if let row = rowForGroup(group: group, rowid: "group" + String(index)) {
                    section!.append(row)
                }
            }
*/
            
            let rowid = "control" + String(index)
            if let row = rowForControl(control: control, rowid: rowid) {
                section!.append(row)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        os_log("[%@ %s]", String(describing: Self.self), #function)
        super.viewWillAppear(animated)
        
        // Adjust for rotation
        let compact = view.traitCollection.horizontalSizeClass != .regular
        os_log("horizontalSizeClass = %s", compact ? "compact" : "regular")
        // TODO change any TextRows to/from TextFloatLabelRow if horizontalSizeClass different
        
        self.navigationItem.title = xform.name
        self.navigationItem.rightBarButtonItems = [submitButton, resetButton]
        self.navigationItem.backBarButtonItem?.title = "Cancel" // BUG no effect?!?

        self.revalidate()
        
        // Refresh form if popping back in case rows have changed
        if !self.isMovingToParent {
            self.refresh() // TODO only updateCell() specific rows
        }
    }
    
    // MARK: UI Actions

    @objc func submitForm() {
        os_log("[%@ %@]", String(describing: Self.self), #function)

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
            submitController = UIAlertController(title: String.init(format: "%.0f%% Complete", progress * 100.0),
                                                 message: String.init(format: "You have answered %d of %d required questions (%d remaining).", numAnswered, numRequired, numRequired-numAnswered),
                                                 preferredStyle: .alert)
            submitController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        self.present(submitController, animated: true)
    }
 
    @objc func resetForm() {
        os_log("[%@ %@]", String(describing: Self.self), #function)

        let resetController = UIAlertController(title: "Discard Changes",
                                      message: "Discard all changes and reset this form back to its original state?",
                                      preferredStyle: .alert)
        resetController.addAction(UIAlertAction(title: "Discard", style: .destructive, handler: { action in
            self.reset()
        }))
        resetController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(resetController, animated: true)
    }

    // MARK: Row --> XFormControl
    
    func controlForRow(row: BaseRow) -> XFormControl? {
        let prefix = "control" // row.tag = "controlXXX" where XXX is the index into controls[] array
        if let tag = row.tag, tag.hasPrefix(prefix), let index = Int(tag.dropFirst(prefix.count)) {
            return controls[index]
        }
        return nil
    }
    
    // MARK: XFormGroup --> Row
    
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

    // MARK: XFormControl --> Row

    func rowForControl(control: XFormControl, rowid: String) -> BaseRow? {
        //let binding = control.binding!
        // *********** FIX TRIGGERS! ****************
        //guard let binding = control.binding else { return nil } // BUG: ODK All_widgets.xml is missing binding for last trigger question, which causes crash!
        
        //let binding = control.binding
        
        //let node = binding.nodeset
        //let binding: XFormBinding
        
        let node: String
        if let binding = control.binding {
            node = binding.nodeset!
        } else {
            node = control.ref!
        }
        
        let iconInsets = UIEdgeInsets.init(top: 3, left: 6, bottom: 3, right: 0)
        
        // Add required and constraint validation rules
        // See also https://stackoverflow.com/questions/44306449
        var rules = RuleSet<String>()
        if let binding = control.binding, let required = binding.required, required != "false()" {
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
        if let binding = control.binding, let constraint = binding.constraint {
            let constraintRule = RuleClosure<String> { rowValue in
                return self.evaluateXPathBoolean(nodeset: node, expression: constraint) ? ValidationError(msg: binding.constraintMsg ?? "invalid value") : nil
            }
            rules.add(rule: constraintRule)
        }

        // Get row widget for the specified control type and appearance, if applicable
        var row: BaseRow
        switch control.type.value {
        
        // MARK: String Controls
        
        case ControlType.string.rawValue :
            let value = getStringForNode(nodeset: node)

            switch control.appearance {
                
            // ---------- multiline
            case "multiline" :
                row = TextAreaRow() {
                    $0.placeholder = control.label
                    $0.value = value
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            self.setValueForControl(control: control, value: row.value)
                        }
                    }
                }
                
            // ---------- numbers
            case "numbers" :
                row = TextRow() {
                    $0.value = value
                    $0.add(ruleSet: rules)
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            self.setValueForControl(control: control, value: row.value)
                        }
                    }}
                    .cellSetup { cell, row in
                        cell.textField.keyboardType = .decimalPad
                        if let _ = control.hint {
                            cell.accessoryType = .detailButton
                        }
                    }
              
            // ---------- URL
            case "url" :
                row = URLRow() {
                    $0.value = URL(string: value ?? "")
                    $0.onCellHighlightChanged { cell, row in
                        if row.isHighlighted { // open url when row is selected
                            if let url = row.value { UIApplication.shared.open(url) }
                            cell.textField.resignFirstResponder() // immediately stop editting!
                        }
                    }
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }

            // ---------- TODO: external app data capture
            case _ where ((control.appearance?.hasPrefix("ex:")) != nil) :
                os_log("unsupported appearance: %s", control.appearance!)
                row = TextRow() {
                    $0.disabled = true
                    $0.value = value
                    }
                    .cellSetup { cell, row in
                        if let _ = control.hint {
                            cell.accessoryType = .detailButton
                        }
                }
                
            default:
                // ---------- note
                // Special case: Note is a permanently readonly text control with no XML value
                if let readonly = control.binding?.readonly, readonly == "true()", value == nil {
                    row = LabelRow() {
                        $0.add(ruleSet: rules)
                        }
                        .cellSetup { cell, row in
                            if let _ = control.hint {
                                cell.accessoryType = .detailButton
                            }
                    }
                    
                // ---------- string
                } else {
                    row = TextRow() {
                        $0.value = value
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
                    }
                }
            }
            
        // MARK: Number Controls
        
        // ---------- integer
        case ControlType.integer.rawValue :
            let value = getNumberForNode(nodeset: node)

            switch control.appearance {
            
            // ---------- thousands-sep
            case "thousands-sep" :
                row = IntRow() {
                    if value != nil { $0.value = value!.intValue }

                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            let value = (row.value != nil) ? String(row.value!) : nil
                            self.setValueForControl(control: control, value: value)
                        }
                    }
                }
                .cellSetup { cell, row in
                    row.formatter = ThousandsIntegerFormatter()
                    row.useFormatterDuringInput = true
                    
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            // ---------- TODO: external app data capture
            case _ where ((control.appearance?.hasPrefix("ex:")) != nil) :
                os_log("unsupported appearance: %s", control.appearance!)
                row = IntRow() {
                    $0.disabled = true
                    if value != nil { $0.value = value!.intValue }
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }

            default :
                row = IntRow() {
                    if value != nil { $0.value = value!.intValue }

                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            let value = (row.value != nil) ? String(row.value!) : nil
                            self.setValueForControl(control: control, value: value)
                        }
                    }
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
            }
            
        case ControlType.decimal.rawValue :
            let value = getNumberForNode(nodeset: node)

            switch control.appearance {
             
            // ---------- thousands-sep
            case "thousands-sep" :
                row = DecimalRow() {
                    if value != nil { $0.value = value!.doubleValue }
                }
                .cellSetup { cell, row in
                    let formatter = row.formatter as! NumberFormatter
                    formatter.minimumFractionDigits = 0
                    formatter.maximumFractionDigits = 6
                    row.useFormatterOnDidBeginEditing = true
                    //row.useFormatterDuringInput = true // TODO realtime formatting messes up decimal point

                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            // ---------- bearing/compass
            case "bearing" :
                row = CompassRow() {
                    $0.onChange { row in
                        let value = (row.value != nil) ? String(row.value!) : nil
                        self.setValueForControl(control: control, value: value)
                    }
                }
                
            // ---------- TODO: external app data capture
            case _ where ((control.appearance?.hasPrefix("ex:")) != nil) :
                os_log("unsupported appearance: %s", control.appearance!)
                row = DecimalRow() {
                    $0.disabled = true
                    if value != nil { $0.value = value!.doubleValue }
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
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
                .cellSetup { cell, row in
                    let formatter = row.formatter as! NumberFormatter
                    formatter.minimumFractionDigits = 0
                    formatter.maximumFractionDigits = 6
                    formatter.groupingSeparator = ""
                    row.useFormatterOnDidBeginEditing = true
                    //row.useFormatterDuringInput = true // TODO realtime formatting messes up decimal point
                    
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
            }
            
        // MARK: Select-1 Controls
        // TODO: randomize options

        case ControlType.selectone.rawValue :
            switch control.appearance {
                
            // ---------- select1 compact
            case _ where control.appearance != nil && control.appearance!.hasPrefix("columns") : // detect columns-n
                fallthrough
            case "compact", "compact-2", "quickcompact", "quickcompact-2", "no-buttons", "columns", "columns-pack", "list", "label", "list-nolabel" :
                row = SegmentedRow<String>() {
                    if control.appearance == "list-nolabel" {
                        $0.options = Array(repeating: "", count: control.items.count) // Special case: hide labels!
                    } else {
                        $0.options = control.items.map { $0.label }
                    }
                    
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
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
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
                    }
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            // ---------- TODO: likert
            case "likert" :
                os_log("unsupported appearance: %s", control.appearance!)
                row = SliderRow() { // different base widget?
                    $0.disabled = true
                    $0.steps = UInt(control.items.count-1)
                }
                .cellSetup { cell, row in
                    row.shouldHideValue = true // only display the stars
                    cell.slider.minimumValue = 0.0
                    cell.slider.maximumValue = Float(control.items.count)
                    
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            // TODO: image-map
            // how display this inline? control may have no label text!
            case "image-map" :
                os_log("unsupported appearance: %s", control.appearance!)
                row = LabelRow() {
                    $0.add(ruleSet: rules)
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            // TODO: search? autocomplete (filter options based on text entry)
            case "search", "autocomplete" :
                os_log("unsupported appearance: %s", control.appearance!)
                row = PushRow<String>() {
                    $0.selectorTitle = control.label
                    $0.options = control.items.map { $0.label }
                    $0.disabled = true
                }
            
            // ---------- select1 full
            case "full", "quick" :
                fallthrough
            default :
                row = PushRow<String>() {
                    $0.selectorTitle = control.label
                    $0.options = control.items.map { $0.label }
                                      
                    /*
                    Push rows must have unique tag, which is obtained from the option label
                    itext options have no label string, instead must lookup value in instance XML:
                     
                    jr:itext('/data/select_one_widgets/grid_widget/a:label')
 
                    <text id="/data/select_one_widgets/grid_widget/a:label">
                      <value>A</value>
                      <value form="image">jr://images/a.jpg</value>
                    </text>
                    */
                    
                    // Workaround: remove all null options and disable entire row if none left!
                    $0.options = $0.options!.filter { $0.count > 0 }
                    $0.disabled = Condition(booleanLiteral: $0.options!.count == 0) // https://github.com/xmartlabs/Eureka/issues/1393

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
            
        // MARK: Select-Multi Controls
        // TODO: randomize
        
        // TODO: image-map

        case ControlType.select.rawValue :
            switch control.appearance {
            
            // ---------- select compact
            // TODO multi-select UISegmentedControl?
            case "compact", "compact-2", "list", "label", "list-nolabel" :
                os_log("unsupported appearance: %s", control.appearance!)
                row = SegmentedRow<String>() {
                    if control.appearance == "list-nolabel" {
                        $0.options = Array(repeating: "", count: control.items.count) // Special case: hide labels!
                    } else {
                        $0.options = control.items.map { $0.label }
                    }
                    $0.disabled = true
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            // ---------- select minimal
            // TODO multi-select UIPickeView?
            case "minimal" :
                os_log("unsupported appearance: %s", control.appearance!)
                row = PickerInlineRow<String>() {
                    $0.options = control.items.map { $0.label }
                    $0.disabled = true
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                    
            case "image-map" :
                os_log("unsupported appearance: %s", control.appearance!)
                row = LabelRow() {
                    $0.add(ruleSet: rules)
                    $0.disabled = true
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            case "autocomplete" :
                os_log("unsupported appearance: %s", control.appearance!)
                row = MultipleSelectorRow<String>() {
                    $0.selectorTitle = control.label
                    $0.options = control.items.map { $0.label }
                    $0.disabled = true
                }
                
            case "full" :
                fallthrough
            default :
                row = MultipleSelectorRow<String>() {
                    $0.selectorTitle = control.label
                    $0.options = control.items.map { $0.label }
                    
                    // Workaround: remove all null options and disable entire row if none left!
                    $0.options = $0.options!.filter { $0.count > 0 }
                    $0.disabled = Condition(booleanLiteral: $0.options!.count == 0) // https://github.com/xmartlabs/Eureka/issues/1393
                    
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
            }
            
        // MARK: Date & Time Controls

        // TODO show calendar for date and dateTime by default?
        
        case ControlType.datetime.rawValue :
            row = DateTimeRow(rowid) {
                if let dateTime = getStringForNode(nodeset: node) {
                    $0.value = XForm.dateTimeFormat.date(from: dateTime)
                }
                $0.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted { // lost focus (ie finished editing)
                        if let value = row.value {
                            self.setValueForControl(control: control, value: XForm.dateTimeFormat.string(from: value))
                        } else {
                            self.setValueForControl(control: control, value: nil)
                        }
                    }
                }
            }
            .cellSetup { cell, row in
                if let _ = control.hint {
                    cell.accessoryType = .detailButton
                }
            }
            
        case ControlType.date.rawValue :
            switch control.appearance {
            
            case "ethiopian", "coptic", "islamic", "bikram-sambat", "myanmar", "persian" :
                // TODO
                os_log("unsupported appearance: %s", control.appearance!)
                row = TextRow() {
                    $0.disabled = true
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }

            // ---------- year
            case "year" :
                // TODO custom picker with only year to replace UIDatePicker
                row = DateRow() {
                    $0.dateFormatter = DateFormatter()
                    $0.dateFormatter!.dateFormat = "yyyy"
                    if let date = getStringForNode(nodeset: node) {
                        $0.value = XForm.dateFormat.date(from: date)
                    }
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            if let date = row.value {
                                let calendar = Calendar.current
                                let newdate = calendar.date(from: calendar.dateComponents([.year], from: date))! // Note: this will set day and month to 1!
                                self.setValueForControl(control: control, value: XForm.dateFormat.string(from: newdate))
                            } else {
                                self.setValueForControl(control: control, value: nil)
                            }
                        }
                    }
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            // ---------- month-year
            case "month-year" :
                // TODO custom picker with only year and month to replace UIDatePicker
                row = DateRow() {
                    $0.dateFormatter = DateFormatter()
                    $0.dateFormatter!.dateFormat = "MM/yyyy" // Note: display format only
                    if let date = getStringForNode(nodeset: node) {
                        $0.value = XForm.dateFormat.date(from: date)
                    }
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            if let date = row.value {
                                let calendar = Calendar.current
                                let newdate = calendar.date(from: calendar.dateComponents([.year, .month], from: date))! // Note: this will set day 1!
                                self.setValueForControl(control: control, value: XForm.dateFormat.string(from: newdate))
                            } else {
                                self.setValueForControl(control: control, value: nil)
                            }
                        }
                    }
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
                
            // ---------- date
            default :
                row = DateRow() {
                    if let date = getStringForNode(nodeset: node) {
                        $0.value = XForm.dateFormat.date(from: date)
                    }
                    $0.onCellHighlightChanged { cell, row in
                        if !row.isHighlighted { // lost focus (ie finished editing)
                            if let date = row.value {
                                self.setValueForControl(control: control, value: XForm.dateFormat.string(from: date))
                            } else {
                                self.setValueForControl(control: control, value: nil)
                            }
                        }
                    }
                }
                .cellSetup { cell, row in
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
            }
            
        // ---------- time
        case ControlType.time.rawValue :
            row = TimeRow() {
                if let dateTime = getStringForNode(nodeset: node) {
                    $0.value = XForm.timeFormat.date(from: dateTime)
                }
                $0.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted { // lost focus (ie finished editing)
                        if let value = row.value {
                            self.setValueForControl(control: control, value: XForm.timeFormat.string(from: value))
                        } else {
                            self.setValueForControl(control: control, value: nil)
                        }
                    }
                }
            }
            .cellSetup { cell, row in
                if let _ = control.hint {
                    cell.accessoryType = .detailButton
                }
            }
         
        // MARK: GPS Controls

        // GPS location
        case ControlType.geopoint.rawValue :
            row = LocationRow() {
                $0.value = XForm.geopointTransformer.reverseTransformedValue(getStringForNode(nodeset: node)) as? CLLocation // XForm geopoint -> CLLocation
                
                // Note: always show map, even for no appearance. But restrict to GPS location unless placement-map
                if control.appearance != "placement-map" {
                    $0.trackUser = true // disable map pin for changing location
                }

                $0.displayValueFor = { value in
                    guard let location = value ?? nil else { return nil } // unwrap double optional; see https://stackoverflow.com/questions/33049246
                    return XForm.geopointTransformer.displayValue(location)
                }
                
                $0.onChange { row in
                    self.setValueForControl(control: control, value: XForm.geopointTransformer.transformedValue(row.value) as? String) // CLLocation -> XForm geopoint
                }
            }
             
        // GPS Path
        case ControlType.geotrace.rawValue :
            // TODO
            os_log("unsupported control type: %d", control.type.value!)
            row = TextRow() {
                $0.disabled = true
            }

        // GPS region
        case ControlType.geoshape.rawValue :
            // TODO
            os_log("unsupported control type: %d", control.type.value!)
            row = TextRow() {
                $0.disabled = true
            }

        // MARK: Boolean Controls

        case ControlType.boolean.rawValue :
            let value = getBoolForNode(nodeset: node) // Note: null -> 0
            switch control.appearance {
                
            // ---------- checkmark
            case "checkmark" :
                row = SwitchRow() {
                    $0.value = value
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
                    $0.value = value
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
            
        // MARK: Range Controls
        
        case ControlType.range.rawValue :
            let value = getNumberForNode(nodeset: node) // Note: null -> 0
            
            switch control.appearance {
            
            // ---------- picker
            case "picker" :
                if control.binding?.type.value == 5 { // decimal
                    row = PickerInlineRow<Float>() {
                        $0.options = Array(stride(from: control.min.value!, through: control.max.value!, by: control.inc.value!))
                        $0.value = value?.floatValue
                        $0.onChange { row in
                            self.setValueForControl(control: control, value: String(row.value!))
                        }
                    }
                    .cellSetup { cell, row in
                        if let _ = control.hint {
                            cell.accessoryType = .detailButton
                        }
                    }
                } else { // integer
                    row = PickerInlineRow<Int>() {
                        $0.options = Array(stride(from: Int(control.min.value!), through: Int(control.max.value!), by: Int(control.inc.value!)))
                        $0.value = value?.intValue
                        $0.onChange { row in
                            self.setValueForControl(control: control, value: String(Int(row.value!)))
                        }
                    }
                    .cellSetup { cell, row in
                        if let _ = control.hint {
                            cell.accessoryType = .detailButton
                        }
                    }
                }
                
            // ---------- rating (stars)
            // TODO handle non-1 start value, fractional step, fractional end value, ...
            case "rating" :
                row = RatingRow() {
                    $0.value = value?.doubleValue ?? 0.0
                    $0.shouldHideValue = true
                    
                    if (control.binding?.type.value == 4) { // integer
                        $0.displayValueFor = { return "\(Int($0 ?? 0))" }
                    }
                    
                    $0.onChange { row in
                        if (control.binding?.type.value == 4) { // integer
                            self.setValueForControl(control: control, value: String(Int(row.value!)))
                        } else { // decimal
                            self.setValueForControl(control: control, value: String(Float(row.value!)))
                        }
                    }
                }
                .cellSetup { cell, row in
                    cell.rating.settings.totalStars = Int(ceil(control.max.value!))
                    if (control.binding?.type.value == 4) { // integer
                        cell.rating.settings.fillMode = .full
                    } else {
                        cell.rating.settings.fillMode = .precise
                    }
                    
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }

            // ---------- TODO: vertical?
            case "vertical" :
                fallthrough
                
            default:
                row = SliderRow() {
                    $0.steps = UInt((control.max.value! - control.min.value!) / control.inc.value!)
                    $0.value = value?.floatValue ?? control.min.value! // BUG WORKAROUND - must always have value otherwise slider not shown
                    
                    if (control.binding?.type.value == 4) { // integer
                        $0.displayValueFor = { return "\(Int($0 ?? 0))" }
                    }
                }
                .cellSetup { cell, row in
                    cell.slider.minimumValue = control.min.value!
                    cell.slider.maximumValue = control.max.value!
                    
                    /* IMPORTANT
                     Cannot use .onChange event to update XForm value because the form refresh causes slider to de-select, which immediately halts the sliding action.
                     And cannot make slider.isContinuous = false because then the displayed value wont continuously update while sliding.
                     So instead add an explicit update closure for when user releases slider; ie touchUpInside or touchUpOutside
                    */
                    let update = { [weak cell] () -> Void in
                        if let weakCell = cell {
                            self.setValueForControl(control: control, value: NSNumber(value: weakCell.slider.value).stringValue) // float -> NSNumber -> String
                        }
                    }
                    cell.slider.addAction(for: .touchUpInside, update)
                    cell.slider.addAction(for: .touchUpOutside, update)
                    
                    if let _ = control.hint {
                        cell.accessoryType = .detailButton
                    }
                }
            }
            
        // MARK: Misc Controls

        // ---------- trigger
        case ControlType.trigger.rawValue :
            let value = getStringForNode(nodeset: node)
            row = ButtonRow() {
                $0.value = value
                $0.onCellSelection { cell, row in
                    self.setValueForControl(control: control, value: "OK")
                    row.title = "✓"
                    row.reload() // needed to refresh the title
                    cell.backgroundColor = .systemGreen
                }
                .cellSetup { cell, row in
                    // Initialize as triggered if value is already 'OK'
                    if row.value == "OK" {
                        row.title = "✓"
                        cell.backgroundColor = .systemGreen
                    }
                }
            }
            
        // ---------- secret
        case ControlType.secret.rawValue :
            row = PasswordRow() {
                $0.value = getStringForNode(nodeset: node)
                $0.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted { // lost focus (ie finished editing)
                        self.setValueForControl(control: control, value: row.value)
                    }
                }
            }
           
        // ---------- barcode, QR code
        // TODO add clear button to BarcodeScannerRow?
        case ControlType.barcode.rawValue :
            row = BarcodeScannerRow() {
                $0.value = getStringForNode(nodeset: node)
                $0.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted { // lost focus (ie finished editing)
                        self.setValueForControl(control: control, value: row.value)
                    }
                }
            }
            .cellSetup { cell, row in
                //if let _ = control.hint { cell.accessoryType = .detailButton }
                cell.accessoryView = UIImageView(image: UIImage(named: "icons8-barcode-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets))
                cell.accessoryView?.tintColor = .systemBlue
            }

        // ---------- ranking
        case ControlType.rank.rawValue :
            // TODO: use Eureka MultivaluedSection viewcontroller?
            os_log("unsupported control type: %d", control.type.value!)
            row = TextRow() {
                $0.disabled = true
            }

        // MARK: Photos, Images
        
        case ControlType.binary.rawValue :
            if control.mediatype!.starts(with: "image") {
                switch control.appearance {
                    
                // ---------- signature
                case "signature" :
                    row = SignatureRow() {
                    $0.placeholderImage = UIImage.init(named: "icons8-autograph-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets)
                    
                    if let filename = getStringForNode(nodeset: node) {
                        // load image from documents directory
                        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let url = documents.appendingPathComponent(filename)
                        os_log("loading signature from %@", url.absoluteString)
                        $0.value = try? UIImage(data: Data(contentsOf: url))
                    }
                        
                    $0.onChange { row in //4
                        if let image = row.value {
                            // save jpeg image to documents directory using UUID filename
                            let uuid = UUID().uuidString
                            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let url = documents.appendingPathComponent(uuid).appendingPathExtension("jpg")
                            if let data = image.jpegData(compressionQuality: 0.7) {
                                os_log("saving image to %@ (%d kB)", url.absoluteString, data.count/1024)
                                try! data.write(to: url) // TODO handle write errors
                                self.setValueForControl(control: control, value: url.lastPathComponent)
                            }
                        } else {
                            // Clear previous image
                            self.setValueForControl(control: control, value: nil)
                        }
                    }}
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }

                // ---------- draw (signature subclass)
                case "draw" :
                    row = DrawRow() {
                    $0.placeholderImage = UIImage.init(named: "icons8-design-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets)
                    
                    if let filename = getStringForNode(nodeset: node) {
                        // load image from documents directory
                        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let url = documents.appendingPathComponent(filename)
                        os_log("loading image from %@", url.absoluteString)
                        $0.value = try? UIImage(data: Data(contentsOf: url))
                    }
                        
                    $0.onChange { row in //4
                        if let image = row.value {
                            // save jpeg image to documents directory using UUID filename
                            let uuid = UUID().uuidString
                            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let url = documents.appendingPathComponent(uuid).appendingPathExtension("jpg")
                            if let data = image.jpegData(compressionQuality: 0.7) {
                                os_log("saving image to %@ (%d kB)", url.absoluteString, data.count/1024)
                                try! data.write(to: url) // TODO handle write errors
                                self.setValueForControl(control: control, value: url.lastPathComponent)
                            }
                        } else {
                            // Clear previous image
                            self.setValueForControl(control: control, value: nil)
                        }
                    }}
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
                
                // ---------- photo
                // CRITICAL: Info.plist must contain NSCameraUsageDescription key
                default:
                    row = ImageRow() {
                        $0.placeholderImage = UIImage.init(named: "icons8-camera-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets)
                        $0.clearAction = .yes(style: .destructive) // BUG clear causes onChange: to save placeholder image!
                        
                        if let appearance = control.appearance {
                            // Enable image editting
                            if appearance.contains("annotate") {
                                $0.allowEditor = true
                                $0.useEditedImage = true
                                // TODO use Draw UI overlay
                            } else {
                                $0.allowEditor = false
                            }
                            
                            // Disable choosing existing image
                            if ["new", "selfie", "new-front"].contains(where: appearance.contains) {
                                $0.sourceTypes = .Camera
                            } else {
                                $0.sourceTypes = .All
                            }
                            
                            // TODO Default to front camera
                            if ["selfie", "new-front"].contains(where: appearance.contains) {
                                //$0.imagePickerController.cameraDevice = UIImagePickerController.CameraDevice.front
                            }
                        }

                        if let filename = getStringForNode(nodeset: node) {
                            // load image from documents directory
                            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let url = documents.appendingPathComponent(filename)
                            os_log("loading photo from %@", url.absoluteString)
                            $0.value = try? UIImage(data: Data(contentsOf: url))
                        }
                        
                        $0.onChange { row in
                            // TODO delete old file if clear or replace
                            if let image = row.value {
                                // save jpeg image to documents directory
                                let uuid = UUID().uuidString
                                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                                let url = documents.appendingPathComponent(uuid).appendingPathExtension("jpg")
                                if let data = image.jpegData(compressionQuality: 0.5) {
                                    os_log("saving image to %@ (%d kB)", url.absoluteString, data.count/1024)
                                    try! data.write(to: url) // TODO handle write errors
                                    // TODO add EXIF (GPS, timestamp, etc) using CGImageDestinationAddImage?
                                    self.setValueForControl(control: control, value: url.lastPathComponent)
                                    self.submission.attachments.append(url.absoluteString)
                                }
                            } else {
                                // Clear previous image
                                self.setValueForControl(control: control, value: nil)
                            }
                        }}
                        .cellSetup { cell, row in
                            cell.accessoryView?.tintColor = .systemBlue
                        }
                    }
                
            // MARK: Video

            // ---------- video
            // CRITICAL: Info.plist must contain NSPhotoLibraryUsageDescription key
            } else if control.mediatype!.starts(with: "video") {
                //os_log("unsupported media type: %s", control.mediatype!)
                row = _VideoRow("eventPromoVideoTag"){
                    $0.disabled = false
                    
                    if let filename = getStringForNode(nodeset: node) {
                        // load image from documents directory
                        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let url = documents.appendingPathComponent(filename)
                        os_log("loading video from %@", url.absoluteString)
                        let asset: PHAsset? = PHAssetForFileURL(url: url as NSURL)
                        // TODO
                        //row.value = TLPHAsset(phAsset: asset, selectedOrder: 0, type: 0);
                    }
                    
                    $0.onChange { row in
                        // TODO delete old file if clear or replace
                        if let tlphAsset = row.value, let phAsset = tlphAsset.phAsset {
                            // save video file to documents directory using UUID filename
                            let uuid = UUID().uuidString
                            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let url = documents.appendingPathComponent(uuid).appendingPathExtension("mov")
                            
                            // save PHAsset video to file
                            // https://stackoverflow.com/questions/35652094/how-to-get-nsdata-from-file-by-using-phasset
                            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: nil, resultHandler: { (asset, mix, nil) in
                                                let myAsset = asset as? AVURLAsset
                                                let data = try! Data(contentsOf: (myAsset?.url)!) // TODO catch exception
                                                os_log("saving video to %@ (%d kB)", url.absoluteString, data.count/1024)
                                                try! data.write(to: url) // TODO handle write errors
                                
                                                // https://realm.io/docs/swift/latest/#threading
                                                DispatchQueue.main.async {
                                                    self.setValueForControl(control: control, value: url.lastPathComponent) // CRITICAL: otherwise 'Realm accessed from incorrect thread' crash
                                                }
                                            })
                        } else {
                            // Clear previous image
                            self.setValueForControl(control: control, value: nil)
                        }
                    }}
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
/*
                    if let filename = getStringForNode(nodeset: node) {
                        // TODO load video from documents directory
                    } else {
                        $0.value = UIImage.init(named: "icons8-video-call-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                    }
                    
                    $0.onChange { row in //4
                        // TODO delete old file if clear or replace
                        if let video = row.value {
                            // TODO save mpeg video to documents directory using UUID filename
                        } else {
                            // Clear previous video
                            self.setValueForControl(control: control, value: nil)
                            row.value = UIImage.init(named: "icons8-video-call-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // restore placeholder
                        }
                    }}
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
 */
              
            // MARK: Audio
            // TODO ---------- audio
            } else if control.mediatype!.starts(with: "audio") {
                os_log("unsupported media type: %s", control.mediatype!)
                row = ImageRow() {
                    $0.disabled = true
                    $0.value = UIImage.init(named: "icons8-voice-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                    }
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
                
            // MARK: Documents
            // TODO ---------- document
            } else {
                os_log("unsupported media type: %s", control.mediatype!)
                row = ImageRow() {
                    $0.disabled = true
                    $0.value = UIImage.init(named: "icons8-document-33")?.withRenderingMode(.alwaysTemplate).withInset(iconInsets) // placeholder
                    }
                    .cellSetup { cell, row in
                        cell.accessoryView?.tintColor = .systemBlue
                    }
            }
         
        default:
            os_log("unrecognized control type: %d", control.type.value!)
            return nil
        }
        
        row.tag = rowid
        row.title = control.label
        row.validationOptions = .validatesOnDemand // validate all rows on form.validate()

        // TODO do this dynamically in refresh
        if let readonly = control.binding?.readonly, readonly == "true()" {
            row.disabled = true
        }
        
        return row
    }
    
    // MARK: Update & Refresh

    func setValueForControl(control: XFormControl!, value: String?) {
        //let nodeset = control.binding!.nodeset!
        let node: String
        if let binding = control.binding {
            node = binding.nodeset!
        } else {
            node = control.ref!
        }
        
        self.setValueForNode(nodeset: node, value: value)
        self.recalculate(nodeset: node)
        self.revalidate() // TODO revalidate only dependent controls from DAG
        self.refresh() // TODO refresh only dependent controls from DAG
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
        os_log("[%@ %s]", String(describing: Self.self), #function)
        form.validate()
        
        // TODO Determine number of required (and relevant) questions, and number of those answered
        numRequired = 0
        numAnswered = 0
        
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
        os_log("[%@ %s]", String(describing: Self.self), #function)
        self.tableView.reloadData()
    }
    
    // See https://www.w3.org/TR/xforms11/#evt-reset
    func reset() {
        os_log("[%@ %s]", String(describing: Self.self), #function)
        // TODO
    }

    func submit() {
        os_log("[%@ %s]", String(describing: Self.self), #function)
        // TODO
        os_log("[%@ %s] XML=%s", String(describing: Self.self), #function, xmlString() ?? "(null)")
        server?.submit(submission: submission, completion: { error in
            os_log("[%@ %s]", String(describing: Self.self), #function)
            // TODO show result in popup

        })
    }
    
    // MARK: <UITableViewDelegate>

    // Hint
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let row = form[indexPath.section][indexPath.row]
        if let control = controlForRow(row: row), let hint = control.hint {
            let info = UIAlertController.init(title: "Hint", message: nil, preferredStyle: .alert)
            let isMarkup = hint.contains("\n") // if hint contains non-plaintext then display as HTML
            if (isMarkup) {
                info.setValue(NSAttributedString(html: hint, font: UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)), forKey: "attributedMessage") // HACK: private API!
            } else {
                info.message = hint
            }
            
            info.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(info, animated: true)
        }
    }
    
    // MARK: <FormDelegate>
    
    override func valueHasBeenChanged(for row: BaseRow, oldValue: Any?, newValue: Any?) {
        os_log("[%@ %@]", String(describing: Self.self), #function)
        super.valueHasBeenChanged(for: row, oldValue: oldValue, newValue: newValue)
    }
    
    // MARK: Rotation

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if let previous = previousTraitCollection, previous.horizontalSizeClass != traitCollection.horizontalSizeClass {
            if traitCollection.horizontalSizeClass == .compact {
                os_log("[%@ %@] switch to compact layout", String(describing: Self.self), #function)
            } else {
                os_log("[%@ %@] switch to regular layout", String(describing: Self.self), #function)
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
        os_log("[%@ %s] nodeset=%s value=%s", String(describing: Self.self), #function, nodeset, value ?? "(null)")
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
            os_log("[%@ %s] XML=%s", String(describing: Self.self), #function, xmlString() ?? "(null)")
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
