import Foundation
import simd

let d2r = Double.pi / 180
let r2d = 180 / Double.pi

func norm360(_ x: Double) -> Double { let r = x.truncatingRemainder(dividingBy: 360); return r < 0 ? r + 360 : r }
func norm2pi(_ x: Double) -> Double { let t = 2 * Double.pi; let r = x.truncatingRemainder(dividingBy: t); return r < 0 ? r + t : r }

typealias V3 = SIMD3<Double>

struct Eq { var ra: Double; var dec: Double }   // radians

struct Observer: Equatable {
    var lat: Double       // degrees
    var lon: Double       // degrees, east positive
    var name: String
    static let fallback = Observer(lat: 43.65, lon: -79.38, name: "Toronto")
}

enum BodyKind { case sun, moon, planet }

struct SkyBody: Identifiable {
    let id: String
    let name: String
    let kind: BodyKind
    var eq: Eq
    var mag: Double
    var dist: Double            // AU (Moon: Earth radii)
    var illum: Double = 1       // illuminated fraction
    var elong: Double = 0       // degrees from Sun
    var moonDist: Double = 0    // Earth radii (Moon only)
}

enum Planet: Int, CaseIterable { case mercury, venus, mars, jupiter, saturn, uranus, neptune
    var name: String { ["Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"][rawValue] }
}

struct RiseSet {
    var rise: Date?
    var set: Date?
    var transit: Date?
    var maxAlt: Double          // degrees within window
    var upNow: Bool
}

enum Astro {
    static func jd(_ date: Date) -> Double { date.timeIntervalSince1970 / 86400 + 2440587.5 }
    static func date(jd: Double) -> Date { Date(timeIntervalSince1970: (jd - 2440587.5) * 86400) }
    /// Schlyter day number (days since 1999 Dec 31.0 TT)
    static func dayNumber(_ jd: Double) -> Double { jd - 2451543.5 }

    /// Local sidereal time in radians.
    static func lst(jd: Double, lon: Double) -> Double {
        norm2pi(norm360(280.46061837 + 360.98564736629 * (jd - 2451545.0) + lon) * d2r)
    }

    static func eclipticObliquity(_ d: Double) -> Double { (23.4393 - 3.563e-7 * d) * d2r }

    // MARK: Coordinate transforms

    static func eqVector(_ eq: Eq) -> V3 {
        V3(cos(eq.dec) * cos(eq.ra), cos(eq.dec) * sin(eq.ra), sin(eq.dec))
    }

    /// Rotation terms for a given sidereal time and latitude (radians).
    struct Frame {
        let cl: Double, sl: Double, cphi: Double, sphi: Double
        init(lst: Double, lat: Double) { cl = cos(lst); sl = sin(lst); cphi = cos(lat); sphi = sin(lat) }
        /// Equatorial unit vector -> (east, north, up).
        @inline(__always) func enu(_ v: V3) -> V3 {
            let a = cl * v.x + sl * v.y
            let b = sl * v.x - cl * v.y
            return V3(-b, v.z * cphi - a * sphi, v.z * sphi + a * cphi)
        }
    }

    static func altAz(_ enu: V3) -> (alt: Double, az: Double) {
        (asin(max(-1, min(1, enu.z))), norm2pi(atan2(enu.x, enu.y)))
    }

    static func enuVector(alt: Double, az: Double) -> V3 { V3(cos(alt) * sin(az), cos(alt) * cos(az), sin(alt)) }

    /// J2000 -> mean equator of date (small-angle precession, good to ~1 arcmin for decades).
    static func precess(ra: Double, dec: Double, years: Double) -> Eq {
        let dra = (3.075 + 1.336 * sin(ra) * tan(dec)) * years / 3600 * 15 * d2r
        let ddec = 20.04 * cos(ra) * years / 3600 * d2r
        return Eq(ra: norm2pi(ra + dra), dec: dec + ddec)
    }

    // MARK: Kepler

    private static func kepler(M: Double, e: Double) -> Double {
        var E = M + e * r2d * sin(M * d2r) * (1 + e * cos(M * d2r))
        for _ in 0..<8 {
            let dE = (E - e * r2d * sin(E * d2r) - M) / (1 - e * cos(E * d2r))
            E -= dE
            if abs(dE) < 1e-7 { break }
        }
        return E
    }

    // MARK: Sun

    struct SunPos { var lon: Double; var r: Double; var M: Double; var w: Double }   // degrees, AU

