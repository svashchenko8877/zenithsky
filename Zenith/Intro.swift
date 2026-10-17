import SwiftUI

// MARK: - Splash

struct SplashView: View {
    var onDone: () -> Void
    @State private var appear = false
    @State private var leaving = false
    @State private var moonElong: Double = 6
    private let title = Array("ZENITH")

    var body: some View {
        ZStack {
            DriftMesh(palette: [
                Color(red: 0.04, green: 0.03, blue: 0.16), Color(red: 0.16, green: 0.08, blue: 0.36), Color(red: 0.05, green: 0.05, blue: 0.20),
                Color(red: 0.30, green: 0.12, blue: 0.45), Color(red: 0.10, green: 0.08, blue: 0.32), Color(red: 0.50, green: 0.22, blue: 0.55),
                Color(red: 0.03, green: 0.03, blue: 0.12), Color(red: 0.12, green: 0.10, blue: 0.34), Color(red: 0.06, green: 0.04, blue: 0.18),
            ])
            StarField(count: 110, appear: appear)
            VStack(spacing: 26) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.35)).frame(width: 230, height: 230).blur(radius: 50)
                        .scaleEffect(appear ? 1 : 0.3).opacity(appear ? 1 : 0)
                    MoonDisc(elong: moonElong, size: 132)
                        .scaleEffect(appear ? 1 : 0.2).rotationEffect(.degrees(appear ? 0 : -50))
                        .opacity(appear ? 1 : 0)
                }
                HStack(spacing: appear ? 5 : -4) {
                    ForEach(Array(title.enumerated()), id: \.offset) { i, ch in
                        Text(String(ch)).font(.system(size: 40, weight: .heavy, design: .rounded))
                            .opacity(appear ? 1 : 0).blur(radius: appear ? 0 : 12)
                            .offset(y: appear ? 0 : 26)
                            .animation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.5 + Double(i) * 0.07), value: appear)
                    }
                }
                Text("The sky, right now.").font(rounded(16, .medium)).foregroundStyle(Theme.text2)
                    .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 10)
                    .animation(.easeOut(duration: 0.8).delay(1.2), value: appear)
            }
        }
        .scaleEffect(leaving ? 1.5 : 1).blur(radius: leaving ? 14 : 0).opacity(leaving ? 0 : 1)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.75)) { appear = true }
            withAnimation(.easeInOut(duration: 2.2)) { moonElong = 96 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                withAnimation(.easeIn(duration: 0.6)) { leaving = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { onDone() }
            }
        }
    }
}

