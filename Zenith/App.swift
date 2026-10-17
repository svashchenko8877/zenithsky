import SwiftUI

@main
struct ZenithApp: App {
    @StateObject private var model = SkyModel()
    @StateObject private var loc = LocationProvider()
    @StateObject private var motion = MotionProvider()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model).environmentObject(loc).environmentObject(motion).environmentObject(purchases)
                .preferredColorScheme(.dark)
                .onAppear { loc.start(); motion.start(); applyLaunchArgs() }
        }
    }

    private func applyLaunchArgs() {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        func val(_ k: String) -> Double? { a.firstIndex(of: k).flatMap { a.indices.contains($0 + 1) ? Double(a[$0 + 1]) : nil } }
        if let az = val("-zaz") { model.az = az * d2r; model.useGyro = false }
        if let alt = val("-zalt") { model.alt = alt * d2r; model.useGyro = false }
        if let fov = val("-zfov") { model.fov = fov * d2r }
        if let h = val("-zhours") { model.timeOffset = h * 3600 }
        if a.contains("-zmanual") { model.useGyro = false }
        if let sel = a.firstIndex(of: "-zselect"), a.indices.contains(sel + 1) {
            let key = a[sel + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.selected = .body(key) }
        }
        if a.contains("-zgrid") { model.showGrid = true }
        if a.contains("-zpaywall") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { model.showPaywall = true } }
        if let lat = val("-zlat"), let lon = val("-zlon") { loc.observer = Observer(lat: lat, lon: lon, name: "Test") }
        #endif
    }
}

struct RootView: View {
    @AppStorage("zen.onboarded") private var onboarded = false
    @State private var tab = 0
    @State private var stage = 0          // 0 splash, 1 onboarding, 2 app
    @EnvironmentObject var model: SkyModel

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                Tab("Sky", systemImage: "sparkles", value: 0) { SkyView() }
                Tab("Tonight", systemImage: "moon.stars.fill", value: 1) { TonightView() }
                Tab("Moon", systemImage: "moonphase.first.quarter", value: 2) { MoonView() }
                Tab("Events", systemImage: "calendar", value: 3) { EventsView() }
            }
            .tint(Theme.accent)
            .opacity(stage == 2 ? 1 : 0)

            if stage == 1 {
                OnboardingView {
                    onboarded = true
                    withAnimation(.easeInOut(duration: 0.5)) { stage = 2 }
                    model.introZoom()
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08)))
            }
            if stage == 0 {
                SplashView {
                    guard stage == 0 else { return }
                    if onboarded { withAnimation(.easeInOut(duration: 0.4)) { stage = 2 }; model.introZoom() }
                    else { withAnimation(.easeInOut(duration: 0.5)) { stage = 1 } }
                }
                .transition(.opacity)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            #if DEBUG
            let a = ProcessInfo.processInfo.arguments
            if a.contains("-zskip") { stage = 2 }
            if a.contains("-zonboard") { stage = 1; onboarded = false }
            if let i = a.firstIndex(of: "-ztab"), a.indices.contains(i + 1), let t = Int(a[i + 1]) { tab = t }
            #endif
        }
    }
}
