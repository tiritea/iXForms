//
//  LocationRow.swift
//  iXForms
//
//  Created by Gareth Bestor on 12/12/20.
//  Copyright © 2020 Xiphware. All rights reserved.
//

import Eureka
import MapKit

public final class LocationRow: OptionsRow<PushSelectorCell<CLLocation>>, PresenterRowType, RowType {
    
    public typealias PresenterRow = MapViewController
    
    public var map: MKMapView?
    public var trackUser = false
    
    /// Defines how the view controller will be presented, pushed, etc.
    public var presentationMode: PresentationMode<PresenterRow>?
    
    /// Will be called before the presentation occurs.
    public var onPresentCallback: ((FormViewController, PresenterRow) -> Void)?

    public required init(tag: String?) {
        super.init(tag: tag)
        presentationMode = .show(controllerProvider: ControllerProvider.callback { return MapViewController(){ _ in } }, onDismiss: { vc in _ = vc.navigationController?.popViewController(animated: true) })

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

public class MapViewController : UIViewController, TypedRowControllerType, MKMapViewDelegate {

    public var row: RowOf<CLLocation>!
    public var onDismissCallback: ((UIViewController) -> ())?
    
    var location: CLLocation?
    let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: nil, action: #selector(MapViewController.save(_:)))

    // MARK: Map

    lazy var mapView : MKMapView = { [unowned self] in
        let v = MKMapView(frame: self.view.bounds)
        v.delegate = self
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.showsUserLocation = true
        v.isScrollEnabled = true
        v.isZoomEnabled = true
        v.isPitchEnabled = false
        v.isRotateEnabled = false
        v.userTrackingMode = .none
        v.mapType = .standard

        // TODO move to under top safe area?
        let scale = MKScaleView(mapView: v)
        scale.scaleVisibility = .visible // always
        v.addSubview(scale)
        scale.translatesAutoresizingMaskIntoConstraints = false
        scale.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 50).isActive = true
        scale.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -12).isActive = true
            
        let mapButton = UIButton(type: .custom)
        mapButton.imageView?.contentMode = .scaleAspectFit
        mapButton.setImage(UIImage(named: "icons8-waypoint-map-50")?.withRenderingMode(.alwaysTemplate), for: .normal)
        mapButton.setImage(UIImage(named: "icons8-world-map-50")?.withRenderingMode(.alwaysTemplate), for: .selected)
        mapButton.tintColor = .systemBlue
        mapButton.sizeToFit() // 50x50
        mapButton.addTarget(self, action: #selector(changeMap), for: .touchUpInside)
        v.addSubview(mapButton)
        mapButton.translatesAutoresizingMaskIntoConstraints = false
        mapButton.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10).isActive = true
        mapButton.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -10).isActive = true

