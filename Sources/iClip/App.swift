import AppKit
import SwiftUI
import Combine
import iClipCore

final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var store: Store!
    private var statusItem: NSStatusItem!
    private var panel: ClipboardPanel?
    private var settingsWindow: NSWindow?
    private var previousApp: NSRunningApplication?
    private var monitor: Any?
    private var pasteGeneration = UUID()
    private var menuBarSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store = Store()
        store.hotKey.action = { [weak self] in self?.togglePanel() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menuIcon = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "clipboard", accessibilityDescription: "iClip 剪贴板")
        menuIcon?.size = NSSize(width: 18, height: 18)
        menuIcon?.isTemplate = true
        statusItem.button?.image = menuIcon
        statusItem.button?.setAccessibilityLabel("iClip 剪贴板")
        let menu = NSMenu()
        menu.addItem(withTitle: "打开剪贴板", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "退出 iClip", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        menuBarSubscription = store.$showMenuBarIcon.sink { [weak self] visible in
            self?.statusItem.isVisible = visible
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hidePanel() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        hidePanel()
        openSettings()
        return false
    }

    @objc private func openPanel() { showPanel() }
    private func togglePanel() {
        if panel?.isVisible == true { hidePanel() } else { showPanel() }
    }
    private func showPanel() {
        pasteGeneration = UUID()
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        let panel = panel ?? makePanel()
        let hostingView = NSHostingView(rootView: ClipboardView(store: store,
            select: { [weak self] in self?.select($0) },
            dismiss: { [weak self] in self?.hidePanel() },
            settings: { [weak self] in self?.hidePanel(); self?.openSettings() }))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.cornerRadius = 22
        hostingView.layer?.masksToBounds = true
        hostingView.layer?.borderWidth = 0
        panel.contentView = hostingView
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let x = min(max(pointer.x - 190, frame.minX + 12), frame.maxX - 392)
            let y = min(max(pointer.y - 510, frame.minY + 12), frame.maxY - 522)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.makeKeyAndOrderFront(nil)
    }
    private func makePanel() -> ClipboardPanel {
        let result = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 510),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        result.level = .floating
        result.isOpaque = false
        result.backgroundColor = .clear
        result.hasShadow = false
        result.hidesOnDeactivate = false
        result.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        result.delegate = self
        panel = result
        return result
    }
    private func hidePanel() { panel?.orderOut(nil) }
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel { hidePanel() }
    }

    private func select(_ entry: ClipboardEntry) {
        pasteGeneration = UUID()
        let generation = pasteGeneration
        guard store.copy(entry) else { NSSound.beep(); return }
        hidePanel()
        guard AXIsProcessTrusted(), let target = previousApp, !target.isTerminated else { return }
        target.activate()
        // Wait for focus restoration and modifier release before synthesizing Command-V.
        pasteWhenReady(target, generation: generation, remaining: 12)
    }
    private func pasteWhenReady(_ target: NSRunningApplication, generation: UUID, remaining: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.pasteGeneration == generation, !target.isTerminated else { return }
            let flags = CGEventSource.flagsState(.combinedSessionState)
            let modifiers: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
            guard flags.intersection(modifiers).isEmpty,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
                if remaining > 0 { self.pasteWhenReady(target, generation: generation, remaining: remaining - 1) }
                return
            }
            guard let source = CGEventSource(stateID: .combinedSessionState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    @objc private func openSettings() {
        pasteGeneration = UUID()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 540),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "iClip 设置"
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        store.launchAtLogin = SMAppService.mainApp.status == .enabled
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        store.finishSaving { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

import ServiceManagement
@main
struct iClipApplication {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
