import SwiftUI
import simd

enum SkyObject: Hashable {
    case star(Int)
    case body(String)
    case dso(String)
    case constellation(String)
}

struct ObjectInfo {
    var title: String
    var subtitle: String
    var mag: Double?
    var enu: V3
    var vec: V3?          // fixed equatorial vector (nil for solar-system bodies)
    var body: SkyBody?
}

@MainActor
final class SkyModel: ObservableObject {
    // Camera
    @Published var az: Double = 180 * d2r
    @Published var alt: Double = 38 * d2r
    @Published var fov: Double = 75 * d2r
    @Published var useGyro = true
    @Published var showPaywall = false

    // Time
    @Published var clock = Date()
    @Published var timeOffset: TimeInterval = 0
    @Published var playing = false
    private var timer: Timer?

    // Selection
    @Published var selected: SkyObject?
    @Published var target: SkyObject?

    // Settings
    @AppStorage("zen.constellations") var showConstellations = true
    @AppStorage("zen.conNames") var showConstellationNames = true
    @AppStorage("zen.labels") var showLabels = true
    @AppStorage("zen.dso") var showDeepSky = true
    @AppStorage("zen.grid") var showGrid = false
    @AppStorage("zen.milky") var showMilkyWay = true
    @AppStorage("zen.daystars") var starsInDay = true
    @AppStorage("zen.red") var redMode = false
    @AppStorage("zen.meteors") var showMeteors = true

    let data = SkyData.shared

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private var lastTick = Date()
    private var sinceClock = 0.0
    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        if playing { timeOffset += dt * 3600 * 2; clock = now }      // 2 hours per second
        else {
            sinceClock += dt
            if sinceClock >= 2 { sinceClock = 0; clock = now }
        }
    }

    var date: Date { clock.addingTimeInterval(timeOffset) }
    var isLive: Bool { abs(timeOffset) < 1 && !playing }

    func goNow() { timeOffset = 0; playing = false; clock = Date() }

    // MARK: Tweening (camera moves)

    private var tweenTimer: Timer?
    func tween(duration: Double, ease: @escaping (Double) -> Double = { 1 - pow(1 - $0, 3) }, _ step: @escaping (Double) -> Void) {
        tweenTimer?.invalidate()
        let start = Date()
        tweenTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] t in
            let k = min(1, Date().timeIntervalSince(start) / duration)
            step(ease(k))
            if k >= 1 { t.invalidate(); self?.tweenTimer = nil }
        }
    }

    /// Smoothly turn the camera toward a direction (shortest way round in azimuth).
    func slew(to enu: V3, duration: Double = 0.9) {
        let (a1, z1) = Astro.altAz(enu)
        let a0 = alt, z0 = az
        var dz = z1 - z0
        while dz > .pi { dz -= 2 * .pi }
        while dz < -.pi { dz += 2 * .pi }
        let ta = max(-85 * d2r, min(85 * d2r, a1))
        tween(duration: duration, ease: { $0 < 0.5 ? 4 * $0 * $0 * $0 : 1 - pow(-2 * $0 + 2, 3) / 2 }) { [weak self] k in
            self?.az = norm2pi(z0 + dz * k); self?.alt = a0 + (ta - a0) * k
        }
    }

    func animateFov(to target: Double, duration: Double = 0.55) {
        let f0 = fov
        tween(duration: duration) { [weak self] k in self?.fov = f0 + (target - f0) * k }
    }

    /// Opening move: start zoomed out and ease into the normal view.
    func introZoom() {
        let target = fov
        fov = 125 * d2r
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.animateFov(to: target, duration: 1.8) }
    }

    /// Latest gyro forward vector, kept by the sky view so slews can start from the live camera.
    var gyroForward: V3?

    // MARK: Resolving objects

    func info(_ obj: SkyObject, observer: Observer, at date: Date) -> ObjectInfo? {
        let jd = Astro.jd(date)
        let frame = Astro.Frame(lst: Astro.lst(jd: jd, lon: observer.lon), lat: observer.lat * d2r)
        switch obj {
        case .star(let i):
            guard i < data.stars.count else { return nil }
            let s = data.stars[i]
            return ObjectInfo(title: s.name.isEmpty ? "Star" : s.name, subtitle: "Star · " + spectral(Double(s.bv)),
                              mag: Double(s.mag), enu: frame.enu(s.vec), vec: s.vec, body: nil)
        case .body(let id):
            guard let b = Astro.allBodies(jd: jd).first(where: { $0.id == id }) else { return nil }
            var sub = b.kind == .planet ? "Planet" : (b.kind == .sun ? "Our star" : "Moon")
            if b.kind == .moon { sub = "\(Astro.phaseName(elong: b.elong)) · \(Int((b.illum * 100).rounded()))% lit" }
            return ObjectInfo(title: b.name, subtitle: sub, mag: b.mag, enu: Astro.enu(of: b, jd: jd, observer: observer), vec: nil, body: b)
        case .dso(let id):
            guard let d = data.deepSky.first(where: { $0.id == id }) else { return nil }
            return ObjectInfo(title: d.name, subtitle: "\(d.kind) · \(d.id)", mag: d.mag, enu: frame.enu(d.vec), vec: d.vec, body: nil)
        case .constellation(let id):
            guard let c = data.constellations.first(where: { $0.id == id }) else { return nil }
            return ObjectInfo(title: c.name, subtitle: "Constellation", mag: nil, enu: frame.enu(c.center), vec: c.center, body: nil)
        }
    }

    func bodies(at date: Date) -> [SkyBody] { Astro.allBodies(jd: Astro.jd(date)) }

    func lookAt(_ enu: V3) {
        if useGyro, let f = gyroForward { let (a, z) = Astro.altAz(f); alt = a; az = z }
        useGyro = false
        slew(to: enu)
    }

    func select(_ obj: SkyObject, observer: Observer, slew: Bool) {
        selected = obj
        if slew, let i = info(obj, observer: observer, at: date) { lookAt(i.enu) }
    }

    func spectral(_ bv: Double) -> String {
        switch bv {
        case ..<0.0: return "blue-white"
        case ..<0.3: return "white"
        case ..<0.6: return "yellow-white"
        case ..<1.0: return "yellow"
        case ..<1.4: return "orange"
        default: return "red"
        }
    }
}

func compassName(_ az: Double) -> String {
    let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
    let i = Int((norm2pi(az) / (2 * .pi) * 16).rounded()) % 16
    return names[i]
}

let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "h:mm a"; return f }()
let dayTimeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE h:mm a"; return f }()
let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f }()
let fullFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, h:mm a"; return f }()
