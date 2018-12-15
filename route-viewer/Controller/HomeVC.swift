//
//  ViewController.swift
//  route-viewer
//
//  Created by Mohammad Irteza Khan on 12/13/18.
//  Copyright © 2018 Irteza. All rights reserved.
//

import UIKit
import Mapbox
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation

class HomeVC: UIViewController {
    
    let mapView = NavigationMapView()
    let headerView = UIView()
    let EtaTextView = UITextView()
    let distanceTextView = UITextView()
    
    var routes: [Route]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMapView()
        setupRecenterButton()
        setupMapStyleSelector()
        setupHeaderView()
        
        let longPressRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(handleLongPress(sender:)))
        mapView.addGestureRecognizer(longPressRecognizer)
    }
    
    func setupMapView() {
        mapView.delegate = self
        mapView.navigationMapDelegate = self
        
        mapView.frame = view.bounds
        mapView.styleURL = MGLStyle.streetsStyleURL
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.locationManager.startUpdatingLocation()
        mapView.showsUserLocation = true
        mapView.setUserTrackingMode(.follow, animated: true)
        view.addSubview(mapView)
    }
    
    func setupRecenterButton() {
        let recenterButton = UIButton(type: .system)
        let buttonImage = UIImage.init(named: "recenter-button")

        recenterButton.setImage(buttonImage, for: .normal)
        recenterButton.addTarget(self, action: #selector(moveMapToUserLocation), for: .touchUpInside)
        view.insertSubview(recenterButton, aboveSubview: mapView)
        
        recenterButton.translatesAutoresizingMaskIntoConstraints = false
        
        recenterButton.centerXAnchor.constraint(equalTo: mapView.rightAnchor, constant: -20).isActive = true
        recenterButton.bottomAnchor.constraint(equalTo: mapView.logoView.topAnchor, constant: -20).isActive = true
        recenterButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        recenterButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
    }
    
    func setupMapStyleSelector() {
        let styleSelector = UISegmentedControl(items: ["Satellite", "Streets", "Dark"])
        styleSelector.translatesAutoresizingMaskIntoConstraints = false
        styleSelector.tintColor = UIColor.init(red: 0.211, green: 0.219, blue: 0.294, alpha: 1)
        styleSelector.backgroundColor = UIColor.white
        styleSelector.layer.cornerRadius = 4
        styleSelector.clipsToBounds = true
        styleSelector.selectedSegmentIndex = 1
        view.insertSubview(styleSelector, aboveSubview: mapView)
        styleSelector.addTarget(self, action: #selector(changeStyle(sender:)), for: .valueChanged)
        
        styleSelector.centerXAnchor.constraint(greaterThanOrEqualTo: mapView.centerXAnchor).isActive = true
        styleSelector.bottomAnchor.constraint(equalTo: mapView.logoView.topAnchor).isActive = true
    }
    
    func setupHeaderView() {
        headerView.backgroundColor = UIColor.white
        
        view.insertSubview(headerView, aboveSubview: mapView)
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        headerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        headerView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        headerView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        headerView.addSubview(EtaTextView)
        EtaTextView.translatesAutoresizingMaskIntoConstraints = false
        
        EtaTextView.leftAnchor.constraint(equalTo: headerView.leftAnchor, constant: 10).isActive = true
        EtaTextView.rightAnchor.constraint(equalTo: headerView.rightAnchor, constant: 10).isActive = true
        EtaTextView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 30).isActive = true
        EtaTextView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        headerView.isHidden = true
    }
    
    @objc func moveMapToUserLocation() {
        mapView.setUserTrackingMode(.follow, animated: true)
    }
    
    @objc func handleLongPress(sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .ended:
            let selectedPoint: CGPoint = sender.location(in: mapView)
            let selectedLocation: CLLocationCoordinate2D = mapView.convert(selectedPoint, toCoordinateFrom: mapView)
            addAnnotation(at: selectedLocation)
            guard let currentLocation = mapView.userLocation?.coordinate else { return }
            calculateRoute(from: currentLocation, to: selectedLocation) { (route, error) in
                if error != nil {
                    print("Error calculating route")
                }
            }
        default:
            break
        }
    }
    
    @objc func changeStyle(sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            mapView.styleURL = MGLStyle.satelliteStyleURL
        case 1:
            mapView.styleURL = MGLStyle.streetsStyleURL
        case 2:
            mapView.styleURL = MGLStyle.darkStyleURL
        default:
            mapView.styleURL = MGLStyle.streetsStyleURL
        }
        // Reset the map to initial view and remove previously added items
        self.clearView()
    }
    
    func addAnnotation(at coordinate: CLLocationCoordinate2D) {
        self.clearView()
        let annotation = MGLPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Show direction"
        mapView.addAnnotation(annotation)
    }
    
    func clearView() {
        // Clear previously added annotations
        if let annotations = mapView.annotations {
            mapView.removeAnnotations(annotations)
        }
        headerView.isHidden = true
        self.hidePreviousRoute()
    }
    
    func calculateRoute(from origin: CLLocationCoordinate2D,
                        to destination: CLLocationCoordinate2D,
                        completion: @escaping (Route?, Error?) -> ()) {
        
        let origin = Waypoint(coordinate: origin, coordinateAccuracy: -1, name: "My location")
        let destination = Waypoint(coordinate: destination, coordinateAccuracy: -1, name: "Selected location")
        
        let options = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .automobile)
        
        _ = Directions.shared.calculate(options) { [unowned self] (waypoints, routes, error) in
            self.hidePreviousRoute()
            self.routes = routes
            self.drawRoute(routes: routes)
            self.zoomToFitRoute(route: routes?.first)
            self.showRouteInfo(of: routes?.first)
        }
        
    }
    
    func hidePreviousRoute() {
        // Hide all the lines starting with the id "line" that were added previously
        guard let layers = mapView.style?.layers else { return }
        for layer in layers {
            if layer.identifier.contains("line-") {
                layer.isVisible = false
            }
        }
    }
    
    func drawRoute(routes: [Route]?) {
        guard let routes = routes else { return }
        for i in stride(from: 0, to: routes.count, by: 1) {
            let route = routes[i]
            if route.coordinateCount == 0 {
                continue
            }
            
            var routeCoordinates = route.coordinates!
            let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: route.coordinateCount)
            
            // Try to reuse the previously added polyline if available or create a new one
            if let source = mapView.style?.source(withIdentifier: "source-\(i)") as? MGLShapeSource {
                source.shape = polyline
            } else {
                let source = MGLShapeSource(identifier: "source-\(i)", features: [polyline], options: nil)
                mapView.style?.addSource(source)
            }
            
            if let source = mapView.style?.source(withIdentifier: "source-\(i)") as? MGLShapeSource {
                // Try to reuse the previously added line if available or else draw a new one
                if (mapView.style?.layer(withIdentifier: "line-\(i)") as? MGLLineStyleLayer) == nil {
                    // Mark first route as a selected route
                    if i == 0 {
                        let lineStyle = MGLLineStyleLayer(identifier: "line-\(i)", source: source)
                        lineStyle.lineColor = NSExpression(forConstantValue: UIColor.blue)
                        lineStyle.lineWidth = NSExpression(forConstantValue: 5)
                        mapView.style?.addLayer(lineStyle)
                    }
                    else {
                        let selectedLine = mapView.style?.layer(withIdentifier: "line-0") as? MGLLineStyleLayer
                        let alternateLineStyle = MGLLineStyleLayer(identifier: "line-\(i)", source: source)
                        alternateLineStyle.lineColor = NSExpression(forConstantValue: UIColor.gray)
                        alternateLineStyle.lineWidth = NSExpression(forConstantValue: 5)
                        mapView.style?.insertLayer(alternateLineStyle, below: selectedLine!)
                    }
                }
                else {
                    (mapView.style?.layer(withIdentifier: "line-\(i)") as? MGLLineStyleLayer)!.isVisible = true
                }
            }
        }
    }
    
    func zoomToFitRoute(route: Route?) {
        guard let route = route else { return }
        if route.coordinateCount == 0 {
            return
        }
        let centerPoint = getCenterPoint(of: route)
        
        // Get the farthest distance of the route from the center, so that whole route is showed up if route has unusual shape
        let farthestDistance = getFarthestDistance(from: centerPoint, to: route.coordinates!)
        let altitude = (2 * farthestDistance) / tan(Double.pi * (15/180.0))
        let camera = MGLMapCamera(lookingAtCenter: centerPoint, fromEyeCoordinate: centerPoint, eyeAltitude: altitude)
        mapView.setCamera(camera, animated: true)
    }
    
    func getCenterPoint(of route: Route) -> CLLocationCoordinate2D {
        var topLeftCoord: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: -90, longitude: 180 )
        var bottomRightCoord: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 90, longitude: -180 )
        
        for coordinate in route.coordinates! {
            let tempLoc: CLLocation = CLLocation.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            topLeftCoord.latitude = fmax((topLeftCoord.latitude), (tempLoc.coordinate.latitude))
            topLeftCoord.longitude = fmin((topLeftCoord.longitude), (tempLoc.coordinate.longitude))
            
            bottomRightCoord.latitude = fmin((bottomRightCoord.latitude), (tempLoc.coordinate.latitude))
            bottomRightCoord.longitude = fmax((bottomRightCoord.longitude), (tempLoc.coordinate.longitude))
        }
        
        var centerCoordinate : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        centerCoordinate.latitude = (topLeftCoord.latitude) - ((topLeftCoord.latitude) - (bottomRightCoord.latitude)) * 0.5
        centerCoordinate.longitude = (topLeftCoord.longitude) + ((bottomRightCoord.longitude) - (topLeftCoord.longitude)) * 0.5
        
        return centerCoordinate
    }
    
    func getFarthestDistance(from centerCoordinate: CLLocationCoordinate2D, to coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        var farthestDistance: CLLocationDistance = 0
        for coordinate in coordinates {
            farthestDistance = max(farthestDistance, centerCoordinate.distance(to: coordinate))
        }
        
        return farthestDistance
    }
    
    func showRouteInfo(of route: Route?) {
        guard let route = route else { return }
        EtaTextView.text = "ETA: \(getETA(time: route.expectedTravelTime))"
        headerView.isHidden = false
    }
    
    func getETA(time: TimeInterval) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .medium
        return dateFormatter.string(from: Date().addingTimeInterval(time))
    }

}


extension HomeVC: MGLMapViewDelegate, NavigationMapViewDelegate {
    
}
