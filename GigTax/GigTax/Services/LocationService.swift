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
    private(set) var isShiftActive = false
    private(set) var shiftStartDate: Date?
    private(set) var isShiftPaused = false

    // MARK: - Config (set by ContentView)
    var cityMPG: Double = 28
    var highwayMPG: Double = 36
    var gasPrice: Double = 3.45
    private(set) var gasPriceStatus: EIAGasPrice?
    var modelContext: ModelContext?
    var vehicle: Vehicle?
    var driverProfile: DriverProfile?

    /// Was hardcoded to business for every auto-detected trip regardless of
    /// real intent. Restored on launch from DriverProfile so a shift spanning
    /// app relaunch/backgrounding isn't silently dropped.
    func restoreShiftState(active: Bool, startDate: Date?, paused: Bool) {
        isShiftActive = active
        shiftStartDate = active ? startDate : nil
        isShiftPaused = active && paused
    }

    func startShift() {
        isShiftActive = true
        shiftStartDate = .now
        isShiftPaused = false
        persistShiftState()
    }

    /// Doesn't retroactively re-tag a trip already in progress — its
    /// business/personal tag was already captured the instant it began.
    func endShift() {
        isShiftActive = false
        shiftStartDate = nil
        isShiftPaused = false
        persistShiftState()
    }

    /// A break within an active shift (lunch, waiting out a slow spell) —
    /// unlike endShift(), this keeps shiftStartDate untouched so the shift
    /// is still the same continuous session once resumed. Any trip that
    /// starts while paused is tagged personal, same as if no shift were
    /// active at all.
    func pauseShift() {
        guard isShiftActive else { return }
        isShiftPaused = true
        persistShiftState()
    }

    func resumeShift() {
        guard isShiftActive else { return }
        isShiftPaused = false
        persistShiftState()
    }

    private func persistShiftState() {
        driverProfile?.isShiftActive = isShiftActive
        driverProfile?.shiftStartDate = shiftStartDate
        driverProfile?.isShiftPaused = isShiftPaused
        try? modelContext?.save()
    }

    /// Was a flat $3.45 fallback for every driver in every state until this
    /// was actually wired up — see EIAService for the fix's real substance.
    func refreshGasPrice(state: String, apiKey: String?) async {
        let result = await EIAService.shared.fetchGasPrice(state: state, apiKey: apiKey)
        gasPrice = result.pricePerGallon
        gasPriceStatus = result
    }

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
    // Captured once, at the moment a trip starts, so ending a shift mid-trip
    // never retroactively re-tags a trip already correctly classified.
    private var currentTripIsBusiness = false

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

    // MARK: - Stop-zone geofence
    // Significant-location-change alone is documented by Apple as slow —
    // often minutes — to notice the device has started moving again after
    // being still, which meant real driving between stops could go entirely
    // untracked. A geofence around wherever a trip actually ended delivers a
    // near-instant exit callback the moment the driver actually leaves, so
    // it's used as the primary "wake up and re-evaluate" trigger, with
    // significant-change kept running in parallel as a fallback.
    private static let stopZoneIdentifier = "gigtax.stopZone"
    private let stopZoneRadius: CLLocationDistance = 150

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

    /// - Parameter anchor: the last known location, if any — used to arm a
    ///   stop-zone geofence there so leaving it wakes tracking back up almost
    ///   immediately, rather than waiting on significant-change alone.
    private func enterLowPowerMode(anchor: CLLocation? = nil) {
        powerMode = .lowPower
        evaluationTask?.cancel()
        manager.stopUpdatingLocation()
        disarmStopZone()
        if let anchor {
            armStopZone(around: anchor)
        }
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        } else {
            enterActiveMode(accuracy: kCLLocationAccuracyHundredMeters, distanceFilter: 100)
        }
    }

    private func enterActiveMode(accuracy: CLLocationAccuracy, distanceFilter: CLLocationDistance) {
        manager.stopMonitoringSignificantLocationChanges()
        disarmStopZone()
        manager.desiredAccuracy = accuracy
        manager.distanceFilter  = distanceFilter
        manager.startUpdatingLocation()
    }

    private func armStopZone(around loc: CLLocation) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(center: loc.coordinate, radius: stopZoneRadius, identifier: Self.stopZoneIdentifier)
        region.notifyOnEntry = false
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
    }

    private func disarmStopZone() {
        for region in manager.monitoredRegions where region.identifier == Self.stopZoneIdentifier {
            manager.stopMonitoring(for: region)
        }
    }

    /// Region-exit fired first (the common, fast case) — jump straight to
    /// evaluating a possible trip start, same as the first location update
    /// would have done under the old significant-change-only flow.
    private func handleStopZoneExit() {
        guard powerMode == .lowPower, !isTracking else { return }
        disarmStopZone()
        powerMode = .evaluating
        enterActiveMode(accuracy: kCLLocationAccuracyHundredMeters, distanceFilter: 50)
        scheduleEvaluationTimeout()
    }

    private func scheduleEvaluationTimeout() {
        evaluationTask?.cancel()
        let window = evaluationWindow
        evaluationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(window))
            guard let self, !Task.isCancelled else { return }
            if self.powerMode == .evaluating && !self.isTracking {
                self.enterLowPowerMode(anchor: self.lastLoc)
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
        currentTripIsBusiness = isShiftActive && !isShiftPaused
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
            enterLowPowerMode(anchor: loc)
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
        // Deadhead miles between fares while a shift is active still count as
        // business; anything driven outside a shift (grocery run, drive home)
        // is personal by default instead of the old hardcoded "always business".
        trip.tripTypeRaw          = (currentTripIsBusiness ? TripType.business : TripType.personal).rawValue

        modelContext?.insert(trip)
        if let fuelExpense = Expense.fuelExpense(for: trip) {
            modelContext?.insert(fuelExpense)
        }
        try? modelContext?.save()

        if let vehicle, let modelContext {
            MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: modelContext)
        }

        resetState()
        enterLowPowerMode(anchor: loc)
    }

    private func resetState() {
        isTracking = false; currentTripStart = nil; currentTripMiles = 0
        tripStartLoc = nil; lastLoc = nil
        cityMilesAcc = 0; hwyMilesAcc = 0; totalMilesAcc = 0
        movingStart = nil; stationaryStart = nil
        currentTripIsBusiness = false
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

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == LocationService.stopZoneIdentifier else { return }
        Task { @MainActor [weak self] in self?.handleStopZoneExit() }
    }

    // No explicit handling needed — significant-location-change monitoring
    // is already running in parallel as the fallback wake-up path.
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {}
}
