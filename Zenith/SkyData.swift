import Foundation
import SwiftUI
import simd

struct Star {
    let vec: V3
    let mag: Float
    let bv: Float
    let name: String
}

struct ConstellationInfo: Identifiable {
    let id: String
    let name: String
    let center: V3
    let lines: [[V3]]
}

struct DeepSky: Identifiable {
    let id: String
    let name: String
    let kind: String
    let mag: Double
    let vec: V3
    let eq: Eq
}

final class SkyData {
    static let shared = SkyData()
    private(set) var stars: [Star] = []
    private(set) var constellations: [ConstellationInfo] = []
    let deepSky: [DeepSky]
    /// Points along the galactic equator (J2000 equatorial unit vectors) and the galactic centre.
    let milkyWay: [V3]
    let galacticCentre: V3

    private init() {
        let years = Date().timeIntervalSince1970 / 31_557_600 - 30 // years since J2000
        func vec(_ raDeg: Double, _ decDeg: Double) -> V3 {
            let p = Astro.precess(ra: raDeg * d2r, dec: decDeg * d2r, years: years)
            return Astro.eqVector(p)
        }
        if let url = Bundle.main.url(forResource: "sky", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let arr = root["stars"] as? [[Any]] {
                stars = arr.compactMap { s in
                    guard s.count >= 5, let ra = (s[0] as? NSNumber)?.doubleValue, let dec = (s[1] as? NSNumber)?.doubleValue,
                          let m = (s[2] as? NSNumber)?.floatValue, let bv = (s[3] as? NSNumber)?.floatValue else { return nil }
                    return Star(vec: vec(ra, dec), mag: m, bv: bv, name: s[4] as? String ?? "")
                }
            }
            if let arr = root["constellations"] as? [[String: Any]] {
                constellations = arr.compactMap { c in
                    guard let id = c["id"] as? String, let name = c["name"] as? String,
                          let ra = (c["ra"] as? NSNumber)?.doubleValue, let dec = (c["dec"] as? NSNumber)?.doubleValue else { return nil }
                    let segs = (c["lines"] as? [[[NSNumber]]] ?? []).map { seg in seg.map { vec($0[0].doubleValue, $0[1].doubleValue) } }
                    return ConstellationInfo(id: id, name: name, center: vec(ra, dec), lines: segs)
                }
            }
        }

        func dso(_ id: String, _ name: String, _ kind: String, _ raH: Double, _ dec: Double, _ mag: Double) -> DeepSky {
            let p = Astro.precess(ra: raH * 15 * d2r, dec: dec * d2r, years: years)
            return DeepSky(id: id, name: name, kind: kind, mag: mag, vec: Astro.eqVector(p), eq: p)
        }
        deepSky = [
            dso("M31", "Andromeda Galaxy", "Galaxy", 0.712, 41.27, 3.4),
            dso("M45", "Pleiades", "Open cluster", 3.79, 24.12, 1.6),
            dso("M42", "Orion Nebula", "Nebula", 5.588, -5.39, 4.0),
            dso("M13", "Hercules Cluster", "Globular cluster", 16.695, 36.46, 5.8),
            dso("M44", "Beehive Cluster", "Open cluster", 8.67, 19.67, 3.7),
            dso("M33", "Triangulum Galaxy", "Galaxy", 1.564, 30.66, 5.7),
            dso("M8", "Lagoon Nebula", "Nebula", 18.063, -24.38, 4.6),
            dso("M20", "Trifid Nebula", "Nebula", 18.04, -23.03, 6.3),
            dso("M17", "Omega Nebula", "Nebula", 18.346, -16.18, 6.0),
            dso("M16", "Eagle Nebula", "Nebula", 18.313, -13.79, 6.4),
            dso("M27", "Dumbbell Nebula", "Planetary nebula", 19.994, 22.72, 7.4),
            dso("M57", "Ring Nebula", "Planetary nebula", 18.893, 33.03, 8.8),
            dso("M1", "Crab Nebula", "Supernova remnant", 5.575, 22.02, 8.4),
            dso("M51", "Whirlpool Galaxy", "Galaxy", 13.498, 47.2, 8.4),
            dso("M81", "Bode's Galaxy", "Galaxy", 9.926, 69.07, 6.9),
            dso("M82", "Cigar Galaxy", "Galaxy", 9.931, 69.68, 8.4),
            dso("M101", "Pinwheel Galaxy", "Galaxy", 14.053, 54.35, 7.9),
            dso("M104", "Sombrero Galaxy", "Galaxy", 12.666, -11.62, 8.0),
            dso("M87", "Virgo A", "Galaxy", 12.514, 12.39, 8.6),
            dso("M3", "M3", "Globular cluster", 13.703, 28.38, 6.2),
            dso("M5", "M5", "Globular cluster", 15.309, 2.08, 5.6),
            dso("M4", "M4", "Globular cluster", 16.393, -26.53, 5.6),
            dso("M22", "M22", "Globular cluster", 18.607, -23.9, 5.1),
            dso("M92", "M92", "Globular cluster", 17.285, 43.14, 6.4),
            dso("M11", "Wild Duck Cluster", "Open cluster", 18.851, -6.27, 5.8),
            dso("M6", "Butterfly Cluster", "Open cluster", 17.668, -32.25, 4.2),
            dso("M7", "Ptolemy Cluster", "Open cluster", 17.898, -34.79, 3.3),
            dso("M35", "M35", "Open cluster", 6.15, 24.33, 5.3),
            dso("M37", "M37", "Open cluster", 5.873, 32.55, 6.2),
            dso("M41", "M41", "Open cluster", 6.767, -20.75, 4.5),
            dso("M47", "M47", "Open cluster", 7.61, -14.5, 4.4),
            dso("NGC869", "Double Cluster", "Open cluster", 2.32, 57.13, 3.7),
            dso("Omega Cen", "Omega Centauri", "Globular cluster", 13.447, -47.48, 3.9),
            dso("LMC", "Large Magellanic Cloud", "Galaxy", 5.393, -69.76, 0.9),
            dso("SMC", "Small Magellanic Cloud", "Galaxy", 0.877, -72.8, 2.7),
        ]

        // Galactic plane: ecliptic-like great circle through the J2000 galactic pole (RA 192.859, Dec 27.128).
        let pole = Astro.eqVector(Eq(ra: 192.85948 * d2r, dec: 27.12825 * d2r))
        let c = Astro.eqVector(Eq(ra: 266.405 * d2r, dec: -28.936 * d2r))
        let s2 = simd_normalize(simd_cross(pole, c))
        var pts: [V3] = []
        for i in 0..<181 {
            let t = Double(i) / 180 * 2 * .pi
            let v = c * cos(t) + s2 * sin(t)
            pts.append(simd_normalize(v))
        }
        milkyWay = pts
        galacticCentre = c
    }
}