    static func sun(d: Double) -> SunPos {
        let w = 282.9404 + 4.70935e-5 * d
        let e = 0.016709 - 1.151e-9 * d
        let M = norm360(356.0470 + 0.9856002585 * d)
        let E = kepler(M: M, e: e)
        let xv = cos(E * d2r) - e
        let yv = sqrt(1 - e * e) * sin(E * d2r)
        let v = atan2(yv, xv) * r2d
        let r = hypot(xv, yv)
        return SunPos(lon: norm360(v + w), r: r, M: M, w: w)
    }

    static func eclToEq(x: Double, y: Double, z: Double, d: Double) -> Eq {
        let ecl = eclipticObliquity(d)
        let ye = y * cos(ecl) - z * sin(ecl)
        let ze = y * sin(ecl) + z * cos(ecl)
        return Eq(ra: norm2pi(atan2(ye, x)), dec: atan2(ze, hypot(x, ye)))
    }

    static func sunBody(jd: Double) -> SkyBody {
        let d = dayNumber(jd)
        let s = sun(d: d)
        let eq = eclToEq(x: s.r * cos(s.lon * d2r), y: s.r * sin(s.lon * d2r), z: 0, d: d)
        return SkyBody(id: "sun", name: "Sun", kind: .sun, eq: eq, mag: -26.7, dist: s.r)
    }

    // MARK: Moon

    struct MoonPos { var lon: Double; var lat: Double; var r: Double }   // degrees, Earth radii

    static func moon(d: Double) -> MoonPos {
        let N = norm360(125.1228 - 0.0529538083 * d)
        let i = 5.1454
        let w = norm360(318.0634 + 0.1643573223 * d)
        let a = 60.2666
        let e = 0.0549
        let M = norm360(115.3654 + 13.0649929509 * d)
        let E = kepler(M: M, e: e)
        let xv = a * (cos(E * d2r) - e)
        let yv = a * sqrt(1 - e * e) * sin(E * d2r)
        let v = atan2(yv, xv) * r2d
        var r = hypot(xv, yv)
        let vw = (v + w) * d2r
        let Nr = N * d2r, ir = i * d2r
        let xh = r * (cos(Nr) * cos(vw) - sin(Nr) * sin(vw) * cos(ir))
        let yh = r * (sin(Nr) * cos(vw) + cos(Nr) * sin(vw) * cos(ir))
        let zh = r * sin(vw) * sin(ir)
        var lon = atan2(yh, xh) * r2d
        var lat = atan2(zh, hypot(xh, yh)) * r2d
        let sp = sun(d: d)
        let Ms = sp.M
        let Ls = sp.w + sp.M
        let Lm = N + w + M
        let D = Lm - Ls
        let F = Lm - N
        func s(_ x: Double) -> Double { sin(x * d2r) }
        func c(_ x: Double) -> Double { cos(x * d2r) }
        lon += -1.274 * s(M - 2 * D) + 0.658 * s(2 * D) - 0.186 * s(Ms) - 0.059 * s(2 * M - 2 * D)
            - 0.057 * s(M - 2 * D + Ms) + 0.053 * s(M + 2 * D) + 0.046 * s(2 * D - Ms) + 0.041 * s(M - Ms)
            - 0.035 * s(D) - 0.031 * s(M + Ms) - 0.015 * s(2 * F - 2 * D) + 0.011 * s(M - 4 * D)
        lat += -0.173 * s(F - 2 * D) - 0.055 * s(M - F - 2 * D) - 0.046 * s(M + F - 2 * D)
            + 0.033 * s(F + 2 * D) + 0.017 * s(2 * M + F)
        r += -0.58 * c(M - 2 * D) - 0.46 * c(2 * D)
        return MoonPos(lon: norm360(lon), lat: lat, r: r)
    }

    static func moonBody(jd: Double) -> SkyBody {
        let d = dayNumber(jd)
        let m = moon(d: d)
        let lr = m.lon * d2r, br = m.lat * d2r
        let eq = eclToEq(x: m.r * cos(lr) * cos(br), y: m.r * sin(lr) * cos(br), z: m.r * sin(br), d: d)
        let sunLon = sun(d: d).lon
        let elong = norm360(m.lon - sunLon)
        let illum = (1 - cos(elong * d2r)) / 2
        var b = SkyBody(id: "moon", name: "Moon", kind: .moon, eq: eq, mag: -12.7 + 0.03 * abs(180 - elong) / 10, dist: m.r)
        b.illum = illum; b.elong = elong; b.moonDist = m.r
        return b
    }

