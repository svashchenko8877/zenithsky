import SwiftUI
import simd

struct SkyView: View {
    @EnvironmentObject var model: SkyModel
    @EnvironmentObject var loc: LocationProvider
    @EnvironmentObject var motion: MotionProvider
    @EnvironmentObject var purchases: PurchaseManager
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showTime = false
    @State private var dragStart: (az: Double, alt: Double)?
    @State private var pinchStart: Double?
    @State private var canvasSize: CGSize = .zero

    private var basis: DeviceBasis {
        if model.useGyro, let b = motion.basis { return b }
        return SkyCamera.basis(az: model.az, alt: model.alt)
    }

    private func snapshot(_ time: Double) -> SkySnapshot {
        SkySnapshot(date: model.date, observer: loc.observer, basis: basis, fov: model.fov,
                    showConstellations: model.showConstellations, showConstellationNames: model.showConstellationNames,
                    showLabels: model.showLabels, showDeepSky: model.showDeepSky && purchases.isPro, showGrid: model.showGrid,
                    showMilkyWay: model.showMilkyWay, starsInDay: model.starsInDay,
                    selected: model.selected, target: model.target, bodies: model.bodies(at: model.date), time: time, meteors: model.showMeteors)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                    let snap = snapshot(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000))
                    Canvas { ctx, size in
                        var c = ctx
                        SkyRenderer.draw(&c, size: size, snap: snap, data: model.data)
                    }
                    .gesture(dragGesture(size: geo.size))
                    .gesture(magnify)
                    .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { _ in
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        model.animateFov(to: model.fov > 45 * d2r ? 28 * d2r : 75 * d2r)
                    })
                    .simultaneousGesture(SpatialTapGesture().onEnded { tap(at: $0.location, snap: snap, size: geo.size) })
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, s in canvasSize = s }
                .onReceive(motion.$basis) { b in model.gyroForward = b?.forward }

                VStack(spacing: 0) {
                    topBar()
                    Spacer()
                    if let sel = model.selected, let info = model.info(sel, observer: loc.observer, at: model.date) {
                        InfoCard(info: info, obj: sel).padding(.horizontal, 14).padding(.bottom, showTime ? 8 : 92)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.92, anchor: .bottom)).combined(with: .opacity),
                                                    removal: .move(edge: .bottom).combined(with: .opacity)))
                            .id(sel)
                    }
                    if showTime { TimeBar().padding(.horizontal, 14).padding(.bottom, 92).transition(.move(edge: .bottom).combined(with: .opacity)) }
                }

                sideButtons
            }
            .colorMultiply(model.redMode ? Color(red: 1, green: 0.18, blue: 0.1) : .white)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSearch) { SearchView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showSettings) { SettingsView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $model.showPaywall) { PaywallView() }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: model.selected)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showTime)
    }

    // MARK: Gestures

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                if dragStart == nil {
                    if model.useGyro, let b = motion.basis {
                        let (a, z) = Astro.altAz(b.forward)
                        model.alt = a; model.az = z
                    }
                    model.useGyro = false
                    dragStart = (model.az, model.alt)
                }
                guard let s = dragStart else { return }
                let perPx = model.fov / Double(size.height) * 0.95
                model.az = norm2pi(s.az - Double(v.translation.width) * perPx / max(0.2, cos(s.alt)) * 0.9)
                model.alt = max(-89 * d2r, min(89 * d2r, s.alt + Double(v.translation.height) * perPx))
            }
            .onEnded { _ in dragStart = nil }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                if pinchStart == nil { pinchStart = model.fov }
                model.fov = max(8 * d2r, min(125 * d2r, (pinchStart ?? model.fov) / Double(v.magnification)))
            }
            .onEnded { _ in pinchStart = nil }
    }

    private func tap(at p: CGPoint, snap: SkySnapshot, size: CGSize) {
        let jd = Astro.jd(snap.date)
        let frame = Astro.Frame(lst: Astro.lst(jd: jd, lon: snap.observer.lon), lat: snap.observer.lat * d2r)
        let cam = SkyCamera(basis: snap.basis, size: size, fov: snap.fov)
        var best: (SkyObject, CGFloat)?
        func consider(_ o: SkyObject, _ v: V3, bias: CGFloat) {
            guard let q = cam.project(v) else { return }
            let d = hypot(q.x - p.x, q.y - p.y) - bias
            if d < 30, d < (best?.1 ?? .infinity) { best = (o, d) }
        }
        for b in snap.bodies { consider(.body(b.id), Astro.enu(of: b, jd: jd, observer: snap.observer), bias: 14) }
        if snap.showDeepSky { for d in model.data.deepSky { consider(.dso(d.id), frame.enu(d.vec), bias: 6) } }
        for (i, s) in model.data.stars.enumerated() where s.mag < 4.6 { consider(.star(i), frame.enu(s.vec), bias: CGFloat(5 - s.mag) * 2.4) }
        if best == nil, snap.showConstellations, snap.fov < 105 * d2r {
            for c in model.data.constellations { consider(.constellation(c.id), frame.enu(c.center), bias: 0) }
        }
        model.selected = best?.0
        if best != nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    // MARK: Overlays

    private func topBar() -> some View {
        let fwd = basis.forward
        let (a, z) = Astro.altAz(fwd)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: loc.denied ? "location.slash" : "location.fill").font(.system(size: 11))
                    Text(loc.observer.name).font(rounded(14, .bold))
                }
                Text(model.isLive ? "Live · " + timeFmt.string(from: model.date) : fullFmt.string(from: model.date))
                    .font(rounded(12)).foregroundStyle(model.isLive ? Theme.text2 : Theme.gold)
            }
            .padding(.horizontal, 12).padding(.vertical, 8).glass(16)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(compassName(z)) \(Int((z * r2d).rounded()))°").font(rounded(16, .bold)).monospacedDigit()
                Text("Alt \(Int((a * r2d).rounded()))° · FOV \(Int((model.fov * r2d).rounded()))°").font(rounded(11)).foregroundStyle(Theme.text2).monospacedDigit()
            }
            .padding(.horizontal, 12).padding(.vertical, 8).glass(16)
        }
        .padding(.horizontal, 14).padding(.top, 62)
    }

    private var sideButtons: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                roundButton("magnifyingglass") { showSearch = true }
                roundButton(model.useGyro ? "gyroscope" : "hand.draw", tint: model.useGyro ? Theme.accent : .white) {
                    if motion.available { model.useGyro.toggle() } else { model.useGyro = false }
                }
                roundButton(purchases.isPro ? (showTime ? "clock.fill" : "clock") : "lock.fill", tint: showTime || !model.isLive ? Theme.gold : .white) {
                    if purchases.isPro { showTime.toggle() } else { model.showPaywall = true }
                }
                roundButton(model.redMode ? "moon.fill" : "moon", tint: model.redMode ? .red : .white) { model.redMode.toggle() }
                roundButton("slider.horizontal.3") { showSettings = true }
            }
            .padding(.trailing, 14)
        }
        .padding(.top, 30)
    }

    private func roundButton(_ icon: String, tint: Color = .white, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 46, height: 46).glassEffect(.regular.interactive(), in: Circle())
        }.buttonStyle(.plain)
    }
}

