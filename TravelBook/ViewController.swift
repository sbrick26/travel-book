//
//  ViewController.swift
//  TravelBook
//
//  Created by Swayam Barik on 10/12/21.
//

import UIKit
import MapKit
import CoreLocation
import CoreData

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var noteText: UITextField!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    
    var locationManager = CLLocationManager()
    
    var chosenLatitude = Double()
    var chosenLongitude = Double()
    
    var selectedTitle = ""
    var selectedID: UUID?
    
    var annotationTitle = ""
    var annotationSub = ""
    var annotationLat = Double()
    var annotationLong = Double()

    override func viewDidLoad() {
        super.viewDidLoad()
        // set delegate of map like tableview to self, import, and delegate in class name
        mapView.delegate = self
        locationManager.delegate = self
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // diff levels to save battery and data -- ex. tinder woulnd't need best, but navigation would need best
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Gesture Recon
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(chooseLocation(gestureRecognizer:)))
                                                             
        // Do any additional setup after loading the view.
        gestureRecognizer.minimumPressDuration = 1.5
        mapView.addGestureRecognizer(gestureRecognizer)
        
        if selectedTitle != "" {
            // go to core data and get information and mute editing
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
            let idString = selectedID!.uuidString
            fetchRequest.predicate = NSPredicate(format: "id=%@", idString)
            fetchRequest.returnsObjectsAsFaults = false
            
            do {
                let results = try context.fetch(fetchRequest)
                if results.count > 0 {
                    for result in results as! [NSManagedObject] {
                        if let title = result.value(forKey: "title") as? String {
                            annotationTitle = title
                        }
                        if let subtitle = result.value(forKey: "subtitle") as? String {
                            annotationSub = subtitle
                        }
                        if let latitude = result.value(forKey: "latitude") as? Double {
                            annotationLat = latitude
                        }
                        if let longitude = result.value(forKey: "longitude") as? Double {
                            annotationLong = longitude
                        }
                        let annotation = MKPointAnnotation()
                        annotation.title = annotationTitle
                        annotation.subtitle = annotationSub
                        let coordinate = CLLocationCoordinate2D(latitude: annotationLat, longitude: annotationLong)
                        annotation.coordinate = coordinate
                        
                        mapView.addAnnotation(annotation)
                        nameText.text = annotationTitle
                        noteText.text = annotationSub
                        
                        locationManager.stopUpdatingLocation()
                        
                        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        let region = MKCoordinateRegion(center: coordinate, span: span)
                        mapView.setRegion(region, animated: true)
                    }
                }
            } catch {
                print("Fetch Error")
            }
            
        }
        else {
            // original add data screen
        }
                                        
    }
    
    @objc func chooseLocation(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            
            // alert to make sure that the name and note field are added before adding an annotation
            if nameText.text == "" || noteText.text == "" {
                let alert = UIAlertController(title: "Please fill out the fields above.", message: "Cannot add an annotation without both name and note.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true)
                
            }
            // lets user add location only if name and note field are both filled out
            else {
                
                // checks if annotations are already on map, and if so delete the annotation from the screen before adding a new annotation
                if !self.mapView.annotations.isEmpty {
                    let annotations = self.mapView.annotations
                    self.mapView.removeAnnotations(annotations)
                }
                
                let touchPoint = gestureRecognizer.location(in: self.mapView)
                let touchCoordinates = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView)
                
                chosenLatitude = touchCoordinates.latitude
                chosenLongitude = touchCoordinates.longitude
                // create pin/annotation
                let annotation = MKPointAnnotation()
                annotation.coordinate = touchCoordinates // set coordinate
                annotation.title = nameText.text
                annotation.subtitle = noteText.text
                self.mapView.addAnnotation(annotation)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // function to get current location, gives array of locations
        
        if selectedTitle == "" {
            let location = CLLocationCoordinate2D(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude) // locations.first alternative maybe
            
            // define width and height of map region
            let span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            
            // make region by combing location and span
            let region = MKCoordinateRegion(center: location, span: span)
            mapView.setRegion(region, animated: true)
        }
        
        
        // DONE // TODO: Fix region constantly fixated on user location to allow for map exploration
        
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is MKUserLocation {
            return nil
        }
        
        let resuseID = "myAnnotation"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: resuseID) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: resuseID)
            pinView?.canShowCallout = true
            pinView?.tintColor = UIColor.gray
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure)
            pinView?.rightCalloutAccessoryView = button
        }
        else {
            pinView?.annotation = annotation
        }
        
        return pinView
    }
    
    //callout accesory detial
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if selectedTitle != "" {
            let requestLocation = CLLocation(latitude: annotationLat, longitude: annotationLong)
            CLGeocoder().reverseGeocodeLocation(requestLocation) { placemarks, error in
                //closure type, gives multiple outputs for when action completes
                
                if let placemark = placemarks {
                    if placemark.count > 0 {
                        let newPlacemark = MKPlacemark(placemark: placemark[0])
                        let item = MKMapItem(placemark: newPlacemark)
                        item.name = self.annotationTitle
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDefault]
                        item.openInMaps(launchOptions: launchOptions)
                        
                    }
                }
                
            }
        }
    }

    @IBAction func saveButtonClicked(_ sender: Any) {
        
        // save to Core Data when button is clicked
        
        // alert to make sure that all data is filled out before saving to Core Data
        if nameText.text == "" || noteText.text == "" || self.mapView.annotations.isEmpty {
            let alert = UIAlertController(title: "Please complete all fields before saving.", message: "Cannot save data without name, note, AND map annotation.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
        
        // runs if every field is filled out before saving
        else {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            // establish new item for Core Data entity
            let newPlace = NSEntityDescription.insertNewObject(forEntityName: "Places", into: context)
            
            // Add to everything in Core Data Database
            newPlace.setValue(nameText.text, forKey: "title")
            newPlace.setValue(noteText.text, forKey: "subtitle")
            newPlace.setValue(chosenLatitude, forKey: "latitude")
            newPlace.setValue(chosenLongitude, forKey: "longitude")
            newPlace.setValue(UUID(), forKey: "id")
            
            
            // do try catch to save data
            do{
                try context.save()
                print("Saved to Core Data")
            } catch {
                print("Could not save properly")
            }
            
            NotificationCenter.default.post(name: NSNotification.Name("newPlace"), object: nil)
            navigationController?.popViewController(animated: true)
        }

    }
    
}