        return v
    }()

    // MARK: Pin

    lazy var pinView: UIImageView = { [unowned self] in
        let v = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        v.image = UIImage(named: "map_pin", in: Bundle(for: MapViewController.self), compatibleWith: nil)
        v.image = v.image?.withRenderingMode(.alwaysTemplate)
        v.tintColor = self.view.tintColor
        v.backgroundColor = .clear
        v.clipsToBounds = true
        v.contentMode = .scaleAspectFit
        v.isUserInteractionEnabled = false
        return v
        }()

    // MARK: Elipse

    let width: CGFloat = 20.0
    let height: CGFloat = 10.0

    lazy var ellipse: UIBezierPath = { [unowned self] in
        let ellipse = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        return ellipse
        }()

    lazy var ellipsisLayer: CAShapeLayer = { [unowned self] in
        let layer = CAShapeLayer()
        layer.bounds = CGRect(x: 0, y: 0, width: self.width, height: self.height)
        layer.path = self.ellipse.cgPath
        layer.fillColor = UIColor.red.cgColor
        layer.fillRule = .nonZero
        layer.lineCap = .butt
        layer.lineDashPattern = nil
        layer.lineDashPhase = 0.0
        layer.lineJoin = .miter
        layer.lineWidth = 1.5
        layer.miterLimit = 10.0
        layer.strokeColor = UIColor.white.cgColor
        return layer
        }()

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    convenience public init(_ callback: ((UIViewController) -> ())?){
        self.init(nibName: nil, bundle: nil)
        onDismissCallback = callback
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        saveButton.target = self
        navigationItem.rightBarButtonItem = saveButton
        
        view.addSubview(mapView)

        if (row as! LocationRow).trackUser == true {
            mapView.userTrackingMode = .follow
            mapView.isScrollEnabled = false
            mapView.isZoomEnabled = false // TODO add pinch gesture to zoom (default behavior repositions map center!)
        } else {
            mapView.addSubview(pinView)
            mapView.layer.insertSublayer(ellipsisLayer, below: pinView.layer)
        }
        
        // TODO show previous location when tracking user?
        
        if let value = row.value {
            moveTo(value)
            //let region = MKCoordinateRegion(center: value.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000) // initially show 1km region around previous location
            //mapView.setRegion(region, animated: true)
        } else {
            print("default region") // otherwise mapView will default to a region based on device locale
        }
        
         updateTitle()
    }

    @objc func changeMap(sender : UIButton) {
        sender.isSelected.toggle()
        mapView.mapType = sender.isSelected ? .hybridFlyover : .standard
    }

    func moveTo(_ location: CLLocation) {
        print("moveTo")
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(region, animated: true)
        self.location = location
        print("location=",location)
        print("map center=",mapView.center)
        updateTitle()
    }
    
    public func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        print("didUpdate")
        guard let location = userLocation.location else { return }
        self.location = location
        updateTitle()
    }
    
    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        print("didSelect")
        if let annotation = view.annotation, annotation.isEqual(mapView.userLocation), let location = mapView.userLocation.location {
            // TODO dont zoom *out* if the current region is already smaller
            moveTo(location)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                mapView.deselectAnnotation(mapView.userLocation, animated: true)
            }
        }
    }
  
    /*
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = "annotation"
        if annotation.isEqual(mapView.userLocation) {
            if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                annotationView.annotation = annotation
                return annotationView
            } else {
                let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView.isEnabled = true
                annotationView.canShowCallout = true
                let button = UIButton(type: .system)
                button.setTitle("Save", for: .normal)
                button.sizeToFit()
                annotationView.rightCalloutAccessoryView = button
                return annotationView
            }
        }
        return nil
    }
    */
    
    /*
    public func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        print("calloutAccessoryControlTapped")
        if let annotation = view.annotation, annotation.isEqual(mapView.userLocation) {
            row.value = mapView.userLocation.location
            onDismissCallback?(self)
        }
    }
    */
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let center = mapView.convert(mapView.centerCoordinate, toPointTo: pinView)
        pinView.center = CGPoint(x: center.x, y: center.y - (pinView.bounds.height/2))
        ellipsisLayer.position = center
    }

    @objc func save(_ sender: UIBarButtonItem) {
        if (row as! LocationRow).trackUser == true {
            row.value = mapView.userLocation.location
        } else {
            //let target = mapView.convert(ellipsisLayer.position, toCoordinateFrom: mapView) // target is the center of ellipse, not map!
            //row.value = CLLocation(latitude: target.latitude, longitude: target.longitude)
            row.value = location
        }
        onDismissCallback?(self)
    }

    func updateTitle() {
        //title = self.row.displayValueFor!(CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude))
        title = self.row.displayValueFor!(location)
    }

    // Raise pin when start scrolling
    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        ellipsisLayer.transform = CATransform3DMakeScale(0.5, 0.5, 1)
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.pinView.center = CGPoint(x: self!.pinView.center.x, y: self!.pinView.center.y - 10)
            })
    }

    // Drop pin when finish scrolling
    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        ellipsisLayer.transform = CATransform3DIdentity
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.pinView.center = CGPoint(x: self!.pinView.center.x, y: self!.pinView.center.y + 10)
            })
        
        let target = mapView.convert(ellipsisLayer.position, toCoordinateFrom: mapView) // target is the center of ellipse, not map!
        location = CLLocation(latitude: target.latitude, longitude: target.longitude)
        updateTitle()
    }
}
