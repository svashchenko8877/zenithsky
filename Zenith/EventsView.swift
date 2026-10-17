import SwiftUI

struct MeteorShower: Identifiable {
    let id: String
    let name: String
    let month: Int
    let day: Int
    let zhr: Int
    let parent: String
    var nextPeak: Date? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let year = cal.component(.year, from: Date())
        for y in [year, year + 1] {
            if let d = cal.date(from: DateComponents(year: y, month: month, day: day, hour: 12)), d > Date().addingTimeInterval(-86400) { return d }
        }
        return nil
    }
    static let all: [MeteorShower] = [
        .init(id: "qua", name: "Quadrantids", month: 1, day: 3, zhr: 80, parent: "Asteroid 2003 EH1"),
        .init(id: "lyr", name: "Lyrids", month: 4, day: 22, zhr: 18, parent: "Comet Thatcher"),
        .init(id: "eta", name: "Eta Aquariids", month: 5, day: 6, zhr: 50, parent: "Halley's Comet"),
        .init(id: "sda", name: "Southern Delta Aquariids", month: 7, day: 30, zhr: 25, parent: "Comet 96P/Machholz"),
        .init(id: "per", name: "Perseids", month: 8, day: 12, zhr: 100, parent: "Comet Swift-Tuttle"),
        .init(id: "dra", name: "Draconids", month: 10, day: 8, zhr: 10, parent: "Comet Giacobini-Zinner"),
        .init(id: "ori", name: "Orionids", month: 10, day: 21, zhr: 20, parent: "Halley's Comet"),
        .init(id: "leo", name: "Leonids", month: 11, day: 17, zhr: 15, parent: "Comet Tempel-Tuttle"),
        .init(id: "gem", name: "Geminids", month: 12, day: 14, zhr: 150, parent: "Asteroid 3200 Phaethon"),
        .init(id: "urs", name: "Ursids", month: 12, day: 22, zhr: 10, parent: "Comet Tuttle"),
    ]
}

struct EventsView: View {
    var body: some View {
        let now = Date()
                let showers = MeteorShower.all.compactMap { s -> (MeteorShower, Date)? in s.nextPeak.map { (s, $0) } }.sorted { $0.1 < $1.1 }.prefix(5)

        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Events").font(rounded(34, .heavy))
                    Text("Meteor showers and eclipses").font(rounded(15)).foregroundStyle(Theme.text2)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Meteor showers", systemImage: "sparkle").font(rounded(17, .bold))
                        ForEach(Array(showers), id: \.0.id) { s, peak in
                            let moon = Astro.moonBody(jd: Astro.jd(peak))
                            let q = moon.illum < 0.25 ? ("Dark skies", Theme.good) : (moon.illum < 0.6 ? ("Some moonlight", Theme.warn) : ("Bright Moon", Color.red.opacity(0.85)))
                            HStack(spacing: 12) {
                                MeteorGlyph(seed: Double(s.zhr) * 0.37).frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(rounded(16, .semibold))
                                    Text("\(s.parent) · up to \(s.zhr)/hr").font(rounded(12)).foregroundStyle(Theme.text2)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(dateFmt.string(from: peak)).font(rounded(14, .bold))
                                    Text(q.0).font(rounded(12, .bold)).foregroundStyle(q.1)
                                }
                            }
                        }
                    }
                }.reveal()

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Eclipses", systemImage: "circle.lefthalf.filled").font(rounded(17, .bold))
                        ForEach(Eclipse.upcoming, id: \.id) { e in
                            HStack(alignment: .top, spacing: 12) {
                                EclipseGlyph(solar: e.id.hasPrefix("s")).frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.title).font(rounded(16, .semibold))
                                    Text(e.region).font(rounded(12)).foregroundStyle(Theme.text2)
                                }
                                Spacer()
                                Text(dateFmt2.string(from: e.date)).font(rounded(14, .bold))
                            }
                        }
                    }
                }.reveal()
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
        }
        .background(AppBackground())
    }
}

