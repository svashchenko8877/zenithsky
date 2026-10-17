import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var appear = false
    private let features: [(String, String, String)] = [
        ("clock.arrow.2.circlepath", "Time travel", "Scrub the sky to any hour or day: past sunsets, tomorrow's planets."),
        ("sparkles", "Deep-sky objects", "Galaxies, nebulae and clusters, from Andromeda to the Orion Nebula."),
        ("calendar", "Full Moon calendar", "Browse every month: phases, moonrise, moonset and supermoons."),
        ("heart.fill", "Support indie astronomy", "One payment, no subscription, yours forever."),
    ]

    var body: some View {
        ZStack {
            DriftMesh(palette: [
                Color(red: 0.04, green: 0.03, blue: 0.16), Color(red: 0.22, green: 0.10, blue: 0.40), Color(red: 0.05, green: 0.05, blue: 0.20),
                Color(red: 0.30, green: 0.12, blue: 0.45), Color(red: 0.55, green: 0.24, blue: 0.55), Color(red: 0.16, green: 0.10, blue: 0.38),
                Color(red: 0.03, green: 0.03, blue: 0.12), Color(red: 0.12, green: 0.10, blue: 0.34), Color(red: 0.06, green: 0.04, blue: 0.18),
            ])
            StarField(count: 80)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 38, height: 38)
                            .glassEffect(.regular.interactive(), in: Circle())
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 20).padding(.top, 20)

                ScrollView {
                    VStack(spacing: 22) {
                        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                            let t = tl.date.timeIntervalSinceReferenceDate
                            MoonDisc(elong: 40 + t * 22, size: 110)
                                .scaleEffect(appear ? 1 : 0.3).rotationEffect(.degrees(appear ? 0 : -40))
                                .shadow(color: Theme.accent.opacity(0.5), radius: 30)
                                .offset(y: CGFloat(sin(t * 1.2)) * 4)
                        }
                        VStack(spacing: 6) {
                            Text("Zenith Pro").font(.system(size: 34, weight: .heavy, design: .rounded))
                            Text("Unlock the whole sky").font(rounded(16, .medium)).foregroundStyle(.white.opacity(0.7))
                        }.opacity(appear ? 1 : 0).offset(y: appear ? 0 : 14)
                        VStack(spacing: 12) {
                            ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                                HStack(spacing: 14) {
                                    Image(systemName: f.0).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.accent).frame(width: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(f.1).font(rounded(16, .bold))
                                        Text(f.2).font(rounded(13)).foregroundStyle(.white.opacity(0.65))
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(14).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .opacity(appear ? 1 : 0).offset(x: appear ? 0 : 60)
                                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.25 + Double(i) * 0.1), value: appear)
                            }
                        }
                    }.padding(.horizontal, 22).padding(.top, 6)
                }.scrollIndicators(.hidden)

                VStack(spacing: 10) {
                    Button { Task { await purchases.buy(); if purchases.isPro { dismiss() } } } label: {
                        Text(purchases.busy ? "…" : "Unlock for \(purchases.price)").font(rounded(18, .heavy))
                            .foregroundStyle(Color(red: 0.08, green: 0.06, blue: 0.2)).frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(ShineBackground())
                    }.buttonStyle(PressScale()).disabled(purchases.busy)
                    HStack(spacing: 18) {
                        Button("Restore purchase") { Task { await purchases.restore(); if purchases.isPro { dismiss() } } }
                        Text("·").foregroundStyle(.white.opacity(0.3))
                        Text("One-time payment").foregroundStyle(.white.opacity(0.5))
                    }.font(rounded(13, .medium)).foregroundStyle(.white.opacity(0.7))
                    if let m = purchases.message { Text(m).font(rounded(12)).foregroundStyle(Theme.warn).multilineTextAlignment(.center) }
                }.padding(.horizontal, 22).padding(.bottom, 24).padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) { appear = true } }
    }
}
