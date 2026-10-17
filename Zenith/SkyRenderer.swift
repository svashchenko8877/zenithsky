import SwiftUI
import simd

struct SkySnapshot {
    var date: Date
    var observer: Observer
    var basis: DeviceBasis
    var fov: Double
    var showConstellations: Bool
    var showConstellationNames: Bool
    var showLabels: Bool
    var showDeepSky: Bool
    var showGrid: Bool
    var showMilkyWay: Bool
    var starsInDay: Bool
    var selected: SkyObject?
    var target: SkyObject?
    var bodies: [SkyBody]
    var time: Double = 0
    var meteors: Bool = true
}

/// Stereographic camera in (east, north, up).
struct SkyCamera {
    let basis: DeviceBasis
    let size: CGSize
    let focal: Double

    init(basis: DeviceBasis, size: CGSize, fov: Double) {
        self.basis = basis; self.size = size
        focal = Double(size.height / 2) / tan(fov / 4)
    }

    @inline(__always) func project(_ v: V3, limit: Double = -0.8) -> CGPoint? {
        let zc = simd_dot(v, basis.forward)
        if zc < limit { return nil }
        let k = focal / (1 + zc)
        return CGPoint(x: Double(size.width) / 2 + simd_dot(v, basis.right) * k,
                       y: Double(size.height) / 2 - simd_dot(v, basis.up) * k)
    }

    static func basis(az: Double, alt: Double) -> DeviceBasis {
        let f = Astro.enuVector(alt: alt, az: az)
        let r = V3(cos(az), -sin(az), 0)
        let u = simd_cross(r, f)
        return DeviceBasis(right: r, up: u, forward: f)
    }
}

enum SkyRenderer {
    static let planetColors: [String: Color] = [
        "mercury": Color(white: 0.8), "venus": Color(red: 1, green: 0.97, blue: 0.85),
        "mars": Color(red: 1, green: 0.5, blue: 0.35), "jupiter": Color(red: 1, green: 0.9, blue: 0.7),
        "saturn": Color(red: 0.95, green: 0.85, blue: 0.55), "uranus": Color(red: 0.6, green: 0.9, blue: 0.95),
        "neptune": Color(red: 0.5, green: 0.6, blue: 1),
    ]

    static func starColor(_ bv: Float) -> Color {
        let t = Double(max(-0.3, min(1.8, bv)))
        if t < 0.3 { let k = (t + 0.3) / 0.6; return Color(red: 0.62 + 0.3 * k, green: 0.74 + 0.2 * k, blue: 1) }
        if t < 0.9 { let k = (t - 0.3) / 0.6; return Color(red: 0.95 + 0.05 * k, green: 0.94 - 0.06 * k, blue: 1 - 0.4 * k) }
        let k = min(1, (t - 0.9) / 0.9)
        return Color(red: 1, green: 0.88 - 0.38 * k, blue: 0.6 - 0.35 * k)
    }

