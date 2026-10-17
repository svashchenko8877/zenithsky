import SwiftUI

private let fullMoonNames = ["Wolf Moon", "Snow Moon", "Worm Moon", "Pink Moon", "Flower Moon", "Strawberry Moon",
                             "Buck Moon", "Sturgeon Moon", "Harvest Moon", "Hunter's Moon", "Beaver Moon", "Cold Moon"]
private let monthFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; return f }()
private let longDayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f }()

struct MoonView: View {
    @EnvironmentObject var loc: LocationProvider
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var model: SkyModel
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var displayElong: Double = 0
    @State private var appeared = false
    @State private var dir: Edge = .trailing
    @State private var shownIllum = 0
    @Namespace private var ns
    private let cal = Calendar.current

    private var days: [Date?] {
        let range = cal.range(of: .day, in: .month, for: month)!
        let first = cal.component(.weekday, from: month) - cal.firstWeekday
        let lead = (first + 7) % 7
        return Array(repeating: nil, count: lead) + range.map { cal.date(byAdding: .day, value: $0 - 1, to: month)! }
    }

    private func noon(_ d: Date) -> Date { cal.date(bySettingHour: 12, minute: 0, second: 0, of: d)! }

    private var events: [(Astro.PhaseEvent, Date)] {
        let end = cal.date(byAdding: .month, value: 1, to: month)!
        return Astro.phaseEvents(from: month, to: end)
    }

    var body: some View {
        let evs = events
        let weekdays = cal.veryShortStandaloneWeekdaySymbols
        let k = cal.firstWeekday - 1
        let ordered: [String] = Array(weekdays[k...]) + Array(weekdays[..<k])

        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("Moon").font(rounded(34, .heavy))
                    Spacer()
                    Button("Today") { shiftToToday() }
                        .font(rounded(14, .bold)).padding(.horizontal, 14).padding(.vertical, 8).glassEffect(.regular.interactive(), in: Capsule())
                        .buttonStyle(.plain)
                }.padding(.top, 8)

