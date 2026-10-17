import SwiftUI

struct SearchView: View {
    @EnvironmentObject var model: SkyModel
    @EnvironmentObject var loc: LocationProvider
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private struct Row: Identifiable { let id: String; let obj: SkyObject; let title: String; let sub: String; let icon: String }

    private var rows: [Row] {
        var out: [Row] = []
        let jd = Astro.jd(model.date)
        for b in Astro.allBodies(jd: jd) {
            out.append(Row(id: "b" + b.id, obj: .body(b.id), title: b.name, sub: b.kind == .planet ? "Planet" : (b.kind == .sun ? "Star" : "Moon"),
                           icon: b.kind == .sun ? "sun.max.fill" : (b.kind == .moon ? "moon.fill" : "globe")))
        }
        for d in model.data.deepSky { out.append(Row(id: "d" + d.id, obj: .dso(d.id), title: d.name, sub: d.kind + " · " + d.id, icon: "sparkles")) }
        for c in model.data.constellations { out.append(Row(id: "c" + c.id, obj: .constellation(c.id), title: c.name, sub: "Constellation", icon: "star.leadinghalf.filled")) }
        let named = model.data.stars.enumerated().filter { !$0.element.name.isEmpty && $0.element.mag < 3.2 }.sorted { $0.element.mag < $1.element.mag }
        for (i, s) in named { out.append(Row(id: "s\(i)", obj: .star(i), title: s.name, sub: String(format: "Star · mag %.1f", s.mag), icon: "star.fill")) }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? out : out.filter { $0.title.lowercased().contains(q) || $0.sub.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List(rows) { r in
                Button {
                    model.select(r.obj, observer: loc.observer, slew: true)
                    model.target = nil
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: r.icon).frame(width: 28).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading) {
                            Text(r.title).font(rounded(16, .semibold))
                            Text(r.sub).font(rounded(12)).foregroundStyle(Theme.text2)
                        }
                        Spacer()
                        if let i = model.info(r.obj, observer: loc.observer, at: model.date) {
                            let alt = Astro.altAz(i.enu).alt * r2d
                            Text(alt > 0 ? "\(Int(alt))° up" : "below").font(rounded(12)).foregroundStyle(alt > 0 ? Theme.good : Theme.text2)
                        }
                    }
                }.listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .searchable(text: $query, prompt: "Planets, stars, constellations, M31…")
            .navigationTitle("Find in sky")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: SkyModel
    @EnvironmentObject var loc: LocationProvider
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sky") {
                    Toggle("Constellation lines", isOn: model.binding(\.showConstellations))
                    Toggle("Constellation names", isOn: model.binding(\.showConstellationNames))
                    Toggle("Star & planet labels", isOn: model.binding(\.showLabels))
                    Toggle("Deep-sky objects", isOn: model.binding(\.showDeepSky))
                    Toggle("Milky Way", isOn: model.binding(\.showMilkyWay))
                    Toggle("Alt-azimuth grid", isOn: model.binding(\.showGrid))
                    Toggle("Show stars in daylight", isOn: model.binding(\.starsInDay))
                    Toggle("Shooting-star animation", isOn: model.binding(\.showMeteors))
                }
                Section("Night vision") {
                    Toggle("Red night mode", isOn: model.binding(\.redMode))
                }
                Section("Location") {
                    LabeledContent("Place", value: loc.observer.name)
                    LabeledContent("Latitude", value: String(format: "%.3f°", loc.observer.lat))
                    LabeledContent("Longitude", value: String(format: "%.3f°", loc.observer.lon))
                    if loc.denied { Text("Location is off. Zenith is using \(loc.observer.name). Enable it in Settings for your real sky.").font(.footnote).foregroundStyle(.secondary) }
                }
                Section("About") {
                    Text("Star data: Hipparcos / Yale Bright Star catalogues via d3-celestial (BSD-3). Planet and Moon positions are computed on your device.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

extension SkyModel {
    func binding(_ kp: ReferenceWritableKeyPath<SkyModel, Bool>) -> Binding<Bool> {
        Binding(get: { self[keyPath: kp] }, set: { self.objectWillChange.send(); self[keyPath: kp] = $0 })
    }
}
