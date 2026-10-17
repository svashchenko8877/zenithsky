import SwiftUI

struct TonightView: View {
    @EnvironmentObject var model: SkyModel
    @EnvironmentObject var loc: LocationProvider

    @State private var appeared = false
    @State private var moonElong: Double = 0
    @State private var shownPct: Int = 0
    @State private var barProgress: CGFloat = 0

    private struct PlanetRow: Identifiable { let id: String; let body: SkyBody; let rs: RiseSet; let alt: Double; let spark: [Double] }

    var body: some View {
        let now = Date()
        let jd = Astro.jd(now)
        let obs = loc.observer
        let moon = Astro.moonBody(jd: jd)
        let dusk = Astro.sunCrossing(from: jd, h: -18, descending: true, observer: obs)
        let dawn = Astro.sunCrossing(from: dusk.map(Astro.jd) ?? jd, h: -18, descending: false, observer: obs)
        let sunset = Astro.sunCrossing(from: jd, h: -0.833, descending: true, observer: obs)
        let sunrise = Astro.sunCrossing(from: sunset.map(Astro.jd) ?? jd, h: -0.833, descending: false, observer: obs)
        let moonRS = Astro.riseSet(altitude: { Astro.altitudeDeg(of: { Astro.moonBody(jd: $0) }, jd: $0, observer: obs) }, h0: 0.125, startJD: jd)
        let rows = planetRows(from: jd, obs: obs)
        let visible = rows.filter { $0.alt > 5 && $0.body.mag < 6 }

        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tonight").font(rounded(34, .heavy))
                    Text("\(dateFmt.string(from: now)) · \(obs.name)").font(rounded(15)).foregroundStyle(Theme.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : -16)

                // Hero: breathing moon with floating planet chips
                Card {
                    ZStack(alignment: .leading) {
                        HStack(spacing: 16) {
                            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                                let t = tl.date.timeIntervalSinceReferenceDate
                                MoonDisc(elong: moonElong, size: 86)
                                    .scaleEffect(1 + 0.025 * sin(t * 1.1))
                                    .rotationEffect(.degrees(sin(t * 0.4) * 3))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Astro.phaseName(elong: moon.elong)).font(rounded(20, .bold))
                                Text("\(shownPct)% illuminated").font(rounded(14)).foregroundStyle(Theme.text2)
                                    .contentTransition(.numericText(value: Double(shownPct))).monospacedDigit()
                                Text("Rises \(moonRS.rise.map { dayTimeFmt.string(from: $0) } ?? "—")").font(rounded(13))
                                Text("Sets \(moonRS.set.map { dayTimeFmt.string(from: $0) } ?? "—")").font(rounded(13))
                            }
                        }
                        VStack(alignment: .trailing, spacing: 14) {
                            ForEach(Array(visible.prefix(2).enumerated()), id: \.offset) { i, r in
                                FloatChip(text: r.body.name, dot: SkyRenderer.planetColors[r.body.id] ?? .white, phase: Double(i) * 2.3, amp: 5)
                                    .scaleEffect(appeared ? 1 : 0.2).opacity(appeared ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.7 + Double(i) * 0.2), value: appeared)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing).offset(y: -2)
                    }
                }.reveal()

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Darkness", systemImage: "moon.stars.fill").font(rounded(17, .bold))
                        NightBar(obs: obs, start: sunset.map(Astro.jd(_:)).map { $0 - 1.0 / 24 } ?? jd, end: sunrise.map(Astro.jd(_:)).map { $0 + 1.0 / 24 } ?? jd + 0.6, nowJD: jd, progress: barProgress)
                            .frame(height: 44)
                        HStack {
                            tile("Sunset", sunset)
                            tile("Astro dusk", dusk)
                            tile("Astro dawn", dawn)
                            tile("Sunrise", sunrise)
                        }
                        Text(darknessVerdict(moon: moon, dusk: dusk, dawn: dawn, obs: obs)).font(rounded(13)).foregroundStyle(Theme.text2)
                    }
                }.reveal()

                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Planets", systemImage: "globe.europe.africa.fill").font(rounded(17, .bold))
                        ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                            HStack(spacing: 12) {
                                ZStack {
                                    if r.alt > 5 { PulseDot(color: SkyRenderer.planetColors[r.body.id] ?? .white) }
                                    Circle().fill(SkyRenderer.planetColors[r.body.id] ?? .white).frame(width: 14, height: 14)
                                }.frame(width: 26, height: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(r.body.name).font(rounded(16, .semibold))
                                    Text(String(format: "mag %.1f", r.body.mag)).font(rounded(12)).foregroundStyle(Theme.text2)
                                }
                                Spacer()
                                AltitudeSpark(values: r.spark, color: SkyRenderer.planetColors[r.body.id] ?? .white, delay: 0.5 + Double(i) * 0.12)
                                    .frame(width: 70, height: 30)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(status(r)).font(rounded(14, .bold)).foregroundStyle(statusColor(r))
                                    Text(detail(r)).font(rounded(12)).foregroundStyle(Theme.text2)
                                }.frame(minWidth: 96, alignment: .trailing)
                            }
                            .opacity(appeared ? 1 : 0).offset(x: appeared ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.35 + Double(i) * 0.08), value: appeared)
                        }
                    }
                }.reveal()
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
        }
        .background(AppBackground())
        .onAppear { play(moon: moon) }
        .onDisappear { appeared = false; moonElong = 0; shownPct = 0; barProgress = 0 }
    }

    private func play(moon: SkyBody) {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { appeared = true }
        withAnimation(.easeOut(duration: 1.5).delay(0.15)) { moonElong = moon.elong }
        withAnimation(.easeOut(duration: 1.3).delay(0.2)) { shownPct = Int((moon.illum * 100).rounded()) }
        withAnimation(.easeInOut(duration: 1.4).delay(0.3)) { barProgress = 1 }
    }

    private func tile(_ title: String, _ d: Date?) -> some View {
        VStack(spacing: 3) {
            Text(title).font(rounded(11)).foregroundStyle(Theme.text2)
            Text(d.map { timeFmt.string(from: $0) } ?? "—").font(rounded(14, .bold)).monospacedDigit()
        }.frame(maxWidth: .infinity)
    }

    private func planetRows(from jd: Double, obs: Observer) -> [PlanetRow] {
        Planet.allCases.map { p in
            let b = Astro.planetBody(p, jd: jd)
            let rs = Astro.riseSet(altitude: { t in Astro.altitudeDeg(of: { Astro.planetBody(p, jd: $0) }, jd: t, observer: obs) }, h0: -0.567, startJD: jd)
            let alt = Astro.altitudeDeg(of: { Astro.planetBody(p, jd: $0) }, jd: jd, observer: obs)
            let spark = (0...24).map { Astro.altitudeDeg(of: { Astro.planetBody(p, jd: $0) }, jd: jd + Double($0) * 0.75 / 24, observer: obs) }
            return PlanetRow(id: b.id, body: b, rs: rs, alt: alt, spark: spark)
        }
    }

    private func status(_ r: PlanetRow) -> String {
        let sunAlt = Astro.sunAltitude(jd: Astro.jd(Date()), observer: loc.observer)
        if r.alt > 5 { return sunAlt > -4 ? "Up (daylight)" : "Visible now" }
        if r.alt > 0 { return "Low" }
        return r.rs.rise != nil ? "Rises soon" : "Not up today"
    }
    private func statusColor(_ r: PlanetRow) -> Color { r.alt > 5 ? Theme.good : (r.alt > 0 ? Theme.warn : Theme.text2) }
    private func detail(_ r: PlanetRow) -> String {
        if r.alt > 0, let s = r.rs.set { return "sets \(timeFmt.string(from: s))" }
        if let rise = r.rs.rise { return "rises \(timeFmt.string(from: rise))" }
        return String(format: "%.0f° %@", r.alt, "alt")
    }

    private func darknessVerdict(moon: SkyBody, dusk: Date?, dawn: Date?, obs: Observer) -> String {
        guard dusk != nil, dawn != nil else { return "No full astronomical night at this latitude right now." }
        let moonUpAtMidnight: Bool = {
            let mid = Astro.jd(dusk!) + (Astro.jd(dawn!) - Astro.jd(dusk!)) / 2
            return Astro.altitudeDeg(of: { Astro.moonBody(jd: $0) }, jd: mid, observer: obs) > 0
        }()
        if moon.illum < 0.2 || !moonUpAtMidnight { return "Great night for faint objects: the Moon stays out of the way." }
        if moon.illum < 0.6 { return "Decent: the Moon will wash out the faintest objects while it is up." }
        return "Bright Moon tonight. Stick to planets, the Moon itself and bright clusters."
    }
}