/// Twinkling field that drifts upward in three parallax layers.
struct StarField: View {
    var count: Int
    var appear: Bool = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var g = SplitMix(seed: 99)
                for i in 0..<count {
                    let x = g.next(), y = g.next(), layer = Double(i % 3) + 1, ph = g.next() * 6.28
                    let yy = (y - t * 0.006 * layer).truncatingRemainder(dividingBy: 1)
                    let py = (yy < 0 ? yy + 1 : yy) * size.height
                    let r = 0.5 + layer * 0.55
                    let a = (0.35 + 0.45 * (0.5 + 0.5 * sin(t * (1 + layer * 0.7) + ph))) * (appear ? 1 : 0)
                    ctx.fill(Path(ellipseIn: CGRect(x: x * size.width, y: py, width: r, height: r)), with: .color(.white.opacity(a)))
                }
            }
        }
        .animation(.easeIn(duration: 1.2), value: appear)
        .allowsHitTesting(false)
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page: Int? = 0
    private let count = 3
    private let titles = ["Point at the sky", "Planets, Moon & deep sky", "Plan every night"]
    private let bodies = [
        "Hold your phone up and the stars, constellations and planets move with you.",
        "Tap anything for its name, brightness and rise and set times, then let the arrow guide you to it.",
        "Moon phases, meteor showers and eclipses, with the darkest hours of the night worked out for you.",
    ]
    private var current: Int { page ?? 0 }

    var body: some View {
        ZStack {
            DriftMesh(palette: current == 0 ? mesh(0.30, 0.14, 0.55) : (current == 1 ? mesh(0.10, 0.20, 0.55) : mesh(0.45, 0.16, 0.40)))
                .animation(.easeInOut(duration: 0.9), value: current)
            StarField(count: 70)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { onDone() }.font(rounded(15, .bold)).foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 16).padding(.vertical, 8).glassEffect(.regular.interactive(), in: Capsule())
                        .opacity(current == count - 1 ? 0 : 1).animation(.snappy, value: current)
                }.padding(.horizontal, 20).padding(.top, 58)

                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(0..<count, id: \.self) { i in
                            pageView(i).containerRelativeFrame(.horizontal).id(i)
                        }
                    }.scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging).scrollPosition(id: $page).scrollIndicators(.hidden)

                VStack(spacing: 22) {
                    HStack(spacing: 8) {
                        ForEach(0..<count, id: \.self) { i in
                            Capsule().fill(i == current ? Color.white : Color.white.opacity(0.3))
                                .frame(width: i == current ? 28 : 8, height: 8)
                        }
                    }.animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)

                    Button {
                        if current == count - 1 { onDone() } else { withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { page = current + 1 } }
                    } label: {
                        HStack(spacing: 8) {
                            Text(current == count - 1 ? "Start exploring" : "Continue").font(rounded(18, .heavy)).contentTransition(.interpolate)
                            Image(systemName: "arrow.right").font(.system(size: 16, weight: .heavy))
                                .offset(x: current == count - 1 ? 4 : 0)
                        }
                        .foregroundStyle(Color(red: 0.08, green: 0.06, blue: 0.2)).frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(ShineBackground())
                    }
                    .buttonStyle(PressScale())
                    .padding(.horizontal, 28)
                }.padding(.bottom, 44)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            #if DEBUG
            let a = ProcessInfo.processInfo.arguments
            if let i = a.firstIndex(of: "-zpage"), a.indices.contains(i + 1), let p = Int(a[i + 1]) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { page = p }
            }
            #endif
        }
    }

    private func mesh(_ r: Double, _ g: Double, _ b: Double) -> [Color] {
        let base = Color(red: 0.04, green: 0.03, blue: 0.14)
        let glow = Color(red: r, green: g, blue: b)
        let mid = Color(red: r * 0.45 + 0.03, green: g * 0.45 + 0.03, blue: b * 0.45 + 0.08)
        return [base, mid, base, mid, glow, mid, base, mid, base.opacity(0.95)]
    }

    private func pageView(_ i: Int) -> some View {
        VStack(spacing: 18) {
            Group {
                switch i {
                case 0: PhoneIllustration()
                case 1: OrbitIllustration()
                default: CalendarIllustration()
                }
            }
            .frame(height: 380)
            .scrollTransition(axis: .horizontal) { c, phase in
                c.offset(x: phase.value * -90).scaleEffect(1 - abs(phase.value) * 0.25).opacity(1 - abs(phase.value) * 0.9).rotation3DEffect(.degrees(phase.value * -25), axis: (0, 1, 0))
            }
            VStack(spacing: 10) {
                Text(titles[i]).font(.system(size: 30, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
                Text(bodies[i]).font(rounded(16, .medium)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 34)
            .scrollTransition(axis: .horizontal) { c, phase in
                c.offset(x: phase.value * 140).opacity(1 - abs(phase.value) * 1.4).blur(radius: abs(phase.value) * 8)
            }
            Spacer(minLength: 0)
        }
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// White capsule with a light sweep that loops across it.
struct ShineBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let x = CGFloat((t * 0.45).truncatingRemainder(dividingBy: 1.6)) - 0.3
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white)
                    .overlay(
                        LinearGradient(colors: [.clear, Theme.accent.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.35).offset(x: x * geo.size.width).blur(radius: 6)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.45), radius: 18, y: 6)
            }
        }
    }
}

// MARK: - Illustrations

/// Phone with a panning mini-sky and floating chips.
struct PhoneIllustration: View {
    @State private var pop = false
    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    RoundedRectangle(cornerRadius: 38, style: .continuous).fill(Color(red: 0.03, green: 0.04, blue: 0.12))
                    Canvas { ctx, size in
                        var g = SplitMix(seed: 5)
                        let pan = sin(t * 0.6) * 60
                        var pts: [CGPoint] = []
                        for i in 0..<46 {
                            let x = g.next() * (size.width + 120) - 60 + pan * (0.4 + Double(i % 3) * 0.3)
                            let y = g.next() * size.height
                            let r = 0.8 + g.next() * 2.0
                            pts.append(CGPoint(x: x, y: y))
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.5 + 0.4 * sin(t * 2 + Double(i)))))
                        }
                        var line = Path()
                        for k in 0..<5 { if k == 0 { line.move(to: pts[k]) } else { line.addLine(to: pts[k]) } }
                        ctx.stroke(line, with: .color(Theme.accent.opacity(0.5)), lineWidth: 1)
                        // horizon glow
                        ctx.fill(Path(CGRect(x: 0, y: size.height - 60, width: size.width, height: 60)),
                                 with: .linearGradient(Gradient(colors: [.clear, Color(red: 0.8, green: 0.4, blue: 0.5).opacity(0.35)]), startPoint: CGPoint(x: 0, y: size.height - 60), endPoint: CGPoint(x: 0, y: size.height)))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                    VStack { Capsule().fill(.black).frame(width: 64, height: 18).padding(.top, 10); Spacer() }
                    RoundedRectangle(cornerRadius: 38, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 3)
                }
                .frame(width: 190, height: 360)
                .rotation3DEffect(.degrees(sin(t * 0.8) * 14), axis: (0, 1, 0), perspective: 0.5)
                .rotationEffect(.degrees(sin(t * 0.5) * 3))
                .shadow(color: Theme.accent.opacity(0.4), radius: 30, y: 14)
            }
            FloatChip(text: "Jupiter  −1.7", dot: Color(red: 1, green: 0.9, blue: 0.7), phase: 0).offset(x: -112, y: -105).scaleEffect(pop ? 1 : 0.2).opacity(pop ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: pop)
            FloatChip(text: "Orion", dot: Theme.accent, phase: 2).offset(x: 112, y: -30).scaleEffect(pop ? 1 : 0.2).opacity(pop ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.4), value: pop)
            FloatChip(text: "M31 Andromeda", dot: Color(red: 0.7, green: 1, blue: 0.85), phase: 4).offset(x: -96, y: 105).scaleEffect(pop ? 1 : 0.2).opacity(pop ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.6), value: pop)
        }
        .onAppear { pop = true }
    }
}