    static func skyGradient(sunAlt: Double) -> [Color] {
        // sunAlt in degrees
        func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
            let k = max(0, min(1, t))
            return Color(red: a.0 + (b.0 - a.0) * k, green: a.1 + (b.1 - a.1) * k, blue: a.2 + (b.2 - a.2) * k)
        }
        let nightTop = (0.01, 0.015, 0.06), nightBot = (0.04, 0.04, 0.13)
        let duskTop = (0.10, 0.12, 0.34), duskBot = (0.62, 0.36, 0.36)
        let dayTop = (0.20, 0.45, 0.85), dayBot = (0.55, 0.75, 0.95)
        if sunAlt > 0 { return [mix(dayTop, dayTop, 0), mix(dayBot, dayBot, 0)] }
        if sunAlt > -6 { let t = -sunAlt / 6; return [mix(dayTop, duskTop, t), mix(dayBot, duskBot, t)] }
        if sunAlt > -18 { let t = (-sunAlt - 6) / 12; return [mix(duskTop, nightTop, t), mix(duskBot, nightBot, t)] }
        return [mix(nightTop, nightTop, 0), mix(nightBot, nightBot, 0)]
    }

    static func moonLit(center c: CGPoint, r: CGFloat, elong: Double) -> Path {
        let k = cos(elong * .pi / 180)
        let dir: CGFloat = elong < 180 ? 1 : -1
        let rx = r * CGFloat(abs(k))
        let sgn: CGFloat = k >= 0 ? 1 : -1
        var lit = Path()
        let steps = 36
        for i in 0...steps {
            let t = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            let p = CGPoint(x: c.x + dir * r * CGFloat(cos(t)), y: c.y + r * CGFloat(sin(t)))
            if i == 0 { lit.move(to: p) } else { lit.addLine(to: p) }
        }
        for i in 0...steps {
            let t = Double.pi / 2 - Double.pi * Double(i) / Double(steps)
            lit.addLine(to: CGPoint(x: c.x + dir * sgn * rx * CGFloat(cos(t)), y: c.y + r * CGFloat(sin(t))))
        }
        lit.closeSubpath()
        return lit
    }

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, snap s: SkySnapshot, data: SkyData) {
        let jd = Astro.jd(s.date)
        let lstv = Astro.lst(jd: jd, lon: s.observer.lon)
        let frame = Astro.Frame(lst: lstv, lat: s.observer.lat * d2r)
        let cam = SkyCamera(basis: s.basis, size: size, fov: s.fov)
        let fovDeg = s.fov * r2d
        let rect = CGRect(origin: .zero, size: size)
        let visibleRect = rect.insetBy(dx: -40, dy: -40)

        // Sky colour from the Sun's altitude
        let sunBody = s.bodies.first { $0.kind == .sun }
        let sunEnu = sunBody.map { Astro.enu(of: $0, jd: jd, observer: s.observer) } ?? V3(0, 0, -1)
        let sunAlt = asin(max(-1, min(1, sunEnu.z))) * r2d
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: skyGradient(sunAlt: sunAlt)),
                                                   startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let night = max(0, min(1, (-sunAlt - 1) / 17))           // 0 day .. 1 astronomical night
        let starFade = s.starsInDay ? max(0.28, night) : night

        // Milky Way
        if s.showMilkyWay {
            var runs = Path()
            var pen = false
            var last = CGPoint.zero
            for v in data.milkyWay {
                if let p = cam.project(frame.enu(v), limit: -0.3), abs(p.x) < 4000, abs(p.y) < 4000 {
                    if pen, hypot(p.x - last.x, p.y - last.y) < 600 { runs.addLine(to: p) } else { runs.move(to: p) }
                    pen = true; last = p
                } else { pen = false }
            }
            let a = 0.20 * max(starFade, 0.15)
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 26))
                l.stroke(runs, with: .color(Color(red: 0.55, green: 0.65, blue: 0.95).opacity(a)), style: StrokeStyle(lineWidth: 110 * CGFloat(70 / max(fovDeg, 20)).clamped(0.6, 2.4), lineCap: .round, lineJoin: .round))
                if let g = cam.project(frame.enu(data.galacticCentre), limit: -0.3) {
                    let rr = 120 * CGFloat(70 / max(fovDeg, 20)).clamped(0.6, 2.4)
                    l.fill(Path(ellipseIn: CGRect(x: g.x - rr, y: g.y - rr * 0.7, width: 2 * rr, height: 1.4 * rr)),
                           with: .color(Color(red: 1, green: 0.85, blue: 0.7).opacity(a * 1.1)))
                }
            }
        }

        // Alt/az grid
        if s.showGrid {
            var grid = Path()
            for altDeg in stride(from: -60.0, through: 60.0, by: 30.0) {
                var pen = false
                for azDeg in stride(from: 0.0, through: 360.0, by: 3.0) {
                    if let p = cam.project(Astro.enuVector(alt: altDeg * d2r, az: azDeg * d2r)) {
                        if pen { grid.addLine(to: p) } else { grid.move(to: p) }
                        pen = true
                    } else { pen = false }
                }
            }
            for azDeg in stride(from: 0.0, to: 360.0, by: 30.0) {
                var pen = false
                for altDeg in stride(from: -88.0, through: 88.0, by: 4.0) {
                    if let p = cam.project(Astro.enuVector(alt: altDeg * d2r, az: azDeg * d2r)) {
                        if pen { grid.addLine(to: p) } else { grid.move(to: p) }
                        pen = true
                    } else { pen = false }
                }
            }
            ctx.stroke(grid, with: .color(.white.opacity(0.10)), lineWidth: 0.7)
        }

        // Constellation lines
        if s.showConstellations {
            var lines = Path()
            for c in data.constellations {
                for seg in c.lines {
                    var pen = false
                    var prev = CGPoint.zero
                    for v in seg {
                        if let p = cam.project(frame.enu(v)), abs(p.x) < 6000, abs(p.y) < 6000 {
                            if pen, hypot(p.x - prev.x, p.y - prev.y) < 3000 { lines.addLine(to: p) } else { lines.move(to: p) }
                            pen = true; prev = p
                        } else { pen = false }
                    }
                }
            }
            ctx.stroke(lines, with: .color(Theme.accent.opacity(0.32 * max(starFade, 0.5))), lineWidth: 1)
        }

        // Stars
        let magLimit = Float(5.6 - max(0, fovDeg - 40) * 0.0125)
        let zoomScale = CGFloat(pow(max(0.8, min(1.7, 70 / fovDeg)), 0.5))
        var labelStars: [(CGPoint, String, Float)] = []
        let tm = s.time
        for (idx, st) in data.stars.enumerated() {
            if st.mag > magLimit { continue }
            let e = frame.enu(st.vec)
            guard let p = cam.project(e), visibleRect.contains(p) else { continue }
            // Scintillation: stronger near the horizon, each star on its own rhythm.
            let h1 = Double((idx &* 2654435761) & 1023) / 1023, h2 = Double((idx &* 40503) & 1023) / 1023
            let low = max(0, min(1, (0.6 - e.z) / 0.6))
            let tw = sin(tm * (1.4 + h1 * 2.8) + h2 * 6.283) * (0.10 + 0.26 * low) + sin(tm * (3.1 + h2 * 2.0) + h1 * 6.283) * 0.05 * low
            let r = (0.7 + CGFloat(5.9 - st.mag) * 0.62) * zoomScale * CGFloat(1 + tw * 0.25)
            let col = starColor(st.bv)
            let alpha = Double(min(1, 0.45 + (5.8 - st.mag) * 0.2)) * starFade * (1 + tw)
            if st.mag < 2.8 {
                let g = r * 3.4 * CGFloat(1 + tw * 0.4)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: 2 * g, height: 2 * g)), with: .color(col.opacity(0.13 * starFade)))
            }
            if st.mag < 1.3 && starFade > 0.4 {
                let L = r * (5.5 + 1.5 * CGFloat(tw))
                var spike = Path()
                spike.move(to: CGPoint(x: p.x - L, y: p.y)); spike.addLine(to: CGPoint(x: p.x + L, y: p.y))
                spike.move(to: CGPoint(x: p.x, y: p.y - L)); spike.addLine(to: CGPoint(x: p.x, y: p.y + L))
                ctx.stroke(spike, with: .color(col.opacity(0.28 * starFade)), lineWidth: 0.8)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(col.opacity(min(1, alpha))))
            if !st.name.isEmpty, s.showLabels, st.mag < (fovDeg < 50 ? 3.4 : 2.1) { labelStars.append((p, st.name, st.mag)) }
        }
        if s.showLabels {
            for (p, name, _) in labelStars {
                ctx.draw(Text(name).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.62 * max(starFade, 0.5))),
                         at: CGPoint(x: p.x + 7, y: p.y - 7), anchor: .bottomLeading)
            }
        }

        // Constellation names
        if s.showConstellations && s.showConstellationNames && fovDeg < 105 {
            for c in data.constellations {
                guard let p = cam.project(frame.enu(c.center)), visibleRect.contains(p) else { continue }
                ctx.draw(Text(c.name.uppercased()).font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(1.6)
                    .foregroundStyle(Theme.accent.opacity(0.62 * max(starFade, 0.5))), at: p)
            }
        }

        // Deep-sky objects
        if s.showDeepSky && fovDeg < 110 {
            for d in data.deepSky {
                if d.mag > (fovDeg > 60 ? 5.0 : 9.5) { continue }
                guard let p = cam.project(frame.enu(d.vec)), visibleRect.contains(p) else { continue }
                let rr: CGFloat = 6 * zoomScale
                var ring = Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: 2 * rr, height: 2 * rr))
                if d.kind.contains("Galaxy") { ring = Path(ellipseIn: CGRect(x: p.x - rr * 1.3, y: p.y - rr * 0.7, width: rr * 2.6, height: rr * 1.4)) }
                ctx.stroke(ring, with: .color(Color(red: 0.7, green: 1, blue: 0.85).opacity(0.7 * max(starFade, 0.5))), lineWidth: 1)
                if s.showLabels {
                    ctx.draw(Text(d.id.hasPrefix("M") || d.id.count < 7 ? d.id : d.name).font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color(red: 0.7, green: 1, blue: 0.85).opacity(0.7)), at: CGPoint(x: p.x + rr + 3, y: p.y), anchor: .leading)
                }
            }
        }

        // Solar-system bodies
        for b in s.bodies {
            let e = Astro.enu(of: b, jd: jd, observer: s.observer)
            guard let p = cam.project(e), visibleRect.contains(p) else { continue }
            switch b.kind {
            case .sun:
                let r = 13 * zoomScale * CGFloat(1 + 0.03 * sin(tm * 1.3))
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 14))
                    l.fill(Path(ellipseIn: CGRect(x: p.x - r * 3, y: p.y - r * 3, width: r * 6, height: r * 6)), with: .color(Theme.gold.opacity(0.6)))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(red: 1, green: 0.95, blue: 0.7)))
            case .moon:
                let r = 15 * zoomScale * CGFloat(1 + 0.015 * sin(tm * 0.9))
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 10))
                    l.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.8, y: p.y - r * 1.8, width: r * 3.6, height: r * 3.6)), with: .color(.white.opacity(0.18 * b.illum + 0.04)))
                }
                let disc = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(disc, with: .color(Color(white: 0.17)))
                ctx.fill(moonLit(center: p, r: r, elong: b.elong), with: .color(Color(white: 0.95)))
            case .planet:
                let col = planetColors[b.id] ?? .white
                let r = max(2.2, (4.2 - CGFloat(b.mag) * 0.55)) * zoomScale
                let pulse = CGFloat(1 + 0.18 * sin(tm * 1.8 + Double(b.name.count)))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 2.6 * pulse, y: p.y - r * 2.6 * pulse, width: r * 5.2 * pulse, height: r * 5.2 * pulse)), with: .color(col.opacity(0.16)))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(col))
            }
            ctx.draw(Text(b.name).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.9)),
                     at: CGPoint(x: p.x + 14, y: p.y + 12), anchor: .topLeading)
        }

        // Shooting stars
        if s.meteors && night > 0.3 {
            let period = 5.5
            let k = floor(tm / period), local = tm - k * period
            var g = SplitMix(seed: UInt64(max(0, k)) &+ 1234)
            let dur = 0.9
            if local < dur {
                let sx = g.next() * Double(size.width) * 0.8 + 20, sy = g.next() * Double(size.height) * 0.35 + 60
                let ang = (0.35 + g.next() * 0.5), len = 170 + g.next() * 110
                let pr = local / dur
                let head = CGPoint(x: sx + cos(ang) * len * pr * 1.3, y: sy + sin(ang) * len * pr * 1.3)
                let fade = sin(pr * .pi)
                for i in 0..<14 {
                    let f = Double(i) / 14
                    let tail = CGPoint(x: head.x - cos(ang) * len * 0.5 * f, y: head.y - sin(ang) * len * 0.5 * f)
                    let tail2 = CGPoint(x: head.x - cos(ang) * len * 0.5 * (f + 1.0 / 14), y: head.y - sin(ang) * len * 0.5 * (f + 1.0 / 14))
                    var seg = Path(); seg.move(to: tail); seg.addLine(to: tail2)
                    ctx.stroke(seg, with: .color(.white.opacity((1 - f) * fade * 0.9)), style: StrokeStyle(lineWidth: 2.2 * (1 - f) + 0.4, lineCap: .round))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2.5, y: head.y - 2.5, width: 5, height: 5)), with: .color(.white.opacity(fade)))
            }
        }

        // Ground (stereographic projection maps circles to circles)
        drawGround(&ctx, cam: cam, size: size, sunAlt: sunAlt)

        // Cardinal points
        let cardinals: [(String, Double)] = [("N", 0), ("NE", 45), ("E", 90), ("SE", 135), ("S", 180), ("SW", 225), ("W", 270), ("NW", 315)]
        for (name, azDeg) in cardinals {
            guard let p = cam.project(Astro.enuVector(alt: 3 * d2r, az: azDeg * d2r)), visibleRect.contains(p) else { continue }
            let main = name.count == 1
            ctx.draw(Text(name).font(.system(size: main ? 17 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(name == "N" ? Color(red: 1, green: 0.45, blue: 0.4) : .white.opacity(main ? 0.9 : 0.55)), at: p)
        }

        // Selection / target markers
        if let sel = s.selected, let v = objectVector(sel, snap: s, frame: frame, jd: jd, data: data), let p = cam.project(v) {
            let pulse = CGFloat(sin(tm * 3.2))
            let r: CGFloat = 20 + pulse * 1.5
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(Theme.gold), lineWidth: 1.6)
            let k = CGFloat((tm * 0.8).truncatingRemainder(dividingBy: 1))
            let rr = 20 + k * 34
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: 2 * rr, height: 2 * rr)), with: .color(Theme.gold.opacity(Double(1 - k) * 0.7)), lineWidth: 1.2)
            // rotating corner brackets
            let ang = tm * 0.9
            for q in 0..<4 {
                let a0 = ang + Double(q) * .pi / 2
                var br = Path()
                br.addArc(center: p, radius: 30, startAngle: .radians(a0 - 0.22), endAngle: .radians(a0 + 0.22), clockwise: false)
                ctx.stroke(br, with: .color(Theme.gold.opacity(0.9)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
            if case .constellation(let cid) = sel, let con = data.constellations.first(where: { $0.id == cid }) {
                var hl = Path()
                for seg in con.lines {
                    var pen = false
                    for v2 in seg {
                        if let q = cam.project(frame.enu(v2)) { if pen { hl.addLine(to: q) } else { hl.move(to: q) }; pen = true } else { pen = false }
                    }
                }
                ctx.stroke(hl, with: .color(Theme.gold.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 6], dashPhase: CGFloat(-tm * 24)))
            }
        }
        if let tgt = s.target, let v = objectVector(tgt, snap: s, frame: frame, jd: jd, data: data) {
            let onscreen = cam.project(v).map { rect.insetBy(dx: 30, dy: 90).contains($0) } ?? false
            if !onscreen {
                // Arrow toward the target
                let dx = simd_dot(v, cam.basis.right), dy = simd_dot(v, cam.basis.up)
                let ang = atan2(-dy, dx)
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let rad = min(size.width, size.height) * 0.36
                let bob = rad + 6 * CGFloat(sin(tm * 4))
                let tip = CGPoint(x: c.x + bob * CGFloat(cos(ang)), y: c.y + bob * CGFloat(sin(ang)))
                ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 26, y: tip.y - 26, width: 52, height: 52)), with: .color(Theme.gold.opacity(0.12 + 0.1 * sin(tm * 4))))
                var arrow = Path()
                arrow.move(to: CGPoint(x: tip.x + 16 * CGFloat(cos(ang)), y: tip.y + 16 * CGFloat(sin(ang))))
                arrow.addLine(to: CGPoint(x: tip.x + 11 * CGFloat(cos(ang + 2.3)), y: tip.y + 11 * CGFloat(sin(ang + 2.3))))
                arrow.addLine(to: CGPoint(x: tip.x + 11 * CGFloat(cos(ang - 2.3)), y: tip.y + 11 * CGFloat(sin(ang - 2.3))))
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(Theme.gold))
            }
        }
    }

    static func objectVector(_ o: SkyObject, snap: SkySnapshot, frame: Astro.Frame, jd: Double, data: SkyData) -> V3? {
        switch o {
        case .star(let i): return i < data.stars.count ? frame.enu(data.stars[i].vec) : nil
        case .body(let id):
            guard let b = snap.bodies.first(where: { $0.id == id }) else { return nil }
            return Astro.enu(of: b, jd: jd, observer: snap.observer)
        case .dso(let id): return data.deepSky.first(where: { $0.id == id }).map { frame.enu($0.vec) }
        case .constellation(let id): return data.constellations.first(where: { $0.id == id }).map { frame.enu($0.center) }
        }
    }

    static func drawGround(_ ctx: inout GraphicsContext, cam: SkyCamera, size: CGSize, sunAlt: Double) {
        // Fit a circle through three projected horizon points.
        var pts: [CGPoint] = []
        for az in stride(from: 0.0, to: 360.0, by: 10.0) {
            if let p = cam.project(Astro.enuVector(alt: 0, az: az * d2r), limit: -0.85) { pts.append(p) }
        }
        guard pts.count >= 3 else {
            // Horizon entirely behind the camera: looking straight up (all sky) or straight down.
            if cam.basis.forward.z < 0 { ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(groundColor(sunAlt))) }
            return
        }
        let a = pts[0], b = pts[pts.count / 2], c = pts[pts.count - 1]
        let d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
        let nadir = cam.project(V3(0, 0, -1), limit: -0.9999)
        let fill = groundColor(sunAlt)
        var path = Path()
        let big = abs(d) < 1e-3
        if !big {
            let ux = ((a.x * a.x + a.y * a.y) * (b.y - c.y) + (b.x * b.x + b.y * b.y) * (c.y - a.y) + (c.x * c.x + c.y * c.y) * (a.y - b.y)) / d
            let uy = ((a.x * a.x + a.y * a.y) * (c.x - b.x) + (b.x * b.x + b.y * b.y) * (a.x - c.x) + (c.x * c.x + c.y * c.y) * (b.x - a.x)) / d
            let rad = hypot(a.x - ux, a.y - uy)
            let circle = Path(ellipseIn: CGRect(x: ux - rad, y: uy - rad, width: 2 * rad, height: 2 * rad))
            let nadirInside = nadir.map { hypot($0.x - ux, $0.y - uy) < rad } ?? false
            if nadirInside {
                path = circle
                ctx.fill(path, with: .color(fill))
            } else {
                path.addRect(CGRect(origin: .zero, size: size).insetBy(dx: -50, dy: -50))
                path.addPath(circle)
                ctx.fill(path, with: .color(fill), style: FillStyle(eoFill: true))
            }
            ctx.stroke(circle, with: .color(.white.opacity(0.28)), lineWidth: 1.2)
        } else {
            // Nearly straight horizon: fill the half-plane on the nadir side.
            let dir = CGPoint(x: c.x - a.x, y: c.y - a.y)
            var n = CGPoint(x: -dir.y, y: dir.x)
            let len = hypot(n.x, n.y)
            n = CGPoint(x: n.x / len, y: n.y / len)
            let side: CGFloat = {
                if let nd = nadir { return ((nd.x - a.x) * n.x + (nd.y - a.y) * n.y) >= 0 ? 1 : -1 }
                return cam.basis.up.z > 0 ? 1 : -1
            }()
            var q = Path()
            let far: CGFloat = 5000
            let l1 = CGPoint(x: a.x - dir.x / len * far, y: a.y - dir.y / len * far)
            let l2 = CGPoint(x: a.x + dir.x / len * far, y: a.y + dir.y / len * far)
            q.move(to: l1); q.addLine(to: l2)
            q.addLine(to: CGPoint(x: l2.x + n.x * side * far, y: l2.y + n.y * side * far))
            q.addLine(to: CGPoint(x: l1.x + n.x * side * far, y: l1.y + n.y * side * far))
            q.closeSubpath()
            ctx.fill(q, with: .color(fill))
        }
    }

    static func groundColor(_ sunAlt: Double) -> Color {
        let k = max(0, min(1, (sunAlt + 12) / 14))
        return Color(red: 0.02 + 0.10 * k, green: 0.025 + 0.12 * k, blue: 0.045 + 0.10 * k).opacity(0.93)
    }
}

extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(hi, Swift.max(lo, self)) }
}
