//
//  MultiLocationRow.swift
//  iXForms
//
//  Created by Gareth Bestor on 12/12/20.
//  Copyright © 2020 Xiphware. All rights reserved.
//

import Eureka
import MapKit

// MARK: Row

public final class MultiLocationRow: OptionsRow<PushSelectorCell<CLLocation>>, PresenterRowType, RowType {
    
    public typealias PresenterRow = MultiMapViewController
    
    public var trackUser = false // expose MKMapView.userTrackingMode
    
    /// Defines how the view controller will be presented, pushed, etc.
    public var presentationMode: PresentationMode<PresenterRow>?
    
    /// Will be called before the presentation occurs.
    public var onPresentCallback: ((FormViewController, PresenterRow) -> Void)?

    public required init(tag: String?) {
        super.init(tag: tag)
        presentationMode = .show(controllerProvider: ControllerProvider.callback { return MultiMapViewController(){ _ in } }, onDismiss: { vc in _ = vc.navigationController?.popViewController(animated: true) })

        displayValueFor = {
            guard let location = $0 else { return "" }
            let fmt = NumberFormatter()
            fmt.maximumFractionDigits = 4
            fmt.minimumFractionDigits = 4
            let latitude = fmt.string(from: NSNumber(value: location.coordinate.latitude))!
            let longitude = fmt.string(from: NSNumber(value: location.coordinate.longitude))!
            return  "\(latitude), \(longitude)"
        }
    }
    
