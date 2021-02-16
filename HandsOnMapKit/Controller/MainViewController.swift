//
//  MainViewController.swift
//  HandsOnMapKit
//
//  Created by Allicia Viona Sagi on 22/12/20.
//

import UIKit
import MapKit
import CoreLocation

class MainViewController: UIViewController, CLLocationManagerDelegate, UISearchBarDelegate, MKLocalSearchCompleterDelegate, MKMapViewDelegate, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    

    // MARK: - Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var lblDistance: UILabel!
    @IBOutlet weak var lblPrice: UILabel!
    @IBOutlet var myTableView: UITableView!
    @IBOutlet var startSearchField: UITextField!
    @IBOutlet var refocusButton: UIImageView!
    @IBOutlet var destinationSearchField: UITextField!
    
    @IBOutlet var pinImage: UIImageView!
    // MARK: - Location Objects
    let locationManager = CLLocationManager()
    
    // MARK: - Search Objects
    let searchRequest = MKLocalSearch.Request()
    
    // MARK: - Completer Objects
    let completer = MKLocalSearchCompleter()
    
    // MARK: - Geocoder Objects
    let geoCoder = CLGeocoder()
    
    // MARK: - Local Variables
    private var myLocation: CLLocation?
    private var destination: CLLocation?
    private var completionString: [String] = []
    private var directionsArray: [MKDirections] = []
    private var previousLocation: CLLocation?
    private var pinCoordinate: CLLocationCoordinate2D?
    private var calculatingRoute = 0
    private var startSearchForRoute: Bool?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startSearchField.delegate = self
        startSearchField.returnKeyType = .search
        destinationSearchField.delegate = self
        destinationSearchField.returnKeyType = .search
        
        // MARK: - Delegate Completer
        completer.delegate = self
        
        // MARK: - Request for Location Permission
        locationManager.requestWhenInUseAuthorization()
        
        // MARK: - Make Sure Location Service is Enabled / Allowed
        if CLLocationManager.locationServicesEnabled() {
            showUserLocation(status: true)
        }
        refocusButton.layer.cornerRadius = 24
        refocusButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.refocusButtonTapped(_:))))
    }
    
    @objc func refocusButtonTapped(_ sender: UITapGestureRecognizer? = nil) {
        for overlay in mapView.overlays{
            mapView.removeOverlay(overlay)
        }
        locationManager.startUpdatingLocation()
        previousLocation = getCenterLocation(for: mapView)
        
        mapView.removeAnnotations(mapView.annotations)
        
        self.lblDistance.text = "0.0 KM"
        self.lblPrice.text = "0"
        self.calculatingRoute = 0
        self.pinImage.isHidden = false
        self.destinationSearchField.text = ""
        self.completer.queryFragment = ""
        completionString = []
    }
    
    // MARK: - Function to Show User's Location in Map
    func showUserLocation(status: Bool) {
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.startUpdatingLocation()
        previousLocation = getCenterLocation(for: mapView)
        self.mapView.showsUserLocation = status
        
    }
    
    // MARK: - Function to Search a Location Using Text
    func searchLocation(locationName: String) {
        
        searchRequest.naturalLanguageQuery = locationName
        
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { (response, error) in
            guard let response = response else {
                print("Error: \(error?.localizedDescription ?? "Unknown error").")
                return
            }
            
            for item in response.mapItems {
                
                self.destination = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                
                if let distance = self.destination?.distance(from: self.myLocation!) {
                    let convertDistance = distance/1000
                    self.lblDistance.text = "\(convertDistance.string(fractionDigits: 1)) KM"
                }
                
            }
        }
    }
    
    // MARK: - Updating User's Location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // Ambil lokasi pertama dari array of locations
        if let location = locations.first {
            
            // MARK: - Setting Map View Area
            let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            let region = MKCoordinateRegion(center: location.coordinate, span: span)
            mapView.setRegion(region, animated: true)
            completer.region = region
            self.pinCoordinate = location.coordinate
            
            // MARK: - Saving User's Location
            let lat = location.coordinate.latitude
            let long = location.coordinate.longitude
            
            self.myLocation =  CLLocation(latitude: lat , longitude: long)
            
            // MARK: - Converting User's Location to Text-Based Information
            
            geoCoder.reverseGeocodeLocation(location) { (placemarks, error) in
                guard let placeMark = placemarks?.first else { return }
                
                // Get User's Street Name from User's Coordinate
                let streetNumber = placeMark.subThoroughfare ?? ""
                let streetName = placeMark.thoroughfare ?? ""

                DispatchQueue.main.async {
                    self.startSearchField.text = "\(streetNumber) \(streetName)"
                }
                
            }
        }