// MARK: - Info card

struct InfoCard: View {
    @EnvironmentObject var model: SkyModel
    @EnvironmentObject var loc: LocationProvider
    let info: ObjectInfo
    let obj: SkyObject

    private var altaz: (Double, Double) { let r = Astro.altAz(info.enu); return (r.alt * r2d, r.az * r2d) }

    private var riseSet: RiseSet {
        let jd0 = Astro.jd(model.date)
        let obs = loc.observer
        if let b = info.body {
            let id = b.id
            let h0 = b.kind == .moon ? 0.125 : (b.kind == .sun ? -0.833 : -0.567)
            return Astro.riseSet(altitude: { t in
                let body = Astro.allBodies(jd: t).first { $0.id == id }!
                return asin(max(-1, min(1, Astro.enu(of: body, jd: t, observer: obs).z))) * r2d
            }, h0: h0, startJD: jd0)
        }
        let v = info.vec ?? V3(0, 0, 1)
        return Astro.riseSet(altitude: { t in
            asin(max(-1, min(1, Astro.Frame(lst: Astro.lst(jd: t, lon: obs.lon), lat: obs.lat * d2r).enu(v).z))) * r2d
        }, h0: -0.567, startJD: jd0)
    }

    var body: some View {
        let (alt, az) = altaz
        let rs = riseSet
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                if let b = info.body, b.kind == .moon { MoonDisc(elong: b.elong, size: 44) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title).font(rounded(22, .bold))
                    Text(info.subtitle).font(rounded(13)).foregroundStyle(Theme.text2)
                }
                Spacer()
                Button { model.selected = nil } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(.white.opacity(0.5)) }.buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                stat(alt > 0 ? "Above horizon" : "Below horizon", String(format: "%.0f° %@", alt, compassName(az * d2r)), alt > 0 ? Theme.good : Theme.warn)
                if let m = info.mag { stat("Magnitude", String(format: "%.1f", m), .white) }
                if let b = info.body, b.kind == .planet { stat("Distance", String(format: "%.2f AU", b.dist), .white) }
            }
            HStack(spacing: 8) {
                stat("Rises", rs.rise.map { dayTimeFmt.string(from: $0) } ?? (rs.upNow ? "Up now" : "—"), .white)
                stat("Sets", rs.set.map { dayTimeFmt.string(from: $0) } ?? (rs.upNow ? "—" : "Never"), .white)
            }
            HStack {
                Button { model.target = obj; model.selected = nil } label: {
                    Label("Guide me", systemImage: "location.north.line.fill").font(rounded(14, .bold)).padding(.horizontal, 14).padding(.vertical, 9)
                }.buttonStyle(.plain).glassEffect(.regular.interactive(), in: Capsule())
                Button { model.lookAt(info.enu) } label: {
                    Label("Center", systemImage: "scope").font(rounded(14, .bold)).padding(.horizontal, 14).padding(.vertical, 9)
                }.buttonStyle(.plain).glassEffect(.regular.interactive(), in: Capsule())
                Spacer()
            }
        }
        .padding(16)
        .glass(26)
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(rounded(11)).foregroundStyle(Theme.text2)
            Text(value).font(rounded(14, .bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Time travel

struct TimeBar: View {
    @EnvironmentObject var model: SkyModel
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(fullFmt.string(from: model.date)).font(rounded(16, .bold)).monospacedDigit()
                Spacer()
                Button("Now") { model.goNow() }.font(rounded(14, .bold)).buttonStyle(.plain).foregroundStyle(Theme.accent)
            }
            HStack(spacing: 8) {
                step("−1d", -86400); step("−1h", -3600)
                Button { model.playing.toggle() } label: {
                    Image(systemName: model.playing ? "pause.fill" : "play.fill").font(.system(size: 16, weight: .bold)).frame(width: 52, height: 38)
                }.buttonStyle(.plain).glassEffect(.regular.interactive(), in: Capsule())
                step("+1h", 3600); step("+1d", 86400)
            }
            Slider(value: Binding(get: { model.timeOffset / 3600 }, set: { model.timeOffset = $0 * 3600; model.playing = false }), in: -24...24)
                .tint(Theme.accent)
        }
        .padding(16).glass(26)
    }

    private func step(_ title: String, _ secs: TimeInterval) -> some View {
        Button { model.timeOffset += secs; model.playing = false } label: {
            Text(title).font(rounded(14, .bold)).frame(maxWidth: .infinity, minHeight: 38)
        }.buttonStyle(.plain).glassEffect(.regular.interactive(), in: Capsule())
    }
}