    /**
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
    
    /**
     Prepares the pushed row setting its title and completion callback.
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

// MARK: ViewController

public class MultiMapViewController : UIViewController, TypedRowControllerType, MKMapViewDelegate, UIGestureRecognizerDelegate {
    public typealias RowValue = CLLocation
    
//public class MultiMapViewController : MapViewController {

    public var row: RowOf<RowValue>!
    public var onDismissCallback: ((UIViewController) -> ())?
    
    let mapView = MKMapView()
    let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: nil, action: #selector(MapViewController.save(_:)))
    var location: CLLocation?

    lazy var marker: UIImageView = { [unowned self] in
        let view = UIImageView(image: UIImage(named: "icons8-marker-50")?.withRenderingMode(.alwaysTemplate))
        view.tintColor = .systemRed
        view.contentMode = .scaleAspectFit
        view.sizeToFit()
        return view
    }()

    lazy var markerShadow: CAShapeLayer = { [unowned self] in
        let layer = CAShapeLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 15, height: 7.5) // must be 2:1 for mapView:regionWillChangeAnimated: circle transform
        layer.path = UIBezierPath(ovalIn: layer.bounds).cgPath
        layer.fillColor = UIColor.systemRed.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 1.5
        return layer
    }()
    
    var isTracking = false {
        didSet {
            if isTracking {
                mapView.isScrollEnabled = false
                mapView.userTrackingMode = .follow
                marker.isHidden = true
                markerShadow.isHidden = true
                mapView.tintColor = .red
            } else {
                mapView.isScrollEnabled = true
                mapView.userTrackingMode = .none
                marker.isHidden = false
                markerShadow.isHidden = false
                mapView.tintColor = nil // default blue
            }
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    convenience public init(_ callback: ((UIViewController) -> ())?){
        self.init(nibName: nil, bundle: nil)
        onDismissCallback = callback
        mapView.delegate = self
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
                
        saveButton.target = self
        navigationItem.rightBarButtonItem = saveButton
        
        // Mapview
        view.addSubview(mapView)
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.showsUserLocation = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.isZoomEnabled = true
        mapView.mapType = .standard

        // Map scale indicator
        let scale = MKScaleView(mapView: mapView)
        scale.scaleVisibility = .visible // always
        view.addSubview(scale)
        scale.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([ // top left
            scale.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            scale.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor)
        ])
        
        // Toggle map type
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(changeMapType), for: .touchUpInside)
        button.setImage(UIImage(named: "icons8-waypoint-map-33")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.setImage(UIImage(named: "icons8-world-map-33")?.withRenderingMode(.alwaysTemplate), for: .selected)
        button.tintColor = .systemBlue
        button.imageView?.contentMode = .scaleAspectFit
        button.sizeToFit()
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([ // bottom right
            button.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -10)
        ])
        
        isTracking = (row as! LocationRow).trackUser
        if isTracking {
            location = mapView.userLocation.location // Note: dont show previous location if trackUser
        } else {
            mapView.addSubview(marker)
            mapView.layer.insertSublayer(markerShadow, below: marker.layer)

            // Add UIPanGestureRecognizer to detect user interaction to disable location tracking, but otherwise doesn't do anything
            let panGesture = UIPanGestureRecognizer(target: self, action: nil)
            panGesture.delegate = self
            mapView.addGestureRecognizer(panGesture)
            
            location = row.value
            if location != nil {
                let region = MKCoordinateRegion(center: location!.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000) // show 1km region around previous location
                mapView.setRegion(region, animated: true)
            }
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let center = mapView.convert(mapView.centerCoordinate, toPointTo: marker)
        marker.center = CGPoint(x: center.x, y: center.y - (marker.bounds.height/2))
        markerShadow.position = center
        
        if !marker.isHidden {
            let target = mapView.convert(markerShadow.position, toCoordinateFrom: mapView)
            setLocation(CLLocation(latitude: target.latitude, longitude: target.longitude))
        } else {
            setLocation(location) // update title
        }
    }

    func setLocation(_ location: CLLocation?) {
        self.location = location
        if location != nil {
            title = row.displayValueFor!(location)
        } else {
            title = "Acquiring..."
        }
    }
    
    func setMapLocation() {
        // Update location from map only when *manually* repositioning. Use marker visibility because it is immediately set when userLocationAnnotation selected, so we can ignore region changes resulting from zooming into userLocation
        guard(!marker.isHidden) else { return }
        let target = mapView.convert(markerShadow.position, toCoordinateFrom: mapView) // target is the center of ellipse, not map!
        setLocation(CLLocation(latitude: target.latitude, longitude: target.longitude))
    }

    // MARK: UI Actions

    @objc func save(_ sender: UIBarButtonItem) {
        row.value = location
        onDismissCallback?(self)
    }

    @objc func changeMapType(sender : UIButton) {
        sender.isSelected.toggle()
        mapView.mapType = sender.isSelected ? .hybridFlyover : .standard
    }
    
    // MARK: UIGestureRecognizerDelegate
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        isTracking = false // Note: this enables scrolling, displays marker, etc. See isTracking.didSet()
        return true
    }
    
    // MARK: MKMapViewDelegate
    
    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        // Raise pin when start scrolling
        markerShadow.transform = CATransform3DMakeScale(0.375, 0.75, 1) // change ellipse to circle
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.marker.center = CGPoint(x: self!.marker.center.x, y: self!.marker.center.y - 10)
            })
    }

    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Drop pin when finish scrolling
        markerShadow.transform = CATransform3DIdentity // restore ellipse
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.marker.center = CGPoint(x: self!.marker.center.x, y: self!.marker.center.y + 10)
            })
        
        // Hide popup after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            mapView.deselectAnnotation(mapView.userLocation, animated: true)
        }
        setMapLocation()
    }
    
    public func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        setMapLocation() // continuously update location in title when scrolling map
    }
    
    public func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard mapView.userTrackingMode == .follow, let location = userLocation.location else { return }
        setLocation(location)
    }
    
    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let annotation = view.annotation, annotation.isEqual(mapView.userLocation), let location = mapView.userLocation.location {
            // Start tracking user location. Note: cant use isTracking because doing everything at once interferes with zooming
            marker.isHidden = true
            markerShadow.isHidden = true
            
            setLocation(location)
            // TODO dont zoom *out* if already zoomed in closer
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapView.setRegion(region, animated: true)
            mapView.userTrackingMode = .follow
            mapView.tintColor = .red
        }
    }
}
