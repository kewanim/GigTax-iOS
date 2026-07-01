import Foundation
import CoreLocation
import SwiftData

@MainActor
@Observable
final class LocationService: NSObject {

    // MARK: - Observable state
    private(set) var isTracking = false
    private(set) var currentTripMiles: Double = 0
    private(set) var currentTripStart: Date?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Config (set by ContentView)
    var cityMPG: Double = 28
    var highwayMPG: Double = 36
    var gasPrice: Double = 3.45
    var modelContext: ModelContext?

    // MARK: - Private
    private let manager = CLLocationManager()
    private var tripStartLoc: CLLocation?
    private var lastLoc: CLLocation?
    private var cityMilesAcc: Double = 0
    private var hwyMilesAcc: Double = 0
    private var totalMilesAcc: Double = 0
    private var movingStart: Date?
    private var stationaryStart: Date?

    // ~5 mph and ~2 mph in m/s
    private let startSpeedMS: Double = 2.2
    private let stopSpeedMS: Double  = 0.9
    private let startDwell: TimeInterval = 30    // 30 s moving → trip starts
    private let stopDwell:  TimeInterval = 180   // 3 min stopped → trip ends

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func startMonitoring() {
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        manager.startUpdatingLocation()
    }

    // MARK: - Trip lifecycle

    private func process(_ loc: CLLocation) {
        let speed = max(0, loc.speed)

        if !isTracking {
            if speed > startSpeedMS {
                if movingStart == nil { movingStart = Date() }
                if let ms = movingStart, Date().timeIntervalSince(ms) >= startDwell {
                    beginTrip(at: loc)
                }
            } else {
                movingStart = nil
            }
        } else {
            if let last = lastLoc {
                let miles = loc.distance(from: last) / 1609.34
                let mph   = speed * 3600 / 1609.34
                if mph >= 45 { hwyMilesAcc += miles } else { cityMilesAcc += miles }
                totalMilesAcc += miles
                currentTripMiles = totalMilesAcc
            }
            if speed < stopSpeedMS {
                if stationaryStart == nil { stationaryStart = Date() }
                if let ss = stationaryStart, Date().timeIntervalSince(ss) >= stopDwell {
                    endTrip(at: loc)
                }
            } else {
                stationaryStart = nil
            }
        }
        lastLoc = loc
    }

    private func beginTrip(at loc: CLLocation) {
        isTracking = true
        currentTripStart = Date()
        tripStartLoc = loc
        cityMilesAcc = 0; hwyMilesAcc = 0; totalMilesAcc = 0
        currentTripMiles = 0; stationaryStart = nil
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter  = 10
    }

    private func endTrip(at loc: CLLocation) {
        guard let start = currentTripStart, totalMilesAcc > 0.1 else {
            resetState(); return
        }
        let gallons  = (cityMPG  > 0 ? cityMilesAcc  / cityMPG  : 0)
                     + (highwayMPG > 0 ? hwyMilesAcc / highwayMPG : 0)
        let duration = Date().timeIntervalSince(start)

        let trip = Trip(
            startDate:      start,
            startLatitude:  tripStartLoc?.coordinate.latitude  ?? 0,
            startLongitude: tripStartLoc?.coordinate.longitude ?? 0
        )
        trip.endDate              = Date()
        trip.endLatitude          = loc.coordinate.latitude
        trip.endLongitude         = loc.coordinate.longitude
        trip.distanceMiles        = totalMilesAcc
        trip.cityMiles            = cityMilesAcc
        trip.highwayMiles         = hwyMilesAcc
        trip.durationSeconds      = duration
        trip.estimatedFuelGallons = gallons
        trip.estimatedFuelCost    = gallons * gasPrice
        trip.tripTypeRaw          = TripType.business.rawValue

        modelContext?.insert(trip)
        try? modelContext?.save()

        resetState()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter  = 50
    }

    private func resetState() {
        isTracking = false; currentTripStart = nil; currentTripMiles = 0
        tripStartLoc = nil; lastLoc = nil
        cityMilesAcc = 0; hwyMilesAcc = 0; totalMilesAcc = 0
        movingStart = nil; stationaryStart = nil
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor [weak self] in self?.process(loc) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in self?.authorizationStatus = status }
    }
}