private let dateFmt2: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; f.timeZone = TimeZone(identifier: "UTC"); return f }()

struct Eclipse {
    let id: String
    let title: String
    let region: String
    let date: Date
    private static func utc(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    static let all: [Eclipse] = [
        .init(id: "s2026-08", title: "Total solar eclipse", region: "Totality over Greenland, Iceland and Spain; partial over Europe and northern North America", date: utc(2026, 8, 12)),
        .init(id: "l2026-08", title: "Partial lunar eclipse", region: "Moon partly in Earth's shadow; check local visibility", date: utc(2026, 8, 28)),
        .init(id: "s2027-02", title: "Annular solar eclipse", region: "Annular over Chile, Argentina and the Atlantic; partial over South America and southern Africa", date: utc(2027, 2, 6)),
        .init(id: "l2027-02", title: "Penumbral lunar eclipse (subtle)", region: "Very faint; hard to notice by eye", date: utc(2027, 2, 20)),
        .init(id: "l2027-07", title: "Penumbral lunar eclipse (subtle)", region: "Very faint; hard to notice by eye", date: utc(2027, 7, 18)),
        .init(id: "s2027-08", title: "Total solar eclipse: the long one", region: "Totality over Morocco, Spain, Algeria, Libya, Egypt and Saudi Arabia; up to 6 min 23 s", date: utc(2027, 8, 2)),
        .init(id: "l2027-08", title: "Penumbral lunar eclipse (subtle)", region: "Very faint; hard to notice by eye", date: utc(2027, 8, 17)),
    ]
    static var upcoming: [Eclipse] { all.filter { $0.date > Date().addingTimeInterval(-86400) }.prefix(5).map { $0 } }
}

/// A streak that loops across a small tile.
struct MeteorGlyph: View {
    var seed: Double
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate + seed
            Canvas { ctx, size in
                let period = 2.4
                let p = (t.truncatingRemainder(dividingBy: period)) / period
                let head = CGPoint(x: -6 + (size.width + 16) * p, y: 2 + (size.height - 6) * p)
                for i in 0..<10 {
                    let f = Double(i) / 10
                    let a = CGPoint(x: head.x - 16 * f, y: head.y - 12 * f)
                    let b = CGPoint(x: head.x - 16 * (f + 0.1), y: head.y - 12 * (f + 0.1))
                    var seg = Path(); seg.move(to: a); seg.addLine(to: b)
                    ctx.stroke(seg, with: .color(.white.opacity((1 - f) * sin(p * .pi))), style: StrokeStyle(lineWidth: 2 - f, lineCap: .round))
                }
                var g = SplitMix(seed: UInt64(seed * 100))
                for _ in 0..<5 {
                    let x = g.next() * size.width, y = g.next() * size.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(.white.opacity(0.4 + 0.4 * sin(t * 2 + x))))
                }
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// Moon (or Sun) slowly being covered by a shadow disc.
struct EclipseGlyph: View {
    var solar: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = size.width * 0.3
                let off = CGFloat(sin(t * 0.9)) * r * 2.1
                if solar {
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 5))
                        l.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.5, y: c.y - r * 1.5, width: r * 3, height: r * 3)), with: .color(Theme.gold.opacity(0.5 * (1 - Double(min(1, abs(off) < r ? 1 - abs(off) / r : 0))))))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(red: 1, green: 0.9, blue: 0.6)))
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r + off, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(red: 0.03, green: 0.03, blue: 0.08)))
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(white: 0.92)))
                    let cover = max(0, 1 - abs(off) / (r * 1.6))
                    ctx.drawLayer { l in
                        l.clip(to: Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)))
                        l.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.15 + off, y: c.y - r * 1.15, width: r * 2.3, height: r * 2.3)),
                               with: .color(Color(red: 0.45 + 0.1 * (1 - cover), green: 0.1, blue: 0.08).opacity(0.85)))
                    }
                }
            }
        }
    }
}
