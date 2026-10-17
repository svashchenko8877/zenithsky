import SwiftUI

enum Theme {
    static let bg1 = Color(red: 0.02, green: 0.03, blue: 0.09)
    static let bg2 = Color(red: 0.07, green: 0.05, blue: 0.18)
    static let accent = Color(red: 0.55, green: 0.70, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.35)
    static let good = Color(red: 0.35, green: 0.85, blue: 0.60)
    static let warn = Color(red: 1.0, green: 0.62, blue: 0.30)
    static let text2 = Color.white.opacity(0.62)
}

func rounded(_ size: CGFloat, _ w: Font.Weight = .semibold) -> Font { .system(size: size, weight: w, design: .rounded) }

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bg1, Theme.bg2], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                var g = SplitMix(seed: 7)
                for _ in 0..<70 {
                    let x = g.next() * size.width, y = g.next() * size.height, r = 0.4 + g.next() * 1.1
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.15 + g.next() * 0.5)))
                }
            }
        }.ignoresSafeArea()
    }
}

struct SplitMix {
    var s: UInt64
    init(seed: UInt64) { s = seed }
    mutating func next() -> Double {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

extension View {
    func glass(_ r: CGFloat = 22) -> some View {
        self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: r, style: .continuous))
    }
}

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ c: () -> Content) { content = c() }
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading).glass(24)
    }
}

/// Lit part of the Moon; `elong` is animatable so phases morph smoothly (use an unwrapped angle to sweep through new/full).
struct MoonLitShape: Shape {
    var elong: Double
    var animatableData: Double { get { elong } set { elong = newValue } }
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        return SkyRenderer.moonLit(center: CGPoint(x: rect.midX, y: rect.midY), r: r, elong: norm360(elong))
    }
}

/// Moon phase disc drawn from elongation (0 new, 180 full).
struct MoonDisc: View {
    var elong: Double
    var size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.16))
            MoonLitShape(elong: elong)
                .fill(LinearGradient(colors: [Color(white: 0.99), Color(white: 0.80)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(0.18), radius: size * 0.12)
    }
}

/// Soft drifting mesh gradient (the pastel-glow backdrop used by the intro and hero areas).
struct DriftMesh: View {
    var palette: [Color]
    private func pts(_ t: Double) -> [SIMD2<Float>] {
        func w(_ a: Double, _ f: Double, _ amp: Float) -> Float { Float(sin(t * f + a)) * amp }
        return [
            [0, 0], [0.5 + w(1, 0.7, 0.08), 0], [1, 0],
            [0, 0.5 + w(2, 0.6, 0.08)], [0.5 + w(3, 0.9, 0.14), 0.5 + w(4, 0.8, 0.14)], [1, 0.5 + w(5, 0.5, 0.08)],
            [0, 1], [0.5 + w(6, 0.75, 0.08), 1], [1, 1],
        ]
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            MeshGradient(width: 3, height: 3, points: pts(tl.date.timeIntervalSinceReferenceDate * 0.35), colors: palette)
        }
        .ignoresSafeArea()
    }
}

/// Floating glass chip that bobs gently (like the floating brand tiles in the reference).
struct FloatChip: View {
    var text: String
    var dot: Color
    var phase: Double = 0
    var amp: CGFloat = 7
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 8, height: 8).shadow(color: dot, radius: 4)
                Text(text).font(rounded(13, .bold))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
            .offset(x: CGFloat(sin(t * 0.9 + phase)) * amp * 0.6, y: CGFloat(sin(t * 1.3 + phase * 1.7)) * amp)
            .rotationEffect(.degrees(sin(t * 0.7 + phase) * 2.5))
        }
    }
}

/// Scroll-driven reveal used on cards in every tab.
extension View {
    func reveal() -> some View {
        self.scrollTransition(.animated(.snappy(duration: 0.45))) { c, phase in
            c.opacity(phase.isIdentity ? 1 : 0.0)
                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                .offset(y: phase.isIdentity ? 0 : (phase.value > 0 ? 40 : -20))
                .blur(radius: phase.isIdentity ? 0 : 8)
        }
    }
}