/// Solar-system style orbits.
struct OrbitIllustration: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let tilt = 0.42
                let orbits: [(Double, Double, Color, Double)] = [
                    (60, 1.6, Color(white: 0.8), 5), (95, 1.1, Color(red: 1, green: 0.97, blue: 0.85), 7),
                    (135, 0.75, Color(red: 1, green: 0.5, blue: 0.35), 6), (175, 0.45, Color(red: 1, green: 0.9, blue: 0.7), 11),
                ]
                for (rad, sp, col, size_) in orbits {
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad * tilt, width: rad * 2, height: rad * 2 * tilt)), with: .color(.white.opacity(0.14)), lineWidth: 1)
                    let a = t * sp
                    let p = CGPoint(x: c.x + rad * cos(a), y: c.y + rad * tilt * sin(a))
                    let r = size_ * (1 + 0.12 * sin(a))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 2.2, y: p.y - r * 2.2, width: r * 4.4, height: r * 4.4)), with: .color(col.opacity(0.18)))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(col))
                }
                // Saturn with ring
                let sr = 205.0, sa = t * 0.3
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - sr, y: c.y - sr * tilt, width: sr * 2, height: sr * 2 * tilt)), with: .color(.white.opacity(0.1)), lineWidth: 1)
                let sp = CGPoint(x: c.x + sr * cos(sa), y: c.y + sr * tilt * sin(sa))
                ctx.fill(Path(ellipseIn: CGRect(x: sp.x - 9, y: sp.y - 9, width: 18, height: 18)), with: .color(Color(red: 0.95, green: 0.85, blue: 0.55)))
                ctx.stroke(Path(ellipseIn: CGRect(x: sp.x - 18, y: sp.y - 5, width: 36, height: 10)), with: .color(Color(red: 0.95, green: 0.85, blue: 0.55).opacity(0.8)), lineWidth: 1.6)
                // Sun
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 14))
                    l.fill(Path(ellipseIn: CGRect(x: c.x - 38, y: c.y - 38, width: 76, height: 76)), with: .color(Theme.gold.opacity(0.7)))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 20, y: c.y - 20, width: 40, height: 40)), with: .color(Color(red: 1, green: 0.93, blue: 0.7)))
                // Earth + Moon
                let ea = t * 0.9, er = 78.0
                let ep = CGPoint(x: c.x + er * cos(ea + 1), y: c.y + er * tilt * sin(ea + 1))
                ctx.fill(Path(ellipseIn: CGRect(x: ep.x - 6, y: ep.y - 6, width: 12, height: 12)), with: .color(Color(red: 0.4, green: 0.65, blue: 1)))
                let ma = t * 4
                let mp = CGPoint(x: ep.x + 15 * cos(ma), y: ep.y + 6 * sin(ma))
                ctx.fill(Path(ellipseIn: CGRect(x: mp.x - 2.5, y: mp.y - 2.5, width: 5, height: 5)), with: .color(.white))
            }
            .frame(width: 400, height: 360)
        }
    }
}

/// Mini calendar whose moons sweep through their phases in a wave.
struct CalendarIllustration: View {
    @State private var pop = false
    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                VStack(spacing: 10) {
                    Text("OCTOBER").font(rounded(13, .heavy)).tracking(3).foregroundStyle(.white.opacity(0.6))
                    VStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { row in
                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { col in
                                    let i = row * 7 + col
                                    let phase = Double(i) * 12.2 + t * 36
                                    MoonDisc(elong: phase, size: 30)
                                        .scaleEffect(1 + 0.12 * sin(t * 1.6 + Double(i) * 0.5))
                                }
                            }
                        }
                    }
                }
                .padding(18).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .rotation3DEffect(.degrees(sin(t * 0.5) * 8), axis: (1, 0, 0), perspective: 0.6)
            }
            FloatChip(text: "Perseids · Aug 12", dot: Theme.gold, phase: 1).offset(x: 70, y: -150).scaleEffect(pop ? 1 : 0.2).opacity(pop ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: pop)
            FloatChip(text: "Total eclipse 2027", dot: Color(red: 1, green: 0.5, blue: 0.5), phase: 3).offset(x: -60, y: 160).scaleEffect(pop ? 1 : 0.2).opacity(pop ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.55), value: pop)
        }
        .onAppear { pop = true }
    }
}
