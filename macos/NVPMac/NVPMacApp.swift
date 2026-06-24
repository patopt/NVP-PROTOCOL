import SwiftUI

@main
struct NVPMacApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 540, minHeight: 660)
                .background(Theme.bg)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @EnvironmentObject var m: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("NVP").font(.system(size: 26, weight: .black)).foregroundColor(Theme.accent)
                    Text("Worker").font(.system(size: 26, weight: .bold)).foregroundColor(Theme.text)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(m.isWorker ? Theme.green : Theme.muted).frame(width: 8, height: 8)
                        Text(m.isWorker ? "LIVE" : m.status.uppercased()).font(.caption.bold()).foregroundColor(m.isWorker ? Theme.green : Theme.muted)
                    }
                }

                // Balance hero — teal feature card
                VStack(spacing: 6) {
                    Text("Solde disponible").font(.caption).foregroundColor(Theme.text.opacity(0.7))
                    Text(usd(m.balance)).font(.system(size: 46, weight: .heavy, design: .rounded)).foregroundColor(Theme.text)
                    Text("+\(usd(m.creditsToday)) aujourd'hui").font(.callout.bold()).foregroundColor(Theme.onAccent)
                        .padding(.horizontal, 12).padding(.vertical, 5).background(Theme.accent).clipShape(Capsule())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 26).background(Theme.teal).clipShape(RoundedRectangle(cornerRadius: 26))

                // Worker toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.isWorker ? "Worker activé" : "Devenir worker").font(.headline).foregroundColor(Theme.text)
                        Text(m.isWorker ? "Gagne pendant que l'app est ouverte" : "Gagne en exécutant de l'IA").font(.caption).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { m.isWorker }, set: { m.setWorker($0) })).labelsHidden().toggleStyle(.switch).tint(Theme.accent)
                }.nvpCard()

                // Connection + stats
                HStack(spacing: 12) {
                    stat("Jobs", "\(m.jobsToday)")
                    stat("Vitesse", "\(Int(m.tokensPerSec)) tok/s")
                    stat("Réseau", m.connected ? "OK" : "—")
                }

                // Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Coordinateur").font(.headline).foregroundColor(Theme.text)
                    TextField("URL", text: $m.coordinatorURL).textFieldStyle(.roundedBorder)
                    TextField("Modèle (id, ex: gemma3_1b, nidum_llama3_2_3b)", text: $m.modelId).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Enregistrer l'appareil") { m.register() }
                            .buttonStyle(.borderedProminent).tint(Theme.accent)
                        Text(m.connected ? "Connecté ✓" : "Non connecté").font(.caption).foregroundColor(m.connected ? Theme.green : Theme.muted)
                    }
                }.nvpCard()

                // Logs
                VStack(alignment: .leading, spacing: 6) {
                    Text("Logs").font(.headline).foregroundColor(Theme.text)
                    ForEach(Array(m.logs.prefix(40).enumerated()), id: \.offset) { _, l in
                        Text("• \(l)").font(.caption).foregroundColor(Theme.muted)
                    }
                }.nvpCard()
            }
            .padding(20)
        }
        .background(Theme.bg)
        .onAppear { m.checkConnection() }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3.bold()).foregroundColor(Theme.text)
            Text(label).font(.caption2).foregroundColor(Theme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).nvpCard()
    }

    private func usd(_ v: Double) -> String {
        v != 0 && abs(v) < 0.01 ? String(format: "$%.6f", v) : String(format: "$%.2f", v)
    }
}
