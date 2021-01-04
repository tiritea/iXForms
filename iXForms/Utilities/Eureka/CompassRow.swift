//
//  CompassRow.swift
//  iXForms
//
//  Created by Gareth Bestor on 29/12/20.
//  Copyright © 2020 Xiphware. All rights reserved.
//

import Eureka
import CoreLocation

public class CompassViewController: UIViewController, TypedRowControllerType, CLLocationManagerDelegate {

    public var row: RowOf<Double>! // *** CHANGE *** RowOf<...> type must match row's class definition
    public var onDismissCallback: ((UIViewController) -> ())?

    let locationManager = CLLocationManager()
    var heading: CLHeading?
    let saveButton = UIButton(type: .system)
    let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: nil, action: #selector(cancel(_:)))
    let compassView = GSBCompassView()
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // *** CHANGE *** Custom view controller setup goes here...

        cancelButton.target = self
        navigationItem.rightBarButtonItem = cancelButton
        view.backgroundColor = .white

        locationManager.requestWhenInUseAuthorization()
        if (CLLocationManager.headingAvailable()) {
            title = "Acquiring..."
            
            // Save button
            let button = UIButton(type: .system)
            button.setTitle("Save", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 24)
            button.addTarget(self, action: #selector(save(_:)), for: .touchUpInside)
            button.sizeToFit()
            view.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                button.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor)
            ])
            
            // Compass
            view.addSubview(compassView)
            compassView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                compassView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                compassView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
                compassView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
                compassView.bottomAnchor.constraint(equalTo: button.topAnchor, constant: 5)
            ])

            // Start updating compass...
            locationManager.delegate = self
            locationManager.headingFilter = 0.5
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        } else {
            title = "Compass Unavailable"
        }
    }
     
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        self.heading = heading
        compassView.compassDegress = -1 * heading.magneticHeading
        compassView.setNeedsDisplay()
        updateTitle()
    }
    
    func updateTitle() {
        title = self.row.displayValueFor!(heading?.magneticHeading)
    }
    
    @objc func save(_ sender: UIBarButtonItem) {
        row.value = heading?.magneticHeading
        onDismissCallback?(self)
    }
    
    @objc func cancel(_ sender: UIButton) {
        onDismissCallback?(self)
    }
}

public final class CompassRow: OptionsRow<PushSelectorCell<Double>>, PresenterRowType, RowType { // *** CHANGE *** Return type must match controller.row type
    
    public typealias PresenterRow = CompassViewController // *** CHANGE ***
        
    // Defines how the view controller will be presented, pushed, etc.
    public var presentationMode: PresentationMode<PresenterRow>?
    
    // Will be called before the presentation occurs.
    public var onPresentCallback: ((FormViewController, PresenterRow) -> Void)?

    public required init(tag: String?) {
        super.init(tag: tag)
        presentationMode = .show(controllerProvider: ControllerProvider.callback { return PresenterRow() },
                                 onDismiss: { vc in
                                    _ = vc.navigationController?.popViewController(animated: true)
                                 })
        
        // *** OPTIONAL *** Custom format for displaying result
        displayValueFor = {
            guard let value = $0 else { return "" }
            let fmt = NumberFormatter()
            fmt.maximumFractionDigits = 1
            fmt.minimumFractionDigits = 1
            fmt.minimumIntegerDigits = 1
            return fmt.string(from: NSNumber(value: value as Double))! + "°"
        }
    }
    
    /*
     Extends `didSelect` method
     */
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
    
    /*
     Prepares the pushed row setting its title and completion callback
     */
    public override func prepare(for segue: UIStoryboardSegue) {
        super.prepare(for: segue)
        guard let rowVC = segue.destination as? PresenterRow else { return }
        rowVC.title = selectorTitle ?? rowVC.title
        rowVC.onDismissCallback = presentationMode?.onDismissCallback ?? rowVC.onDismissCallback
        onPresentCallback?(cell.formViewController()!, rowVC)
        rowVC.row = self
    }
}