//        self.pinCoordinate = placemark.location?.coordinate
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Updating Value from Search Bar
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchLocation(locationName: searchText)
    }
    
    // MARK: - Table View Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if completionString.isEmpty == true || startSearchForRoute == true
        {
            return completionString.count
        }
        else
        {
            return completionString.count + 1
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "identifierMyCell")
        if startSearchForRoute == false
        {
            if indexPath.row == 0
            {
                cell?.textLabel?.text = "Use Current Location"
            }
            else
            {
                cell?.textLabel?.text = completionString[indexPath.row-1]
            }
            return cell!
        }
        else
        {
            cell?.textLabel?.text = completionString[indexPath.row]
            
            return cell!
        }
        
    }
    
    // MARK: - Drawing Polylines and Calculating Distance
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        
        if startSearchForRoute == false
        {
            if indexPath.row == 0
            {
                geoCoder.reverseGeocodeLocation(locationManager.location!) { (placemarks, error) in
                    guard let placeMark = placemarks?.first else { return }
                    
                    // Get User's Street Name from User's Coordinate
                    let streetNumber = placeMark.subThoroughfare ?? ""
                    let streetName = placeMark.thoroughfare ?? ""
                    self.pinCoordinate = placeMark.location?.coordinate
                    DispatchQueue.main.async {
                        self.startSearchField.text = "\(streetNumber) \(streetName)"
                    }
                    
                }
            }
            else
            {
                
                geoCoder.geocodeAddressString((cell?.textLabel?.text)!) { (placemarks, error) in
                    guard let placemark = placemarks?.first else { return }
                    
                    self.startSearchField.text = cell?.textLabel?.text
                    
                    self.pinCoordinate = placemark.location!.coordinate
                }
            }
            completionString = []
            self.completer.queryFragment = ""
            self.myTableView.reloadData()
        }
        else
        {
            self.pinImage.isHidden = true
            self.calculatingRoute = 8
            // Ngambil informasi location dari string yang diselect
            geoCoder.geocodeAddressString((cell?.textLabel?.text)!) { (placemarks, error) in
                guard let placemark = placemarks?.first else { return }
                
                self.destinationSearchField.text = cell?.textLabel?.text
                
                let startAnno = MKPointAnnotation()
                let anno = MKPointAnnotation()
                anno.coordinate = placemark.location!.coordinate
                startAnno.coordinate = self.pinCoordinate!
                //anno.title = self.searchBar.text!
                
                let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                let region = MKCoordinateRegion(center: anno.coordinate, span: span)
                
                self.mapView.setRegion(region, animated: true)
                self.mapView.addAnnotation(startAnno)
                self.mapView.addAnnotation(anno)
                self.mapView.selectAnnotation(anno, animated: true)
                
                let request = self.createDirectionsRequest(from: self.pinCoordinate!, to: placemark.location!.coordinate)
                let directions = MKDirections(request: request)
                self.resetMapView(withNew: directions)
                
                directions.calculate { [unowned self] (response, error) in
                    guard let response = response else { return }
                    
                    let convertDistance = response.routes.first!.distance / 1000
                    self.lblDistance.text = "\(convertDistance.string(fractionDigits: 1)) KM"
                    self.lblPrice.text = String(Int(convertDistance) * 3500)
                    
                    
                    for route in response.routes {
                        
                        self.mapView.addOverlay(route.polyline)
                        self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Creating a Direction Request
    func createDirectionsRequest(from coordinate: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> MKDirections.Request {
        let startingLocation = MKPlacemark(coordinate: coordinate)
        let destination = MKPlacemark(coordinate: destination)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: startingLocation)
        request.destination = MKMapItem(placemark: destination)
        request.transportType = .automobile
        
        return request
    }

    // MARK: - Dismiss Keyboard When Canceled
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.view.endEditing(true)
        completionString = []
        self.myTableView.reloadData()
    }
    
    // MARK: - Dismiss Keyboard and Trigger Completer When Searching
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
    }
    
    // MARK: - Reset MapView Overlays
    func resetMapView(withNew directions: MKDirections) {
        mapView.removeOverlays(mapView.overlays)
        
        directionsArray.append(directions)
        let _ = directionsArray.map { $0.cancel() }
    }
    
    // MARK: - Getting Completer Results
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer.results.first != nil else {
            return
        }
        if completer.results.count != 0 && completer.results.count <= 5
        {
            for result in completer.results
            {
                completionString.append(result.title)
            }
        }
        else
        {
            completionString.append(completer.results.first!.title)
        }
        
        self.myTableView.reloadData()
    }
    
    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        print("Error suggesting a location: \(error.localizedDescription)")
    }
    
    // MARK: - Getting Center Pin Location
    func getCenterLocation(for mapView: MKMapView) -> CLLocation {
        let latitude = mapView.centerCoordinate.latitude
        let longitude = mapView.centerCoordinate.longitude
        
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - Handle Events Whenever Region in MapView Changed
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let center = getCenterLocation(for: mapView)
        print("Calculting Route: \(self.calculatingRoute)")
        guard let previousLocation = self.previousLocation else { return }
        
        guard center.distance(from: previousLocation) > 50 else { return }
        self.previousLocation = center
        
        geoCoder.cancelGeocode()
        
        geoCoder.reverseGeocodeLocation(center) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            
            if let _ = error {
                //TODO: Show alert informing the user
                return
            }
            
            guard let placemark = placemarks?.first else {
                //TODO: Show alert informing the user
                return
            }
            self.pinCoordinate = placemark.location?.coordinate
            let streetNumber = placemark.subThoroughfare ?? ""
            let streetName = placemark.thoroughfare ?? ""
            
            DispatchQueue.main.async {
                if self.calculatingRoute == 0
                {
                    self.startSearchField.text = "\(streetNumber) \(streetName)"
                }
                else{
                    self.calculatingRoute -= 1
                }
                
            }
        }
    }
    
    // MARK: - Setup for Polyline color, width, etc
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay as! MKPolyline)
        renderer.strokeColor = .blue
        return renderer
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        completionString = []
        if textField == startSearchField
        {
            
            self.completer.queryFragment = self.startSearchField.text!
            startSearchForRoute = false
        }
        else
        {
            self.completer.queryFragment = self.destinationSearchField.text!
            startSearchForRoute = true
        }
        
        return true
    }
    
}