    /// Elongation of the Moon from the Sun, degrees 0..360 (0 new, 180 full).
    static func moonElongation(jd: Double) -> Double {
        let d = dayNumber(jd)
        return norm360(moon(d: d).lon - sun(d: d).lon)
    }

    static func phaseName(elong e: Double) -> String {
        switch e {
        case ..<6.5, 353.5...: return "New Moon"
        case ..<83.5: return "Waxing Crescent"
        case ..<96.5: return "First Quarter"
        case ..<173.5: return "Waxing Gibbous"
        case ..<186.5: return "Full Moon"
        case ..<263.5: return "Waning Gibbous"
        case ..<276.5: return "Last Quarter"
        default: return "Waning Crescent"
        }
    }

    // MARK: Planets (Schlyter low-precision elements, ~1 arcmin)

    private struct El { var N, i, w, a, e, M: Double }

    private static func elements(_ p: Planet, d: Double) -> El {
        switch p {
        case .mercury: return El(N: 48.3313 + 3.24587e-5 * d, i: 7.0047 + 5.00e-8 * d, w: 29.1241 + 1.01444e-5 * d, a: 0.387098, e: 0.205635 + 5.59e-10 * d, M: 168.6562 + 4.0923344368 * d)
        case .venus: return El(N: 76.6799 + 2.46590e-5 * d, i: 3.3946 + 2.75e-8 * d, w: 54.8910 + 1.38374e-5 * d, a: 0.723330, e: 0.006773 - 1.302e-9 * d, M: 48.0052 + 1.6021302244 * d)
        case .mars: return El(N: 49.5574 + 2.11081e-5 * d, i: 1.8497 - 1.78e-8 * d, w: 286.5016 + 2.92961e-5 * d, a: 1.523688, e: 0.093405 + 2.516e-9 * d, M: 18.6021 + 0.5240207766 * d)
        case .jupiter: return El(N: 100.4542 + 2.76854e-5 * d, i: 1.3030 - 1.557e-7 * d, w: 273.8777 + 1.64505e-5 * d, a: 5.20256, e: 0.048498 + 4.469e-9 * d, M: 19.8950 + 0.0830853001 * d)
        case .saturn: return El(N: 113.6634 + 2.38980e-5 * d, i: 2.4886 - 1.081e-7 * d, w: 339.3939 + 2.97661e-5 * d, a: 9.55475, e: 0.055546 - 9.499e-9 * d, M: 316.9670 + 0.0334442282 * d)
        case .uranus: return El(N: 74.0005 + 1.3978e-5 * d, i: 0.7733 + 1.9e-8 * d, w: 96.6612 + 3.0565e-5 * d, a: 19.18171 - 1.55e-8 * d, e: 0.047318 + 7.45e-9 * d, M: 142.5905 + 0.011725806 * d)
        case .neptune: return El(N: 131.7806 + 3.0173e-5 * d, i: 1.7700 - 2.55e-7 * d, w: 272.8461 - 6.027e-6 * d, a: 30.05826 + 3.313e-8 * d, e: 0.008606 + 2.15e-9 * d, M: 260.2471 + 0.005995147 * d)
        }
    }

