import SwiftUI

struct WorkerView: View {
    @EnvironmentObject var app: AppState
    @State private var showNVP = false
    @State private var pulse = false

    var body: some View {
        content
            .fullScreenCover(isPresented: $showNVP) { NVPBetaView().environmentObject(app) }
            .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true } }
    }

    private var bannerColor: Color {
        switch app.deviceState.statusBanner.color {
        case "green": return Theme.green
        case "red": return Theme.red
        default: return Theme.gold
        }
    }

    private var isLive: Bool { app.isWorker && app.deviceState.canWork }

    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header
                HStack {
                    Text("NVP").font(.title2).bold().foregroundColor(Theme.gold)
                    Text("Worker").font(.title2).bold().foregroundColor(Theme.text)
                    Spacer()
                    StatusPill(live: isLive, text: app.status)
                }
                .padding(.top, 8)

                // Balance hero — animated deep-teal feature card (fintech identity)
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(colors: [Theme.teal, Color(red: 0.04, green: 0.16, blue: 0.13)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    // Soft animated lime glow that breathes when earning.
                    Circle().fill(Theme.accent.opacity(isLive ? 0.22 : 0.08))
                        .frame(width: 260, height: 260).blur(radius: 60)
                        .offset(x: 120, y: -70).scaleEffect(pulse ? 1.12 : 0.92)
                    VStack(spacing: 8) {
                        Image("nvpcoin").resizable().scaledToFit().frame(width: 40, height: 40)
                            .clipShape(Circle()).overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                            .shadow(color: Theme.accent.opacity(isLive ? 0.5 : 0), radius: 10)
                        Text("Available balance").font(.caption).foregroundColor(Theme.onTeal.opacity(0.7))
                        Text(Format.usd(app.balance))
                            .font(.system(size: 46, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.onTeal)
                            .contentTransition(.numericText())
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right").font(.caption2)
                            Text("+\(Format.usd(app.creditsToday)) today").font(.footnote.bold())
                        }
                        .foregroundColor(Theme.onAccent)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Theme.accent).clipShape(Capsule())
                    }
                    .padding(.vertical, 28)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)

                // Big toggle card
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        ZStack {
                            if isLive {
                                Circle().stroke(Theme.green.opacity(0.5), lineWidth: 2)
                                    .frame(width: 52, height: 52)
                                    .scaleEffect(pulse ? 1.35 : 1.0).opacity(pulse ? 0 : 0.8)
                            }
                            Circle().fill(isLive ? Theme.green.opacity(0.18) : Color.white.opacity(0.06))
                                .frame(width: 52, height: 52)
                            Image(systemName: "bolt.fill")
                                .foregroundColor(isLive ? Theme.green : Theme.muted)
                                .font(.title2)
                                .scaleEffect(isLive && pulse ? 1.12 : 1.0)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.isWorker ? "Worker is ON" : "Become a worker")
                                .font(.headline).foregroundColor(Theme.text)
                            Text(app.isWorker ? "Earning while open" : "Earn by running AI")
                                .font(.caption).foregroundColor(Theme.muted)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(get: { app.isWorker }, set: { app.setWorker($0) }))
                            .labelsHidden()
                            .tint(Theme.green)
                    }
                    Divider().background(Color.white.opacity(0.06))
                    HStack(spacing: 8) {
                        Circle().fill(bannerColor).frame(width: 9, height: 9)
                        Text(app.deviceState.statusBanner.text)
                            .font(.footnote).foregroundColor(Theme.muted)
                        Spacer()
                    }
                }
                .card()

                // Live task strip — what the worker is running right now (so an
                // OpenClaw instance run or an image generation is visible).
                if isLive, app.activity == .inferring || app.activity == .receivedJob {
                    HStack(spacing: 10) {
                        ProgressView().tint(Theme.gold).scaleEffect(0.8)
                        Text(liveTaskText).font(.footnote).bold().foregroundColor(Theme.gold)
                            .lineLimit(1).truncationMode(.tail)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Connection + model status
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle().fill(app.connected ? Theme.green : Theme.red).frame(width: 9, height: 9)
                        Text(app.connected ? "Coordinator connected" : "Coordinator unreachable — set URL in Settings")
                            .font(.footnote).foregroundColor(app.connected ? Theme.muted : Theme.red)
                        Spacer()
                    }
                    if app.nvpEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "point.3.connected.trianglepath.dotted").foregroundColor(Theme.gold)
                            Text("NVP Protocol ON — answers split across devices (torrent-style)")
                                .font(.caption2).foregroundColor(Theme.gold)
                            Spacer()
                        }
                    }
                    Divider().background(Color.white.opacity(0.06))
                    if app.nvpBetaOn { nvpStatus } else { localModelStatus }
                }
                .card()

                // Stats grid
                HStack(spacing: 12) {
                    StatCard(icon: "tray.full.fill", label: "Jobs today", value: "\(app.jobsToday)")
                    StatCard(icon: "speedometer", label: "Speed", value: String(format: "%.0f tok/s", app.tokensPerSec))
                }
                HStack(spacing: 12) {
                    StatCard(icon: "line.3.horizontal.decrease.circle.fill", label: "Queue", value: "\(app.queueDepth)")
                    StatCard(icon: "timer", label: "Last latency", value: "\(app.lastLatencyMs) ms")
                }
                HStack(spacing: 12) {
                    StatCard(icon: "bolt.batteryblock.fill", label: "Charging", value: app.deviceState.isCharging ? "Yes" : "No")
                    StatCard(icon: "thermometer.medium", label: "Thermal", value: thermalLabel)
                }

                if let err = app.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.red)
                        Text(err).font(.caption).foregroundColor(Theme.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
            }
            .padding()
        }
    }

    // Local (single-device) model status — shown only when NVP mode is OFF.
    private var localModelStatus: some View {
        let installed = ModelStore.isInstalled(Config.effectiveModelId)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: installed ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundColor(installed ? Theme.green : Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Config.effectiveModelId).font(.subheadline)
                        .foregroundColor(installed ? Theme.green : Theme.text)
                    if app.isPreloading {
                        Text(app.loadingIntoMemory
                             ? "Loading into memory… (1-2 min)"
                             : String(format: "%.0f / %.0f MB · %.1f MB/s", app.downloadMB, app.downloadTotalMB, app.downloadSpeedMBs))
                            .font(.caption2).foregroundColor(Theme.muted)
                    } else if installed {
                        Text(String(format: "Downloaded ✓ · %.1f GB", ModelStore.sizeOnDiskGB(Config.effectiveModelId)))
                            .font(.caption2).foregroundColor(Theme.green)
                    } else {
                        Text("Not downloaded").font(.caption2).foregroundColor(Theme.muted)
                    }
                }
                Spacer()
                if !app.isPreloading {
                    Button(installed ? "Launch" : "Download") { app.preloadModel(Config.workerModelId) }
                        .font(.footnote).bold().foregroundColor(Theme.onAccent)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(installed ? Theme.green : Theme.accent).clipShape(Capsule())
                }
            }
            if app.isPreloading {
                ProgressView(value: app.loadingIntoMemory ? 1 : app.loadProgress).tint(Theme.gold)
            }
            // Image generation is additive — show it as a second capability.
            if app.imageGenOn {
                Divider().background(Color.white.opacity(0.06))
                HStack(spacing: 10) {
                    Image(systemName: app.imageInstalled ? "photo.fill" : "arrow.down.circle")
                        .foregroundColor(app.imageInstalled ? Theme.green : Theme.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🎨 \(Config.displayName(for: Config.effectiveImageModelId))")
                            .font(.subheadline).foregroundColor(app.imageInstalled ? Theme.green : Theme.text)
                        Text(app.imageDownloading
                             ? String(format: "Téléchargement… %.0f%%", app.imageProgress * 100)
                             : app.imageInstalled ? "Modèle d'image prêt ✓" : "Modèle d'image non téléchargé")
                            .font(.caption2).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    if !app.imageDownloading && !app.imageInstalled {
                        Button("Télécharger") { app.downloadImageModel() }
                            .font(.footnote).bold().foregroundColor(Theme.onAccent)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Theme.accent).clipShape(Capsule())
                    }
                }
                if app.imageDownloading { ProgressView(value: app.imageProgress).tint(Theme.gold) }
            }
        }
    }

    // NVP-D mode status — distributed only; local model is disabled.
    private var nvpStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted").foregroundColor(Theme.gold)
                Text("Mode NVP-D actif").font(.subheadline).bold().foregroundColor(Theme.gold)
                Spacer()
                Text("Modèle local désactivé").font(.caption2).foregroundColor(Theme.muted)
            }
            HStack(spacing: 10) {
                nvpMetric("\(app.nvpPowerTops)", "TOPS")
                nvpMetric(String(format: "%.0f", Config.deviceRamGB), "GB RAM")
                nvpMetric("\(app.nexusPeerCount)", "pairs")
                nvpMetric("\(app.nvpServedModels.count)", "modèles")
            }
            Text("Le worker sert et exécute uniquement des shards NVP-D.")
                .font(.caption2).foregroundColor(Theme.muted)
            Button { showNVP = true } label: {
                HStack { Image(systemName: "rectangle.3.group.fill"); Text("Ouvrir NVP Beta") }
                    .font(.subheadline).bold().foregroundColor(Theme.onAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Theme.gold).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func nvpMetric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundColor(Theme.text)
            Text(label).font(.caption2).foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // Friendly label for the current live task (OpenClaw instance, image, chat).
    private var liveTaskText: String {
        let s = app.status
        if s.hasPrefix("Running OpenClaw") || s.hasPrefix("Generating") || s.lowercased().contains("image") { return s }
        return "Traitement d'une requête…"
    }

    private var thermalLabel: String {
        switch app.deviceState.thermal {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "—"
        }
    }
}

private struct StatusPill: View {
    let live: Bool
    let text: String
    @State private var blink = false
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(live ? Theme.green : Theme.muted).frame(width: 8, height: 8)
                .opacity(live && blink ? 0.35 : 1)
                .shadow(color: live ? Theme.green : .clear, radius: live ? 4 : 0)
            Text(live ? "LIVE" : text.uppercased())
                .font(.caption2).bold()
                .foregroundColor(live ? Theme.green : Theme.muted)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background((live ? Theme.green : Theme.muted).opacity(0.12))
        .clipShape(Capsule())
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { blink = true } }
    }
}

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.accent.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).foregroundColor(Theme.gold).font(.subheadline)
            }
            Text(value).font(.title3).bold().foregroundColor(Theme.text)
                .contentTransition(.numericText())
            Text(label).font(.caption2).foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