/// Sunset-to-sunrise strip coloured by the Sun's altitude, with the Moon-up band and a live "now" marker.
struct NightBar: View {
    var obs: Observer
    var start: Double
    var end: Double
    var nowJD: Double
    var progress: CGFloat

    var body: some View {
        let n = 60
        let span = max(end - start, 0.1)
        let stops: [Gradient.Stop] = (0...n).map { i in
            let t = start + span * Double(i) / Double(n)
            let alt = Astro.sunAltitude(jd: t, observer: obs)
            return Gradient.Stop(color: SkyRenderer.skyGradient(sunAlt: alt)[1], location: Double(i) / Double(n))
        }
        let moonUp: [Bool] = (0...n).map { i in Astro.altitudeDeg(of: { Astro.moonBody(jd: $0) }, jd: start + span * Double(i) / Double(n), observer: obs) > 0 }
        let nowX = CGFloat(max(0, min(1, (nowJD - start) / span)))

        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing))
                    .overlay(StarField(count: 26).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).opacity(0.7))
                    .mask(alignment: .leading) { Rectangle().frame(width: w * progress) }
                // Moon-up band
                Canvas { ctx, size in
                    for i in 0..<n where moonUp[i] {
                        let x0 = size.width * CGFloat(i) / CGFloat(n), x1 = size.width * CGFloat(i + 1) / CGFloat(n)
                        ctx.fill(Path(roundedRect: CGRect(x: x0, y: size.height - 8, width: x1 - x0 + 0.5, height: 5), cornerRadius: 2.5), with: .color(.white.opacity(0.8)))
                    }
                }.mask(alignment: .leading) { Rectangle().frame(width: w * progress) }
                // Now marker
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    Circle().fill(Theme.gold).frame(width: 12, height: 12)
                        .shadow(color: Theme.gold, radius: 6 + 3 * CGFloat(sin(t * 3)))
                        .overlay(Circle().stroke(Theme.gold.opacity(0.5), lineWidth: 1).scaleEffect(1.6 + 0.5 * CGFloat(sin(t * 3))))
                }
                .position(x: w * nowX * progress, y: 14).opacity(Double(progress))
            }
        }
    }
}