    static func planetBody(_ p: Planet, jd: Double) -> SkyBody {
        let d = dayNumber(jd)
        let el = elements(p, d: d)
        let M = norm360(el.M)
        let E = kepler(M: M, e: el.e)
        let xv = el.a * (cos(E * d2r) - el.e)
        let yv = el.a * sqrt(1 - el.e * el.e) * sin(E * d2r)
        let v = atan2(yv, xv) * r2d
        let r = hypot(xv, yv)
        let vw = (v + el.w) * d2r
        let Nr = el.N * d2r, ir = el.i * d2r
        var xh = r * (cos(Nr) * cos(vw) - sin(Nr) * sin(vw) * cos(ir))
        var yh = r * (sin(Nr) * cos(vw) + cos(Nr) * sin(vw) * cos(ir))
        var zh = r * sin(vw) * sin(ir)

        // Perturbations for the giants
        if p == .jupiter || p == .saturn || p == .uranus {
            let Mj = norm360(elements(.jupiter, d: d).M), Ms = norm360(elements(.saturn, d: d).M), Mu = norm360(elements(.uranus, d: d).M)
            func s(_ x: Double) -> Double { sin(x * d2r) }
            func c(_ x: Double) -> Double { cos(x * d2r) }
            var dlon = 0.0, dlat = 0.0
            switch p {
            case .jupiter:
                dlon = -0.332 * s(2 * Mj - 5 * Ms - 67.6) - 0.056 * s(2 * Mj - 2 * Ms + 21) + 0.042 * s(3 * Mj - 5 * Ms + 21)
                    - 0.036 * s(Mj - 2 * Ms) + 0.022 * c(Mj - Ms) + 0.023 * s(2 * Mj - 3 * Ms + 52) - 0.016 * s(Mj - 5 * Ms - 69)
            case .saturn:
                dlon = 0.812 * s(2 * Mj - 5 * Ms - 67.6) - 0.229 * c(2 * Mj - 4 * Ms - 2) + 0.119 * s(Mj - 2 * Ms - 3)
                    + 0.046 * s(2 * Mj - 6 * Ms - 69) + 0.014 * s(Mj - 3 * Ms + 32)
                dlat = -0.020 * c(2 * Mj - 4 * Ms - 2) + 0.018 * s(2 * Mj - 6 * Ms - 49)
            default:
                dlon = 0.040 * s(Ms - 2 * Mu + 6) + 0.035 * s(Ms - 3 * Mu + 33) - 0.015 * s(Mj - Mu + 20)
            }
            var lon = atan2(yh, xh) * r2d + dlon
            let lat = atan2(zh, hypot(xh, yh)) * r2d + dlat
            let rr = sqrt(xh * xh + yh * yh + zh * zh)
            lon = norm360(lon)
            xh = rr * cos(lon * d2r) * cos(lat * d2r)
            yh = rr * sin(lon * d2r) * cos(lat * d2r)
            zh = rr * sin(lat * d2r)
        }

        let sp = sun(d: d)
        let xs = sp.r * cos(sp.lon * d2r), ys = sp.r * sin(sp.lon * d2r)
        let xg = xh + xs, yg = yh + ys, zg = zh
        let R = sqrt(xg * xg + yg * yg + zg * zg)
        let eq = eclToEq(x: xg, y: yg, z: zg, d: d)

        let rr = sqrt(xh * xh + yh * yh + zh * zh)
        let cosFV = max(-1, min(1, (rr * rr + R * R - sp.r * sp.r) / (2 * rr * R)))
        let FV = acos(cosFV) * r2d
        let cosEl = max(-1, min(1, (R * R + sp.r * sp.r - rr * rr) / (2 * R * sp.r)))
        let elong = acos(cosEl) * r2d
        let lg = 5 * log10(rr * R)
        let mag: Double
        switch p {
        case .mercury: mag = -0.36 + lg + 0.027 * FV + 2.2e-13 * pow(FV, 6)
        case .venus: mag = -4.34 + lg + 0.013 * FV + 4.2e-7 * pow(FV, 3)
        case .mars: mag = -1.51 + lg + 0.016 * FV
        case .jupiter: mag = -9.25 + lg + 0.014 * FV
        case .saturn: mag = -8.9 + lg + 0.044 * FV
        case .uranus: mag = -7.15 + lg + 0.001 * FV
        case .neptune: mag = -6.90 + lg + 0.001 * FV
        }
        var b = SkyBody(id: p.name.lowercased(), name: p.name, kind: .planet, eq: eq, mag: mag, dist: R)
        b.illum = (1 + cosFV) / 2
        b.elong = elong
        return b
    }

    static func allBodies(jd: Double) -> [SkyBody] {
        [sunBody(jd: jd), moonBody(jd: jd)] + Planet.allCases.map { planetBody($0, jd: jd) }
    }

    // MARK: Horizontal position of a body

    /// Returns the (east, north, up) vector. The Moon gets a topocentric parallax correction.
    static func enu(of body: SkyBody, jd: Double, observer: Observer) -> V3 {
        let frame = Frame(lst: lst(jd: jd, lon: observer.lon), lat: observer.lat * d2r)
        var v = frame.enu(eqVector(body.eq))
        if body.kind == .moon {
            let alt = asin(max(-1, min(1, v.z)))
            let par = asin(min(1, cos(alt) / max(body.moonDist, 30)))
            let az = atan2(v.x, v.y)
            v = enuVector(alt: alt - par, az: az)
        }
        return v
    }

