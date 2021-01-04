// TODO subclass ImageRow/ImageCell instead

import Eureka
import Foundation
import UIKit
import SwiftSignatureView

// MARK: Cell

public class SignatureCell: PushSelectorCell<UIImage> {
    public override func setup() {
        super.setup()
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        imageView.contentMode = .scaleAspectFit
        accessoryView = imageView
        editingAccessoryView = accessoryView
    }
    
    public override func update() {
        super.update()
        
        selectionStyle = row.isDisabled ? .none : .default
        (accessoryView as? UIImageView)?.image = row.value ?? (row as? ImageRowProtocol)?.thumbnailImage ?? (row as? ImageRowProtocol)?.placeholderImage
    }
}

//MARK: Row

public protocol ImageRowProtocol {
    var placeholderImage: UIImage? { get }
    var thumbnailImage: UIImage? { get }
}

open class SwiftSignatureViewController: UIViewController, TypedRowControllerType  {
    let signatureView = SwiftSignatureView()
    public var row: RowOf<UIImage>!
    public var onDismissCallback: ((UIViewController) -> ())?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        self.view = signatureView
        self.view.backgroundColor = .white
        self.title = "Signature"
        
        /*
        // initialize to previous signature, if any
        if let image = row.value {
            signatureView.signature = image
        }
        */
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(SwiftSignatureViewController.save(_:)))
        let clearButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(SwiftSignatureViewController.clear(_:)))
        navigationItem.rightBarButtonItems = [doneButton, clearButton]
    }
        
    @objc func save(_ sender: UIBarButtonItem) {
        row.value = signatureView.getCroppedSignature()
        onDismissCallback?(self)
    }
        
    @objc func clear(_ sender: UIBarButtonItem) {
        signatureView.clear()
    }
}

open class _SignatureRow<Cell: CellType>: OptionsRow<Cell>, PresenterRowType, ImageRowProtocol where Cell: BaseCell, Cell.Value == UIImage {
    public typealias PresenterRow = SwiftSignatureViewController
    
    open var presentationMode: PresentationMode<PresenterRow>?
    open var onPresentCallback: ((FormViewController, PresenterRow) -> Void)?
    open var placeholderImage: UIImage?
    open var thumbnailImage: UIImage?
    
    public required init(tag: String?) {
        super.init(tag: tag)
        
        presentationMode = .show(controllerProvider: ControllerProvider.callback(builder: { () -> SwiftSignatureViewController in
            return SwiftSignatureViewController()
            }),
            onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
            })
        
        self.displayValueFor = nil
    }
    
    public override func customDidSelect() {
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
    
    open override func prepare(for segue: UIStoryboardSegue) {
        super.prepare(for: segue)
        guard let rowVC = segue.destination as? PresenterRow else { return }
        rowVC.title = selectorTitle ?? rowVC.title
        rowVC.onDismissCallback = presentationMode?.onDismissCallback ?? rowVC.onDismissCallback
        onPresentCallback?(cell.formViewController()!, rowVC)
        rowVC.row = self
    }
}

public final class SignatureRow: _SignatureRow<SignatureCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}
