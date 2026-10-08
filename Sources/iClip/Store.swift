import AppKit
import SwiftUI
import ServiceManagement
import iClipCore
import iClipPlatform

@MainActor
final class Store: ObservableObject {
    @Published private(set) var history = HistoryState()
    @Published var shortcut: Shortcut
    @Published var error: String?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var ready = false
    private let disk = DispatchQueue(label: "iClip.persistence", qos: .utility)
    private let persistence: Persistence
    private var timer: Timer?
    private var changeCount: Int
    private var ignoredChange: Int?
    private var persistenceHealthy = true
    let hotKey = HotKey()

    init() {
        shortcut = UserDefaults.standard.data(forKey: "shortcut")
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? Shortcut()
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iClip", isDirectory: true)
        persistence = Persistence(url: directory.appendingPathComponent("history.json"))
        changeCount = NSPasteboard.general.changeCount
        let persistence = self.persistence
        disk.async {
            let result = Result { try persistence.load() }
            DispatchQueue.main.async {
                switch result {
                case .success(let state): self.history = state
                case .failure(let error):
                    self.persistenceHealthy = false
                    self.error = "读取历史失败：\(error.localizedDescription)。为保护原文件，当前暂停保存，请备份并修复历史文件后重启。"
                }
                self.ready = true
                self.startMonitoring()
            }
        }
        if !hotKey.register(shortcut) { error = "全局快捷键注册失败，请在设置中选择其他组合。" }
    }

    private func startMonitoring() {
        captureCurrent()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let count = NSPasteboard.general.changeCount
                guard count != self.changeCount else { return }
                self.changeCount = count
                guard count != self.ignoredChange else { return }
                self.captureCurrent()
            }
        }
        timer?.tolerance = 0.15
    }

    private func captureCurrent() {
        guard let entry = PasteboardBridge.read(from: .general) else { return }
        switch entry.kind {
        case .text: history.capture(entry.text)
        case .files: history.captureFiles(entry.filePaths)
        case .image:
            if let data = entry.imageData { history.captureImage(data) }
        }
        save()
    }

    @discardableResult
    func copy(_ entry: ClipboardEntry) -> Bool {
        guard PasteboardBridge.write(entry, to: .general) else {
            error = "无法将该条目写入剪贴板。"
            return false
        }
        ignoredChange = NSPasteboard.general.changeCount
        changeCount = NSPasteboard.general.changeCount
        return true
    }
    func pin(_ entry: ClipboardEntry) { history.togglePin(entry.id); save() }
    func remove(_ entry: ClipboardEntry) { history.remove(entry.id); save() }
    func clear() { history.clearUnpinned(); save() }
    func setHistoryLimit(_ limit: Int) {
        guard ready else { return }
        history.limit = max(0, limit)
        save()
    }

    private func save() {
        guard persistenceHealthy else { return }
        let state = history
        let persistence = self.persistence
        disk.async {
            do { try persistence.save(state) }
            catch { DispatchQueue.main.async { self.error = "保存历史失败：\(error.localizedDescription)" } }
        }
    }

    func finishSaving(_ completion: @escaping @MainActor @Sendable () -> Void) {
        timer?.invalidate()
        timer = nil
        // A barrier on the serial persistence queue waits for every submitted save
        // without blocking the main thread during application termination.
        disk.async { DispatchQueue.main.async { completion() } }
    }

    func setShortcut(_ value: Shortcut) {
        guard value != shortcut else { return }
        guard hotKey.register(value) else { error = "该快捷键已被占用，请选择其他组合。"; return }
        shortcut = value
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: "shortcut")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                error = "请在系统设置 → 通用 → 登录项中允许 iClip。"
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { self.error = "修改开机启动失败：\(error.localizedDescription)" }
    }
}
