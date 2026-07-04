import Foundation
import CoreLocation
import SwiftData
import ActivityKit

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
    var vehicle: Vehicle?

    // MARK: - Private
    private let manager = CLLocationManager()
    private var tripStartLoc: CLLocation?
    private var lastLoc: CLLocation?
    private var cityMilesAcc: Double = 0
    private var hwyMilesAcc: Double = 0
    private var totalMilesAcc: Double = 0
    private var movingStart: Date?
    private var stationaryStart: Date?
    private var tripActivity: Activity<TripActivityAttributes>?

    // ~5 mph and ~2 mph in m/s
    private let startSpeedMS: Double = 2.2
    private let stopSpeedMS: Double  = 0.9
    private let startDwell: TimeInterval = 30    // 30 s moving → trip starts
    private let stopDwell:  TimeInterval = 180   // 3 min stopped → trip ends

    // MARK: - Power mode
    // Idle drivers spend most of the day parked. Significant-change monitoring
    // (~500 m / few-minute resolution, very low power) is used until a wake-up
    // suggests real movement, at which point we switch to fine-grained updates
    // to evaluate a possible trip. If nothing materializes, we drop back down.
    private enum PowerMode { case lowPower, evaluating, active }
    private var powerMode: PowerMode = .lowPower
    private var evaluationTask: Task<Void, Never>?
    private let evaluationWindow: TimeInterval = 120
    private let staleTrackingInterval: TimeInterval = 3600

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func startMonitoring() {
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        enterLowPowerMode()
    }

    /// Runs on a periodic BGProcessingTask: persists any pending SwiftData
    /// changes and finalizes a trip that's gone stale (e.g. the app was
    /// suspended mid-trip) so accumulated mileage isn't lost.
    func performBackgroundMaintenance() {
        try? modelContext?.save()

        if isTracking, let last = lastLoc,
           Date().timeIntervalSince(last.timestamp) > staleTrackingInterval {
            endTrip(at: last)
        }

        if let vehicle, let modelContext {
            MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: modelContext)
        }
    }

    // MARK: - Power mode transitions

    private func enterLowPowerMode() {
        powerMode = .lowPower
        evaluationTask?.cancel()
        manager.stopUpdatingLocation()
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        } else {
            enterActiveMode(accuracy: kCLLocationAccuracyHundredMeters, distanceFilter: 100)
        }
    }

    private func enterActiveMode(accuracy: CLLocationAccuracy, distanceFilter: CLLocationDistance) {
        manager.stopMonitoringSignificantLocationChanges()
        manager.desiredAccuracy = accuracy
        manager.distanceFilter  = distanceFilter
        manager.startUpdatingLocation()
    }

    private func scheduleEvaluationTimeout() {
        evaluationTask?.cancel()
        let window = evaluationWindow
        evaluationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(window))
            guard let self, !Task.isCancelled else { return }
            if self.powerMode == .evaluating && !self.isTracking {
                self.enterLowPowerMode()
            }
        }
    }

    // MARK: - Trip lifecycle

    func process(_ loc: CLLocation) {
        let speed = max(0, loc.speed)

        if !isTracking {
            if powerMode == .lowPower {
                powerMode = .evaluating
                enterActiveMode(accuracy: kCLLocationAccuracyHundredMeters, distanceFilter: 50)
                scheduleEvaluationTimeout()
            }

            if speed > startSpeedMS {
                if movingStart == nil { movingStart = loc.timestamp }
                if let ms = movingStart, loc.timestamp.timeIntervalSince(ms) >= startDwell {
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
                updateTripActivity()
            }
            if speed < stopSpeedMS {
                if stationaryStart == nil { stationaryStart = loc.timestamp }
                if let ss = stationaryStart, loc.timestamp.timeIntervalSince(ss) >= stopDwell {
                    endTrip(at: loc)
                }
            } else {
                stationaryStart = nil
            }
        }
        lastLoc = loc
    }

    private func beginTrip(at loc: CLLocation) {
        evaluationTask?.cancel()
        powerMode = .active
        isTracking = true
        currentTripStart = loc.timestamp
        tripStartLoc = loc
        cityMilesAcc = 0; hwyMilesAcc = 0; totalMilesAcc = 0
        currentTripMiles = 0; stationaryStart = nil
        enterActiveMode(accuracy: kCLLocationAccuracyBest, distanceFilter: 10)
        startTripActivity(at: loc.timestamp)
    }

    /// Skips real ActivityKit calls under XCTest — LocationServiceTests
    /// synthesizes many location updates per test, and each one calling into
    /// the live ActivityKit/system service added ~0.6s per test versus the
    /// prior ~0.15s. Same reasoning as the CloudKit test-isolation fix in
    /// GigTaxModelContainer: tests shouldn't depend on real system services.
    private var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func startTripActivity(at startDate: Date) {
        guard !isRunningUnderTest, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TripActivityAttributes(startDate: startDate)
        let content = TripActivityAttributes.ContentState(miles: 0, estimatedFuelCost: 0)
        tripActivity = try? Activity.request(attributes: attributes, content: .init(state: content, staleDate: nil))
    }

    private func updateTripActivity() {
        guard let tripActivity else { return }
        let gallons = (cityMPG > 0 ? cityMilesAcc / cityMPG : 0) + (highwayMPG > 0 ? hwyMilesAcc / highwayMPG : 0)
        let content = TripActivityAttributes.ContentState(miles: totalMilesAcc, estimatedFuelCost: gallons * gasPrice)
        Task { await tripActivity.update(.init(state: content, staleDate: nil)) }
    }

    private func endTripActivity() {
        guard let tripActivity else { return }
        Task { await tripActivity.end(nil, dismissalPolicy: .immediate) }
        self.tripActivity = nil
    }

    private func endTrip(at loc: CLLocation) {
        endTripActivity()
        guard let start = currentTripStart, totalMilesAcc > 0.1 else {
            resetState()
            enterLowPowerMode()
            return
        }
        let gallons  = (cityMPG  > 0 ? cityMilesAcc  / cityMPG  : 0)
                     + (highwayMPG > 0 ? hwyMilesAcc / highwayMPG : 0)
        let duration = loc.timestamp.timeIntervalSince(start)

        let trip = Trip(
            startDate:      start,
            startLatitude:  tripStartLoc?.coordinate.latitude  ?? 0,
            startLongitude: tripStartLoc?.coordinate.longitude ?? 0
        )
        trip.endDate              = loc.timestamp
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
        if let fuelExpense = Expense.fuelExpense(for: trip) {
            modelContext?.insert(fuelExpense)
        }
        try? modelContext?.save()

        if let vehicle, let modelContext {
            MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: modelContext)
        }

        resetState()
        enterLowPowerMode()
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
