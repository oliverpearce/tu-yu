//
//  ScreenshotStage.swift
//  to-you.
//
//  DEBUG-only: stages the real UI on a flat 1280×800 pt backdrop for App Store screenshots.
//  Launch with `-screenshotScene <scene>`; appstore-to-you/tools/capture.sh drives it and
//  captures the backdrop with `screencapture -R100,100,1280,800` (2560×1600 px on Retina).

#if DEBUG
import AppKit
import SwiftUI

enum ScreenshotScene: String {
    case popoverLight, hudWhite, popoverDark, settingsDark, hudSnowDark

    var isDark: Bool { self == .popoverDark || self == .settingsDark || self == .hudSnowDark }
}

final class ScreenshotStageController {
    static let stageSize = CGSize(width: 1280, height: 800)
    static let stageTopLeft = CGPoint(x: 100, y: 100)   // global, top-left origin — must match capture.sh

    private var windows: [NSWindow] = []

    func present(scene: ScreenshotScene, model: AppModel) {
        NSApp.appearance = NSAppearance(named: scene.isDark ? .darkAqua : .aqua)

        switch scene {
        case .popoverLight: model.debugFreeze(total: 25 * 60, left: 18 * 60 + 42, running: true)
        case .hudWhite, .hudSnowDark: model.debugFreeze(total: 25 * 60, left: 18 * 60 + 42, running: true)
        case .popoverDark, .settingsDark: model.debugFreeze(total: 25 * 60, left: 25 * 60, running: false)
        }

        let stage = NSWindow(contentRect: stageFrame(), styleMask: [.borderless], backing: .buffered, defer: false)
        stage.level = .floating
        stage.isOpaque = true
        stage.ignoresMouseEvents = true   // keeps hover controls/highlights out of the shot
        stage.backgroundColor = scene.isDark ? .black : .white
        stage.contentView = NSHostingView(rootView: StageView(scene: scene, model: model))
        stage.setFrame(stageFrame(), display: true)
        stage.orderFrontRegardless()
        windows.append(stage)

        if scene == .settingsDark { presentSettings(over: stage) }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func stageFrame() -> NSRect {
        let screen = NSScreen.screens[0].frame   // the screen with the menu bar; global coords start here
        return NSRect(x: screen.minX + Self.stageTopLeft.x,
                      y: screen.maxY - Self.stageTopLeft.y - Self.stageSize.height,
                      width: Self.stageSize.width, height: Self.stageSize.height)
    }

    // Real titled window at 1× — SettingsView is full of AppKit controls that would blur if scaled.
    private func presentSettings(over stage: NSWindow) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Settings"
        w.isReleasedWhenClosed = false
        w.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        // Lilac to match the app icon, instead of whatever accent colour this Mac uses
        let lilac = Color(red: 0xC8 / 255, green: 0xA2 / 255, blue: 0xE8 / 255)
        w.contentView = NSHostingView(rootView: SettingsView().tint(lilac))
        w.layoutIfNeeded()
        let s = stage.frame
        w.setFrameOrigin(NSPoint(x: s.midX - w.frame.width / 2, y: s.midY - w.frame.height / 2))
        w.makeKeyAndOrderFront(nil)
        windows.append(w)
    }
}

private struct StageView: View {
    let scene: ScreenshotScene
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            (scene.isDark ? Color.black : Color.white)
            switch scene {
            case .popoverLight, .popoverDark:
                menuBarPill
                    .scaleEffect(2.5, anchor: .topLeading)
                    .offset(x: 258, y: 98)
                popoverCard
                    .scaleEffect(2.5, anchor: .topLeading)
                    .offset(x: 258, y: 186)
            case .hudWhite:
                hud(dark: true)
                    .scaleEffect(1.9, anchor: .topLeading)
                    .offset(x: 719, y: 187)
            case .hudSnowDark:
                hud(dark: false)
                    .scaleEffect(1.9, anchor: .topLeading)
                    .offset(x: 719, y: 187)
            case .settingsDark:
                EmptyView()   // the real Settings window sits on top
            }
        }
        .frame(width: ScreenshotStageController.stageSize.width,
               height: ScreenshotStageController.stageSize.height, alignment: .topLeading)
    }

    // Mirrors the status item: umbrella.fill + time while running, plain umbrella when idle.
    private var menuBarPill: some View {
        HStack(spacing: 4) {
            Image(systemName: model.isRunning ? "umbrella.fill" : "umbrella")
                .font(.system(size: 13, weight: .medium))
            if model.isRunning {
                Text(model.formatted(model.secondsLeft))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(Color.primary.opacity(scene.isDark ? 0.16 : 0.09), in: RoundedRectangle(cornerRadius: 6))
    }

    private var popoverCard: some View {
        TimerPopoverView(model: model, openSettings: {}, closePopover: {}, toggleHUD: {})
            .frame(width: 320, height: 168)
            .background {   // shadow on the card shape only, so text doesn't cast its own shadow
                RoundedRectangle(cornerRadius: 14)
                    .fill(scene.isDark ? Color(white: 0.06) : Color(white: 0.97))
                    .shadow(color: .black.opacity(scene.isDark ? 0.5 : 0.16), radius: 12, y: 5)
            }
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(scene.isDark ? 0.22 : 0.12), lineWidth: 0.5))
    }

    private func hud(dark: Bool) -> some View {
        HUDTimerView(model: model, onClose: {}, openSettings: {})
            .frame(width: HUDSize.compact.panelSize.width, height: HUDSize.compact.panelSize.height)
            .environment(\.colorScheme, dark ? .dark : .light)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(dark ? 0.12 : 0.0), lineWidth: 0.5))
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(scene.isDark ? 0.5 : 0.22), radius: 10, y: 5)
            }
    }
}
#endif
