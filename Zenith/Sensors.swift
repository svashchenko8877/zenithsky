import Foundation
import CoreLocation
import CoreMotion
import SwiftUI

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var observer: Observer
    @Published var authorized = false
    @Published var denied = false
    private let manager = CLLocationManager()

    override init() {
        let d = UserDefaults.standard
        if d.object(forKey: "zen.lat") != nil {
            observer = Observer(lat: d.double(forKey: "zen.lat"), lon: d.double(forKey: "zen.lon"), name: d.string(forKey: "zen.place") ?? "Last location")
        } else {
            observer = .fallback
        }
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 5_000
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: authorized = true; manager.startUpdatingLocation()
        default: denied = true
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            if s == .authorizedWhenInUse || s == .authorizedAlways { self.authorized = true; self.denied = false; manager.startUpdatingLocation() }
            else if s == .denied || s == .restricted { self.denied = true }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.observer = Observer(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude, name: self.observer.name)
            let d = UserDefaults.standard
            d.set(loc.coordinate.latitude, forKey: "zen.lat"); d.set(loc.coordinate.longitude, forKey: "zen.lon")
            CLGeocoder().reverseGeocodeLocation(loc) { places, _ in
                guard let p = places?.first else { return }
                let name = p.locality ?? p.administrativeArea ?? p.country ?? "Current location"
                Task { @MainActor in
                    self.observer.name = name
                    UserDefaults.standard.set(name, forKey: "zen.place")
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// Device attitude -> camera basis in (east, north, up).
struct DeviceBasis {
    var right: V3
    var up: V3
    var forward: V3
}

@MainActor
final class MotionProvider: ObservableObject {
    @Published var basis: DeviceBasis?
    @Published var available = false
    private let mm = CMMotionManager()

    init() { available = mm.isDeviceMotionAvailable }

    func start() {
        guard mm.isDeviceMotionAvailable, !mm.isDeviceMotionActive else { return }
        mm.deviceMotionUpdateInterval = 1.0 / 30
        mm.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: .main) { [weak self] motion, _ in
            guard let m = motion?.attitude.rotationMatrix else { return }
            // Reference frame: x north, y west, z up. Device axes in the reference frame are the rows of R.
            func enu(_ a: Double, _ b: Double, _ c: Double) -> V3 { V3(-b, a, c) }
            let right = enu(m.m11, m.m12, m.m13)
            let up = enu(m.m21, m.m22, m.m23)
            let fwd = enu(-m.m31, -m.m32, -m.m33)
            self?.basis = DeviceBasis(right: right, up: up, forward: fwd)
        }
    }

    func stop() { mm.stopDeviceMotionUpdates() }
}