    static func altitudeDeg(of body: (Double) -> SkyBody, jd: Double, observer: Observer) -> Double {
        let b = body(jd)
        return asin(max(-1, min(1, enu(of: b, jd: jd, observer: observer).z))) * r2d
    }

    // MARK: Rise / set

    /// Scans [startJD, startJD+hours/24] in 6 minute steps.
    static func riseSet(altitude: (Double) -> Double, h0: Double, startJD: Double, hours: Double = 24) -> RiseSet {
        let step = 6.0 / 1440
        let n = Int(hours / 24 / step)
        var prev = altitude(startJD) - h0
        let first = prev
        var rise: Double?, set: Double?
        var maxAlt = -90.0, maxJD = startJD
        for i in 1...n {
            let t = startJD + Double(i) * step
            let a = altitude(t)
            if a > maxAlt { maxAlt = a; maxJD = t }
            let cur = a - h0
            if prev < 0 && cur >= 0 && rise == nil { rise = t - step * cur / (cur - prev) }
            if prev >= 0 && cur < 0 && set == nil { set = t - step * cur / (cur - prev) }
            prev = cur
        }
        return RiseSet(rise: rise.map(date(jd:)), set: set.map(date(jd:)),
                       transit: maxAlt > -89 ? date(jd: maxJD) : nil, maxAlt: maxAlt, upNow: first >= 0)
    }

    static func sunAltitude(jd: Double, observer: Observer) -> Double {
        altitudeDeg(of: { sunBody(jd: $0) }, jd: jd, observer: observer)
    }

    /// First time after `from` that the sun crosses `h` going down (dusk) or up (dawn).
    static func sunCrossing(from: Double, h: Double, descending: Bool, observer: Observer, maxHours: Double = 36) -> Date? {
        let step = 6.0 / 1440
        var t = from
        var prev = sunAltitude(jd: t, observer: observer) - h
        while t < from + maxHours / 24 {
            t += step
            let cur = sunAltitude(jd: t, observer: observer) - h
            if descending ? (prev >= 0 && cur < 0) : (prev < 0 && cur >= 0) {
                return date(jd: t - step * cur / (cur - prev))
            }
            prev = cur
        }
        return nil
    }

    // MARK: Moon phases

    enum PhaseEvent: Int, CaseIterable { case new = 0, firstQuarter = 90, full = 180, lastQuarter = 270
        var name: String { switch self { case .new: "New Moon"; case .firstQuarter: "First Quarter"; case .full: "Full Moon"; case .lastQuarter: "Last Quarter" } }
    }

    /// Next occurrence of each phase after `from`.
    static func nextPhases(after from: Date, count: Int) -> [(PhaseEvent, Date)] {
        var out: [(PhaseEvent, Date)] = []
        for ev in PhaseEvent.allCases {
            var t = jd(from)
            for _ in 0..<(count / 2 + 1) {
                if let hit = findPhase(target: Double(ev.rawValue), after: t) { out.append((ev, hit)); t = jd(hit) + 20 } else { break }
            }
        }
        return out.filter { $0.1 > from }.sorted { $0.1 < $1.1 }.prefix(count).map { $0 }
    }

    /// All principal phases between two dates.
    static func phaseEvents(from: Date, to: Date) -> [(PhaseEvent, Date)] {
        var out: [(PhaseEvent, Date)] = []
        for ev in PhaseEvent.allCases {
            var t = jd(from) - 1
            while let hit = findPhase(target: Double(ev.rawValue), after: t), hit <= to {
                if hit >= from { out.append((ev, hit)) }
                t = jd(hit) + 20
            }
        }
        return out.sorted { $0.1 < $1.1 }
    }

    static func moonSign(jd: Double) -> String {
        let signs = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
        return signs[Int(moon(d: dayNumber(jd)).lon / 30) % 12]
    }

    private static func findPhase(target: Double, after start: Double) -> Date? {
        func f(_ t: Double) -> Double { let x = moonElongation(jd: t) - target; return x > 180 ? x - 360 : (x < -180 ? x + 360 : x) }
        var t = start
        var prev = f(t)
        for _ in 0..<70 {
            let next = t + 0.5
            let cur = f(next)
            if prev < 0 && cur >= 0 && abs(cur - prev) < 90 {
                var lo = t, hi = next
                for _ in 0..<30 { let mid = (lo + hi) / 2; if f(mid) < 0 { lo = mid } else { hi = mid } }
                return date(jd: (lo + hi) / 2)
            }
            t = next; prev = cur
        }
        return nil
    }
}