struct PulseDot: View {
    var color: Color
    @State private var on = false
    var body: some View {
        Circle().stroke(color.opacity(0.6), lineWidth: 1.5).frame(width: 14, height: 14)
            .scaleEffect(on ? 2.0 : 1).opacity(on ? 0 : 0.9)
            .onAppear { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { on = true } }
    }
}

/// Tiny altitude-over-the-night curve that draws itself in.
struct AltitudeSpark: View {
    var values: [Double]
    var color: Color
    var delay: Double
    @State private var draw: CGFloat = 0

    private func pt(_ i: Int, _ size: CGSize) -> CGPoint {
        let lo = -20.0, hi = 90.0
        return CGPoint(x: size.width * CGFloat(i) / CGFloat(values.count - 1),
                       y: size.height - size.height * CGFloat((max(lo, min(hi, values[i])) - lo) / (hi - lo)))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizonY = h - h * CGFloat((0 + 20.0) / 110.0)
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: horizonY)); p.addLine(to: CGPoint(x: w, y: horizonY)) }
                    .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                Path { p in
                    for i in 0..<values.count { if i == 0 { p.move(to: pt(i, geo.size)) } else { p.addLine(to: pt(i, geo.size)) } }
                }
                .trim(from: 0, to: draw)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .shadow(color: color.opacity(0.6), radius: 3)
                Circle().fill(.white).frame(width: 5, height: 5).position(pt(0, geo.size)).opacity(Double(draw))
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.2).delay(delay)) { draw = 1 } }
        .onDisappear { draw = 0 }
    }
}
