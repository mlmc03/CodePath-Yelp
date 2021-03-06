//
//  BusinessesViewController.swift
//  Yelp
//
//  Created by Timothy Lee on 4/23/15.
//  Copyright (c) 2015 Timothy Lee. All rights reserved.
//

import UIKit
import KVNProgress
import MapKit

class BusinessesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, FiltersViewControllerDelegate, UISearchBarDelegate, UIScrollViewDelegate, MKMapViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    var mapView: MKMapView!
    
    var businesses = [Business]()
    var searchBar: UISearchBar!
    
    var isMoreDataLoading = false
    var searchActive = false
    var searchedBusinesses = [Business]()

    let segmentControl = UISegmentedControl()
    var segmentBarItem: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup mapView
        mapView = MKMapView()
        mapView.mapType = .standard
        mapView.frame = tableView.frame
        mapView.delegate = self
        view.addSubview(mapView)
        
        // setup tableView
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 120
        view.bringSubview(toFront: tableView)
        
        // setup searchBar
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.sizeToFit()
        navigationItem.titleView = searchBar
        
        // setup segment control for list/map view
        segmentControl.frame = CGRect(x: 0, y: 0, width: 90, height: 30.0)
        segmentControl.insertSegment(with: UIImage(named: "list"), at: 0, animated: true)
        segmentControl.insertSegment(with: UIImage(named: "map"), at: 1, animated: true)
        segmentControl.selectedSegmentIndex = 0
        segmentControl.addTarget(self, action: #selector(segmentControlAction(segmentControl:)), for: .valueChanged)
        segmentBarItem = UIBarButtonItem(customView: segmentControl)
        self.navigationItem.leftBarButtonItem = segmentBarItem
        
        // fetchData
        fetchData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let centerLocation = CLLocation(latitude: 37.7838, longitude: -122.3875)
        goTo(location: centerLocation)
    }

    // app logic
    func fetchData() {
        
        // display activity indicator
        KVNProgress.show()
        
        Business.searchWithTerm(term: "Restaurants", offset: businesses.count, completion: { (businesses: [Business]?, error: Error?) -> Void in
            
            self.businesses.append(contentsOf: businesses!)
            self.tableView.reloadData()
            self.isMoreDataLoading = false
            
            self.mapView.addAnnotations(businesses!)
            
            // hide activity indicator
            KVNProgress.dismiss()
        })
    }
    
    func goTo(location: CLLocation) {
        let span = MKCoordinateSpanMake(0.025, 0.025)
        let region = MKCoordinateRegionMake(location.coordinate, span)
        let regionThatFits = mapView.regionThatFits(region)
        mapView.setRegion(regionThatFits, animated: true)
    }
    
    // Mark: – FiltersViewControllerDelegate
    func filtersViewController(filtersViewController: FiltersViewController, didUpdateFilters filters: [String : AnyObject]) {
        
        // display activity indicator
        KVNProgress.show()
        
        let categories = filters["categories"] as? [String]
        let sort = filters["sort"] as? Int
        let deals = filters["deals"] as? Bool
        let distance = filters["distance"] as? Int
        
        Business.searchWithTerm(term: "Restaurants", sort: sort.map { YelpSortMode(rawValue: $0) }!, categories: categories, deals: deals, radius: distance, offset: 0, completion: {
            (businesses: [Business]?, error: Error?) -> Void in
            
            // remove businesses and replace with new data
            self.mapView.removeAnnotations(self.businesses)
            self.mapView.addAnnotations(businesses!)
            
            self.businesses = businesses!
            self.tableView.reloadData()

            // hide activity indicator
            KVNProgress.dismiss()
        })
    }
    
    // Mark: - MKMapViewDelegate
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let annotation = annotation as? Business {
            let identifier = "pin"
            var view: MKPinAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView {
                dequeuedView.annotation = annotation
                view = dequeuedView
            } else {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
                view.calloutOffset = CGPoint(x: -5, y: 5)
                view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure) as UIView
            }
            return view
        }
        return nil
    
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        let annotation = view.annotation as? Business
        
        
    }
    
    // Mark: - ScrollView
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if !isMoreDataLoading {
            // Calculate the position of one screen length before the bottom of the results
            let scrollViewContentHeight = tableView.contentSize.height
            let scrollOffsetThreshold = scrollViewContentHeight - tableView.bounds.size.height
            
            // When the user has scrolled past the threshold, start requesting
            if(scrollView.contentOffset.y > scrollOffsetThreshold && tableView.isDragging) {
                isMoreDataLoading = true
                
                // ... Code to load more results ...
                self.fetchData()
            }
        }
    }

    // Mark: - Segment Control
    func segmentControlAction(segmentControl: UISegmentedControl) {
        
        var toView = UIView()
        var fromView = UIView()
        
        if segmentControl.selectedSegmentIndex == 0 {
            fromView = self.mapView
            toView = self.tableView
        }
        else {
            fromView = self.tableView
            toView = self.mapView
        }
        
        UIView.transition(from: fromView, to: toView, duration: 0.25, options: UIViewAnimationOptions.showHideTransitionViews, completion: nil)
    }
    
    // Mark: – TableViewControllerDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if searchActive {
            return searchedBusinesses.count
        }
        else if !searchActive {
            return businesses.count
        }

        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "businessCell", for: indexPath) as! BusinessCell
        
        if searchActive {
            cell.business = searchedBusinesses[indexPath.row]
        }
        else {
            cell.business = businesses[indexPath.row]
        }
        
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showFilters" {
            let navigationController = segue.destination as! UINavigationController
            let filtersViewController = navigationController.topViewController as! FiltersViewController
            
            filtersViewController.delegate = self
        }
        else if segue.identifier == "showBusinessDetail" {
            let detailViewController = segue.destination as! DetailViewController

            let cell = sender as! BusinessCell
            let business = cell.business
            detailViewController.business = business
        }
    }
    
    // Mark: – UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchedBusinesses = businesses.filter({ (business) -> Bool in
            var temp = NSString()
            
            if let name = business.title {
                temp = name as NSString
                
            }
            let range = temp.range(of: searchText, options: .caseInsensitive)
            return range.location != NSNotFound
        })
        
        if searchedBusinesses.count == 0 {
            searchActive = false
            self.mapView.removeAnnotations(self.mapView.annotations)
            self.mapView.addAnnotations(self.businesses)
        }
        else {
            searchActive = true
            let annotationsToRemove = self.mapView.annotations.filter { !searchedBusinesses.contains($0 as! Business) }
            self.mapView.removeAnnotations(annotationsToRemove)
        }
        self.tableView.reloadData()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchActive = true;
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }

}
