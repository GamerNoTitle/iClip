import AppKit
@preconcurrency import ApplicationServices
import SwiftUI

/// A temporary companion window, not an overlay injected into System Settings.
@MainActor
final class PermissionGuidance {
    static let shared = PermissionGuidance()
    private var panel: NSPanel?
    private var timer: Timer?
    private var startedAt = Date()

    func show() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        hide()
        startedAt = .now
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 470, height: 154),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PermissionGuidanceView(close: { [weak self] in self?.hide() }))
        self.panel = panel
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        update()
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func update() {
        guard let panel else { return }
        // Tracking never runs indefinitely if the user leaves the onboarding unfinished.
        guard !AXIsProcessTrusted(), Date().timeIntervalSince(startedAt) < 300 else {
            hide()
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == "com.apple.systempreferences" else {
            panel.orderOut(nil)
            return
        }
        let window = settingsWindow(pid: app.processIdentifier)
        let screen = window.flatMap { bounds in
            NSScreen.screens.max { intersectionArea($0.frame, bounds) < intersectionArea($1.frame, bounds) }
        } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let bounds = window ?? visible
        let size = panel.frame.size
        let x = min(max(bounds.midX + min(100, bounds.width * 0.1) - size.width / 2, visible.minX + 12),
                    max(visible.minX + 12, visible.maxX - size.width - 12))
        let y = min(max(bounds.minY - size.height + 6, visible.minY + 12),
                    max(visible.minY + 12, visible.maxY - size.height - 12))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }

    private func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let overlap = a.intersection(b)
        return overlap.isNull ? 0 : overlap.width * overlap.height
    }

    private func settingsWindow(pid: pid_t) -> CGRect? {
        // Window metadata only: no screenshots, AX inspection, or extra permission request.
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]],
              let primary = NSScreen.screens.first else { return nil }
        return windows.compactMap { info -> CGRect? in
            guard (info[kCGWindowOwnerPID as String] as? Int) == Int(pid),
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let dictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dictionary),
                  rect.width > 300, rect.height > 200 else { return nil }
            return CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
        }.max { $0.width * $0.height < $1.width * $1.height }
    }
}

private struct PermissionGuidanceView: View {
    let close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up").font(.title2.bold()).foregroundStyle(.blue)
                Text("将 iClip 拖入上方列表，再开启开关").font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help("关闭引导").accessibilityLabel("关闭引导")
            }
            AppDragTile().frame(height: 44)
            Text("已开启但未生效？请退出并重新打开 iClip。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 470, height: 154)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.separator.opacity(0.5), lineWidth: 0.5))
    }
}

private struct AppDragTile: NSViewRepresentable {
    func makeNSView(context: Context) -> AppDragView { AppDragView() }
    func updateNSView(_ nsView: AppDragView, context: Context) {}
}

private final class AppDragView: NSView, NSDraggingSource {
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "iClip")

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        icon.image = NSWorkspace.shared.icon(forFile: Bundle.main.bundleURL.path)
        icon.imageScaling = .scaleProportionallyUpOrDown
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .labelColor
        for view in [icon, title] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.setAccessibilityElement(false)
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 30), icon.heightAnchor.constraint(equalToConstant: 30),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setAccessibilityElement(true)
        setAccessibilityLabel("iClip 应用，可拖入辅助功能列表")
        toolTip = Bundle.main.bundleURL.path
    }

    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }
    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: Bundle.main.bundleURL as NSURL)
        item.setDraggingFrame(NSRect(x: 10, y: 7, width: 30, height: 30), contents: icon.image)
        beginDraggingSession(with: [item], event: event, source: self)
            .animatesToStartingPositionsOnCancelOrFail = true
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