                Card {
                    VStack(spacing: 10) {
                        HStack {
                            chevron("chevron.left") { shift(-1) }
                            Spacer()
                            VStack(spacing: 0) {
                                Text(monthFmt.string(from: month)).font(rounded(20, .bold))
                                if let full = evs.first(where: { $0.0 == .full }) {
                                    Text(fullMoonNames[cal.component(.month, from: full.1) - 1]).font(rounded(12)).foregroundStyle(Theme.gold)
                                }
                            }
                            Spacer()
                            chevron("chevron.right") { shift(1) }
                        }
                        HStack(spacing: 0) {
                            ForEach(Array(ordered.enumerated()), id: \.offset) { _, d in
                                Text(d).font(rounded(12)).foregroundStyle(Theme.text2).frame(maxWidth: .infinity)
                            }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                                if let day { cell(day, evs, index: i) } else { Color.clear.frame(height: 56) }
                            }
                        }
                        .id(month)
                        .transition(.asymmetric(insertion: .move(edge: dir).combined(with: .opacity), removal: .move(edge: dir == .trailing ? .leading : .trailing).combined(with: .opacity)))
                        .gesture(scrub)
                    }
                }

                detail(for: selected, evs: evs).id(selected).transition(.opacity.combined(with: .scale(scale: 0.98))).reveal()
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
        }
        .background(AppBackground())
        .onAppear { displayElong = 0; morph(); appeared = false; DispatchQueue.main.async { appeared = true } }
        .onDisappear { appeared = false }
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 6).onChanged { v in
            let w = UIScreen.main.bounds.width - 32 - 32
            let col = Int(max(0, min(6, v.location.x / (w / 7))))
            let row = Int(max(0, v.location.y / 62))
            let i = row * 7 + col
            if i < days.count, let d = days[i], !cal.isDate(d, inSameDayAs: selected) {
                UISelectionFeedbackGenerator().selectionChanged()
                select(d)
            }
        }
    }

    private func select(_ d: Date) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { selected = cal.startOfDay(for: d) }
        morph()
    }

    /// Animate the big moon through the shortest way round the phase cycle.
    private func morph() {
        let target = Astro.moonElongation(jd: Astro.jd(noon(selected)))
        var delta = (target - displayElong).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.78)) { displayElong += delta }
        let pct = Int(((1 - cos(target * .pi / 180)) / 2 * 100).rounded())
        withAnimation(.snappy(duration: 0.5)) { shownIllum = pct }
    }

    private func cell(_ day: Date, _ evs: [(Astro.PhaseEvent, Date)], index: Int) -> some View {
        let elong = Astro.moonElongation(jd: Astro.jd(noon(day)))
        let isToday = cal.isDateInToday(day)
        let isSel = cal.isDate(day, inSameDayAs: selected)
        let ev = evs.first { cal.isDate($0.1, inSameDayAs: day) }
        return Button { UISelectionFeedbackGenerator().selectionChanged(); select(day) } label: {
            VStack(spacing: 3) {
                MoonDisc(elong: elong, size: 30).scaleEffect(isSel ? 1.12 : 1)
                Text("\(cal.component(.day, from: day))").font(rounded(12, isToday ? .heavy : .medium)).monospacedDigit()
                    .foregroundStyle(isToday ? Theme.gold : .white.opacity(0.85))
                Circle().fill(ev == nil ? .clear : Theme.gold).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 4)
            .background {
                if isSel {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.16))
                        .matchedGeometryEffect(id: "sel", in: ns)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isToday ? Theme.gold.opacity(0.8) : .clear, lineWidth: 1))
            .scaleEffect(appeared ? 1 : 0.2).opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.014), value: appeared)
        }.buttonStyle(PressScale())
    }

    @ViewBuilder private func detail(for day: Date, evs: [(Astro.PhaseEvent, Date)]) -> some View {
        let obs = loc.observer
        let noonJD = Astro.jd(noon(day))
        let moon = Astro.moonBody(jd: noonJD)
        let rs = Astro.riseSet(altitude: { Astro.altitudeDeg(of: { Astro.moonBody(jd: $0) }, jd: $0, observer: obs) }, h0: 0.125, startJD: Astro.jd(cal.startOfDay(for: day)))
        let age = moon.elong / 360 * 29.530588
        let km = Int(moon.moonDist * 6378.14)
        let dayEvents = Astro.phaseEvents(from: cal.startOfDay(for: day), to: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: day))!)

        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text(longDayFmt.string(from: day)).font(rounded(15)).foregroundStyle(Theme.text2)
                HStack(spacing: 18) {
                    MoonDisc(elong: displayElong, size: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Astro.phaseName(elong: moon.elong)).font(rounded(22, .bold))
                        Text("\(shownIllum)% illuminated").font(rounded(15)).foregroundStyle(Theme.text2)
                            .contentTransition(.numericText(value: Double(shownIllum))).monospacedDigit()
                        Text(String(format: "Moon age %.1f days", age)).font(rounded(14)).foregroundStyle(Theme.text2)
                            .contentTransition(.numericText(value: age)).monospacedDigit()
                    }
                }
                ForEach(Array(dayEvents.enumerated()), id: \.offset) { _, e in
                    let m = Astro.moonBody(jd: Astro.jd(e.1))
                    let super_ = (e.0 == .full || e.0 == .new) && m.moonDist * 6378.14 < 361_500
                    HStack {
                        Image(systemName: "sparkle").foregroundStyle(Theme.gold)
                        Text("\(e.0.name) at \(timeFmt.string(from: e.1))").font(rounded(15, .bold))
                        if e.0 == .full { Text(fullMoonNames[cal.component(.month, from: e.1) - 1]).font(rounded(13)).foregroundStyle(Theme.gold) }
                        if super_ { Text("Supermoon").font(rounded(12, .bold)).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Theme.gold.opacity(0.25))) }
                    }
                }
                Divider().overlay(.white.opacity(0.12))
                HStack {
                    stat("Moonrise", rs.rise.map { timeFmt.string(from: $0) } ?? "—")
                    stat("Moonset", rs.set.map { timeFmt.string(from: $0) } ?? "—")
                    stat("Highest", rs.transit.map { timeFmt.string(from: $0) } ?? "—")
                }
                HStack {
                    stat("Distance", "\(km.formatted()) km")
                    stat("Moon in", Astro.moonSign(jd: noonJD))
                    stat("Elongation", "\(Int(moon.elong))°")
                }
            }
        }
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(rounded(11)).foregroundStyle(Theme.text2)
            Text(v).font(rounded(14, .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chevron(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 16, weight: .bold)).frame(width: 40, height: 40).glassEffect(.regular.interactive(), in: Circle())
        }.buttonStyle(.plain)
    }

    private func shiftToToday() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dir = startOfMonth(Date()) > month ? .trailing : .leading
        appeared = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { month = startOfMonth(Date()); selected = cal.startOfDay(for: Date()) }
        morph()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true }
    }

    private func startOfMonth(_ d: Date) -> Date { cal.date(from: cal.dateComponents([.year, .month], from: d))! }
    private func shift(_ n: Int) {
        if !purchases.isPro { model.showPaywall = true; UINotificationFeedbackGenerator().notificationOccurred(.warning); return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dir = n > 0 ? .trailing : .leading
        appeared = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            month = cal.date(byAdding: .month, value: n, to: month)!
            selected = cal.isDate(month, equalTo: Date(), toGranularity: .month) ? cal.startOfDay(for: Date()) : month
        }
        morph()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true }
    }
}
