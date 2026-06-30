import SwiftUI
import UIKit

/// Simulated lock screen for NVP OS. Dims the screen to the minimum and shows a
/// clock + worker status. Pocket-safe unlock: **double-tap, then swipe up** —
/// so it never unlocks or taps by itself while in a pocket. The worker keeps
/// running (we stay in the app, screen on but dark).
struct LockScreenView: View {
    @EnvironmentObject var app: AppState
    var onUnlock: () -> Void

    @State private var armed = false
    @State private var dragY: CGFloat = 0
    @State private var prevBrightness: CGFloat = UIScreen.main.brightness
    @State private var disarmWork: DispatchWorkItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 6) {
                Spacer().frame(height: 70)
                Image(systemName: armed ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 22)).foregroundColor(.white.opacity(0.55))
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    VStack(spacing: 2) {
                        Text(ctx.date, style: .time)
                            .font(.system(size: 76, weight: .thin, design: .rounded))
                            .foregroundColor(.white.opacity(0.92)).monospacedDigit()
                        Text(ctx.date, style: .date).font(.callout).foregroundColor(.white.opacity(0.55))
                    }
                }
                Spacer()

                // Worker status card
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(app.isWorker ? Theme.green.opacity(0.22) : Color.white.opacity(0.06)).frame(width: 42, height: 42)
                        Image(systemName: "bolt.fill").foregroundColor(app.isWorker ? Theme.green : .white.opacity(0.4))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.isWorker ? "NVP Worker actif" : "Worker en pause")
                            .font(.subheadline.bold()).foregroundColor(.white.opacity(0.9))
                        Text(String(format: "+%@ aujourd'hui · %d jobs", Format.usd(app.creditsToday), app.jobsToday))
                            .font(.caption2).foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 24)

                // Unlock hint
                VStack(spacing: 8) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(armed ? 0.9 : 0.3))
                        .offset(y: armed ? -4 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: armed)
                    Text(armed ? "Glissez vers le haut pour déverrouiller" : "Touchez deux fois puis glissez")
                        .font(.caption).foregroundColor(.white.opacity(armed ? 0.75 : 0.4))
                }
                .padding(.bottom, 40)
            }
            .offset(y: dragY)
        }
        .contentShape(Rectangle())
        // Single taps do nothing (pocket-safe). Double-tap "arms" the unlock.
        .onTapGesture(count: 2) { arm() }
        .gesture(
            DragGesture()
                .onChanged { v in if armed && v.translation.height < 0 { dragY = v.translation.height } }
                .onEnded { v in
                    if armed && v.translation.height < -90 { unlock() }
                    else { withAnimation(.spring()) { dragY = 0 } }
                }
        )
        .onAppear {
            prevBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 0.0
        }
        .onDisappear { UIScreen.main.brightness = prevBrightness }
    }

    private func arm() {
        withAnimation(.easeOut(duration: 0.2)) { armed = true }
        disarmWork?.cancel()
        let w = DispatchWorkItem { withAnimation { armed = false; dragY = 0 } }
        disarmWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: w)
    }

    private func unlock() {
        UIScreen.main.brightness = prevBrightness
        onUnlock()
    }
}
