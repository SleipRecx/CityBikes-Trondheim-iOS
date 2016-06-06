//
//  TableViewController.swift
//  Bysykkel
//  Created by Markus Andresen on 02/05/16.
//  Copyright © 2016 Markus Andresen. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import CoreLocation
import Foundation

class TableViewController: UITableViewController, UISearchResultsUpdating, CLLocationManagerDelegate,UIPopoverPresentationControllerDelegate {
    
    var searchController : UISearchController!
    var refreshController = UIRefreshControl()
    var resultController = UITableViewController()
    let locationManager = CLLocationManager()

    
    @IBOutlet weak var mySegmentedControl: UISegmentedControl!
    @IBOutlet weak var searchButton: UIBarButtonItem!
   
    var places: [BikePlace] = []
    var filteredPlaces: [BikePlace] = []
    var favorites: [BikePlace] = []

    
    override func viewDidLoad(){
        super.viewDidLoad()

        let backItem = UIBarButtonItem()
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
    
        let searchBarItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Search, target: self, action: #selector(TableViewController.searchPressed))
        searchBarItem.tintColor = UIColor.whiteColor()
        navigationItem.rightBarButtonItem = searchBarItem
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        self.resultController.tableView.dataSource = self
        self.resultController.tableView.delegate = self
        self.refreshControl = self.refreshController
        self.refreshController.addTarget(self, action: #selector(TableViewController.refreshTable), forControlEvents: .ValueChanged)
        
        self.searchController = UISearchController(searchResultsController: self.resultController)
        self.searchController.dimsBackgroundDuringPresentation = true
        self.searchController.searchResultsUpdater = self
        self.searchController.searchBar.barTintColor = UIColor(red: 170/255, green: 50/255, blue: 50/255, alpha: 1.0)
        self.searchController.searchBar.tintColor = UIColor.whiteColor()
        definesPresentationContext = true
        
        if CLLocationManager.locationServicesEnabled() {
            switch(CLLocationManager.authorizationStatus()) {
            case .NotDetermined, .Restricted, .Denied:
                locationManager.requestWhenInUseAuthorization()
            default:
               fetchJSON()
            }
        }
    }
    
    func fetchJSON(){
        let API_URL: String = "http://map.webservice.sharebike.com:8888/json/MapService/LiveStationData?APIKey=" +
        "3EFC0CF3-4E99-40E2-9E42-B95C2EDE6C3C&SystemID=citytrondheim"
        let myLocation = locationManager.location!
        Alamofire.request(.GET, API_URL).validate().responseJSON { response in
            switch response.result {
            case .Success:
                if let value = response.result.value {
                    let json = JSON(value)
                    let array = json["result"]["LiveStationData"].arrayValue
                    for place in array{
                        var online:Bool =  place["Online"].boolValue
                        let longitude: Double = place["Longitude"].doubleValue
                        let latitude: Double = place["Latitude"].doubleValue
                        let location = CLLocation(latitude: latitude, longitude: longitude)
                        let distance = Int((myLocation.distanceFromLocation(location)))
                        var adress = place["Address"].stringValue
                        let bikes = place["AvailableBikeCount"].intValue
                        let slots = place["AvailableSlotCount"].intValue
                        if(adress.containsString("[Offline]")){
                            online = false
                            adress = adress.componentsSeparatedByString(" ")[1]
                        }
                        let object = BikePlace(availableBikes: bikes,availableSlots: slots, adress: adress,online: online,location: location, distance: distance)
                        self.places.append(object)
                    }
                    self.fetchFavorites()
                    self.places.sortInPlace({$0.distance < $1.distance})
                    self.tableView.reloadData()
                    
                }
            case
            .Failure(let error):
                print(error)
            }
        }
        
    }
    
  
    func saveFavorites(){
        var tmp = ""
        for favorite in favorites{
            tmp = tmp + String(favorite.id) + ","
            print("faen")
        }
        NSUserDefaults.standardUserDefaults().setObject(tmp, forKey: "favorites")
    }
    
    
    func fetchFavorites(){
        var favoritesID : [Int] = []
        if( NSUserDefaults.standardUserDefaults().objectForKey("favorites") != nil) {
            let favString = NSUserDefaults.standardUserDefaults().objectForKey("favorites")! as! String
            let tmp = favString.characters.split{$0 == ","}.map(String.init)
            for string in tmp{
                favoritesID.append(Int(string)!)
            }
        }
        for place in places{
            if(favoritesID.contains(place.id)){
                favorites.append(place)
            }
        }
        favorites.sortInPlace({$0.distance < $1.distance})
    }
    
  
    // IBAction Methods
    
    @IBAction func mySegmentedControlPressed(sender: AnyObject) {
        if(mySegmentedControl.selectedSegmentIndex == 1){
            let addBarItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: #selector(TableViewController.performPopover))
            addBarItem.tintColor = UIColor.whiteColor()
            navigationItem.rightBarButtonItem = addBarItem
        }
        else{
            let searchBarItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Search, target: self, action: #selector(TableViewController.searchPressed))
            searchBarItem.tintColor = UIColor.whiteColor()
            navigationItem.rightBarButtonItem = searchBarItem
        }
        self.tableView.reloadData()
    }
    
    func searchPressed(){
        if self.tableView.tableHeaderView == self.searchController.searchBar{
            self.tableView.tableHeaderView = nil
        }
        else{
            self.presentViewController(searchController, animated: true, completion: nil)
        }
        
    }
    
    
    
    // TableView Methods
    
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if(mySegmentedControl.selectedSegmentIndex == 1){
            return true
        }
        return false
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getCurrentTableViewArray().count
    }
    
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let unFav = UITableViewRowAction(style: .Normal, title: "Fjern"){(
            action: UITableViewRowAction, indexPath: NSIndexPath!) -> Void in
            self.favorites.removeAtIndex(self.favorites.indexOf(self.favorites[indexPath.row])!)
            self.favorites.sortInPlace({$0.distance < $1.distance})
            self.tableView.reloadData()
            self.saveFavorites()
        }
        unFav.backgroundColor = UIColor(red: 234/255, green: 67/255, blue: 53/255, alpha: 1)
        return [unFav]
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        tableView.rowHeight = 51
        let cell:CustomCell = self.tableView.dequeueReusableCellWithIdentifier("myCell")! as! CustomCell
        let array: [BikePlace] = self.getCurrentTableViewArray()
        cell.id = array[indexPath.row].id
        cell.img.backgroundColor = getCellColor(array[indexPath.row])
        cell.accessoryType = UITableViewCellAccessoryType.None
        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor(red: 243/255, green: 243/255, blue: 243/255, alpha: 1.0)
        cell.selectedBackgroundView = bgColorView
        addExtraMarks(cell, place: array[indexPath.row])
        return cell
        
    }
    
    // TableView support methods
    
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        self.filteredPlaces =  self.places.filter {place -> Bool in
            if place.getDisplayString().lowercaseString.containsString(self.searchController.searchBar.text!.lowercaseString){
                return true
            }
            else{
                return false
            }
        }
        self.resultController.tableView.reloadData();
    }
    
    
    func refreshTable(){
        self.refreshControl?.beginRefreshing()
        self.places.removeAll()
        self.filteredPlaces.removeAll()
        self.favorites.removeAll()
        fetchJSON()
        self.tableView.reloadData()
        self.refreshController.endRefreshing()
    }
    
    
    
    func getCurrentTableViewArray()->[BikePlace]{
        if(mySegmentedControl.selectedSegmentIndex == 1){
            return self.favorites
        }
        if(filteredPlaces.count > 0){
            return self.filteredPlaces
        }
        else {
            return self.places
        }
        
    }
    
    
    func getCellColor(place:BikePlace) -> UIColor{
        if(place.availableBikes == 0){
            return UIColor(red: 234/255, green: 67/255, blue: 53/255, alpha: 1)
        }
        else if(place.availableSlots == 0){
            return UIColor.grayColor()
        }
        else if (place.availableBikes < 5){
            return UIColor(red: 251/255, green: 188/255, blue: 5/255, alpha: 1)
        }
        else{
            return UIColor(red: 52/255, green: 168/255, blue: 83/255, alpha: 1)
        }
    }
    
    func addExtraMarks(cell: CustomCell, place: BikePlace){
        let hour = NSCalendar.currentCalendar().component(.Hour, fromDate: NSDate())
        if hour < 6{
            cell.one.text = place.getDisplayString() + " [Stengt]"
        }
            
        else{
            cell.one.text = place.getDisplayString()
        }
        
        if(place.distance > 10000){
            cell.two.text = String(place.distance/1000) +
                " Kilometer"  + " - Stativer: " + String(place.availableSlots) +  " - Sykler: " + String(place.availableBikes)
        }
        else{
            cell.two.text = String(place.distance) +
                " Meter"  + " - Stativer: " + String(place.availableSlots) +  " - Sykler: " + String(place.availableBikes)
        }
        
    }
    
    // Transfer data between Views
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if(segue.identifier == "mySegue"){
            let cell = sender as? CustomCell
            let index = self.places.indexOf({$0.id == cell!.id})!
            let secondViewController = segue.destinationViewController as! MapViewController
            secondViewController.currentPlace.append(self.places[index])
            secondViewController.places = self.places
        }
            
        else{
            let secondViewController = segue.destinationViewController as! MapViewController
            secondViewController.places = self.places
        }
    }
    
    
    func performPopover(){
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("FavoritesViewController") as! UINavigationController
        let  destinationController = controller.topViewController as! FavoritesController
        destinationController.currentFavorites = self.favorites
        destinationController.places = self.places
        destinationController.favoritesCountStart = self.favorites.count
        destinationController.passDataBack = {[weak self]
            (data) in
            if self != nil {
                self!.favorites = data
                self!.saveFavorites()
                self!.tableView.reloadData()
            }
        }
        self.presentViewController(controller, animated: true, completion: nil)
    }
    
  
    
    
}
