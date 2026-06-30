import SwiftUI

/// NVP OS (beta) — a simulated, iOS-like desktop that runs INSIDE the worker app.
/// Because iOS suspends background apps, staying inside NVP keeps the worker
/// earning; NVP OS makes that pleasant: native NVP apps + web-app tiles, all in
/// one fluid touch interface. No real OS/Linux — pure SwiftUI.
struct NVPOSView: View {
    @EnvironmentObject var app: AppState
    var onExit: () -> Void

    @State private var openApp: OSApp? = nil
    @State private var showSoon: OSApp? = nil
    @State private var locked = false
    @Namespace private var ns

    private let apps = OSApp.catalog
    private var dock: [OSApp] { Array(apps.prefix(4)) }
    private var grid: [OSApp] { Array(apps.dropFirst(4)) }
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 22), count: 4)

    var body: some View {
        ZStack {
            wallpaper.ignoresSafeArea()

            VStack(spacing: 0) {
                statusBar
                workerWidget
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 22) {
                        ForEach(grid) { a in iconButton(a) }
                    }
                    .padding(.horizontal, 22).padding(.top, 18)
                }
                dockBar
            }

            // App window (zoom-in transition).
            if let a = openApp {
                appWindow(a)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(2)
            }

            // Simulated lock screen (pocket-safe: double-tap then swipe up).
            if locked {
                LockScreenView(onUnlock: { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { locked = false } })
                    .environmentObject(app)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(item: $showSoon) { a in SoonSheet(appName: a.name) }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: openApp)
    }

    // MARK: Wallpaper
    private var wallpaper: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.10, blue: 0.09), Color(red: 0.02, green: 0.05, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
            Circle().fill(Theme.accent.opacity(0.16)).frame(width: 360).blur(radius: 90).offset(x: -120, y: -260)
            Circle().fill(Theme.gold.opacity(0.14)).frame(width: 320).blur(radius: 90).offset(x: 140, y: 320)
        }
    }

    // MARK: Status bar
    private var statusBar: some View {
        HStack(spacing: 8) {
            Text(Date.now, style: .time).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.white)
            Text("NVP OS").font(.caption2.bold()).foregroundColor(Theme.accent)
            Text("bêta").font(.system(size: 9, weight: .bold)).foregroundColor(Theme.onAccent)
                .padding(.horizontal, 5).padding(.vertical, 1).background(Theme.accent).clipShape(Capsule())
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(app.isWorker ? Theme.green : Theme.muted).frame(width: 7, height: 7)
                Text(app.isWorker ? "actif" : "off").font(.caption2).foregroundColor(.white.opacity(0.8))
            }
            Image(systemName: "wifi").font(.caption2).foregroundColor(.white.opacity(0.8))
            Image(systemName: "battery.100").font(.caption2).foregroundColor(.white.opacity(0.8))
            Button { withAnimation(.easeIn(duration: 0.25)) { locked = true } } label: {
                Image(systemName: "lock.fill").font(.system(size: 15)).foregroundColor(.white.opacity(0.7))
            }
            Button { onExit() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundColor(.white.opacity(0.55)) }
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
    }

    // MARK: Worker widget (start/stop + live)
    private var workerWidget: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(app.isWorker ? Theme.green.opacity(0.18) : Color.white.opacity(0.06)).frame(width: 44, height: 44)
                Image(systemName: "bolt.fill").foregroundColor(app.isWorker ? Theme.green : Theme.muted)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(app.isWorker ? "Worker actif — tu gagnes" : "Worker en pause").font(.subheadline.bold()).foregroundColor(.white)
                Text(String(format: "+%@ aujourd'hui · %d jobs", Format.usd(app.creditsToday), app.jobsToday))
                    .font(.caption2).foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Toggle("", isOn: Binding(get: { app.isWorker }, set: { app.setWorker($0) })).labelsHidden().tint(Theme.green)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: Icons
    private func iconButton(_ a: OSApp) -> some View {
        Button { open(a) } label: {
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: a.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: a.icon).font(.system(size: 26, weight: .semibold)).foregroundColor(.white))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                Text(a.name).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.92)).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var dockBar: some View {
        HStack(spacing: 26) {
            ForEach(dock) { a in iconButton(a) }
        }
        .padding(.vertical, 12).padding(.horizontal, 18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    private func open(_ a: OSApp) {
        switch a.kind {
        case .soon: showSoon = a
        default: openApp = a
        }
    }

    // MARK: App window
    private func appWindow(_ a: OSApp) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: a.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: a.icon).font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                Text(a.name).font(.subheadline.bold()).foregroundColor(Theme.text)
                Spacer()
                Button { openApp = nil } label: {
                    Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.muted)
                        .frame(width: 30, height: 30).background(Theme.elev2).clipShape(Circle())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.elev)

            Divider().background(Theme.border)

            content(for: a).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(8)
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder private func content(for a: OSApp) -> some View {
        switch a.kind {
        case .native(let id):
            nativeApp(id)
        case .web(let urlString):
            if let url = URL(string: urlString) { WebApp(url: url) } else { errorView }
        case .soon:
            SoonSheet(appName: a.name)
        }
    }

    @ViewBuilder private func nativeApp(_ id: String) -> some View {
        switch id {
        case "worker": WorkerView()
        case "wallet": WalletView()
        case "network": NetworkView()
        case "earnings": EarningsView()
        case "logs": LogsView()
        case "settings": SettingsView()
        default: errorView
        }
    }

    private var errorView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.title).foregroundColor(Theme.muted)
            Text("Indisponible").foregroundColor(Theme.muted)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
    }
}

/// A web-app window with a thin loading bar.
private struct WebApp: View {
    let url: URL
    @State private var progress: Double = 0
    var body: some View {
        ZStack(alignment: .top) {
            WebAppView(url: url, onProgress: { progress = $0 })
            if progress < 1 {
                ProgressView(value: progress).tint(Theme.accent).scaleEffect(x: 1, y: 0.6, anchor: .top)
            }
        }
    }
}

/// "Coming soon" restriction sheet (apple sandbox limits).
private struct SoonSheet: View {
    let appName: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundColor(Theme.gold)
            Text(appName).font(.title3.bold()).foregroundColor(Theme.text)
            Text("À cause des restrictions d'Apple sur iPhone, il est impossible de faire tourner toutes les applications à l'intérieur de NVP OS pour le moment. L'équipe travaille activement pour en ajouter dans la prochaine version.")
                .font(.callout).foregroundColor(Theme.muted).multilineTextAlignment(.center)
            Text("NVP OS · bêta").font(.caption2).foregroundColor(Theme.accent)
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
    }
}
