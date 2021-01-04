//
//  GSBAlertRow.swift
//  iXForms
//
//  Created by Gareth Bestor on 28/10/20.
//  Copyright © 2020 Xiphware. All rights reserved.
//

import Eureka

// Identical to the Eureka AlertRow but adds an optional Alert message
/*
 $0.onPresent { from, alert in // Note: alert as! SelectorAlertController
     if let location = iXForms.location {
         alert.title = "Current GPS location:"
         alert.message = XForm.geopointTransformer.displayValue(location)
         alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { action in
             alert.row.value = location
             alert.onDismissCallback?(alert) // this will invoke .onChange() to save location
         }))
     } else {
         alert.title = "⚠️ Unable to acquire GPS fix"
         alert.message = "Please ensure location services are enabled and try again."
     }
 }
 */

open class _GSBAlertRow<Cell: CellType>: AlertOptionsRow<Cell>, PresenterRowType where Cell: BaseCell {

    public typealias PresentedController = SelectorAlertController<_GSBAlertRow<Cell>>
    
    open var message: String?
    
    open var onPresentCallback: ((FormViewController, PresentedController) -> Void)?
    lazy open var presentationMode: PresentationMode<PresentedController>? = {
        return .presentModally(controllerProvider: ControllerProvider<PresentedController>.callback { [weak self] in
            let vc = PresentedController(title: self?.selectorTitle, message: self?.message, preferredStyle: .alert)
            vc.row = self
            return vc
        }, onDismiss: { [weak self] in
            $0.dismiss(animated: true)
            self?.cell?.formViewController()?.tableView?.reloadData()
        })
    }()

    public required init(tag: String?) {
        super.init(tag: tag)
    }

    open override func customDidSelect() {
        super.customDidSelect()
        if let presentationMode = presentationMode, !isDisabled {
            if let controller = presentationMode.makeController() {
                controller.row = self
                onPresentCallback?(cell.formViewController()!, controller)
                presentationMode.present(controller, row: self, presentingController: cell.formViewController()!)
            } else {
                presentationMode.present(nil, row: self, presentingController: cell.formViewController()!)
            }
        }
    }
}

/// An options row where the user can select an option from a modal Alert
public final class GSBAlertRow<T: Equatable>: _GSBAlertRow<AlertSelectorCell<T>>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}
