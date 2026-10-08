import SwiftUI
import AppKit
@preconcurrency import ApplicationServices
import iClipCore

struct ClipboardView: View {
    @ObservedObject var store: Store
    let select: (ClipboardEntry) -> Void
    let dismiss: () -> Void
    let settings: () -> Void
    @State private var query = ""
    @State private var selected: UUID?
    @FocusState private var searchFocused: Bool

    private var entries: [ClipboardEntry] {
        store.history.entries.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clipboard.fill").foregroundStyle(.tint)
                Text("iClip").font(.headline)
                Spacer()
                Text(store.shortcut.display).font(.caption).foregroundStyle(.secondary)
                Button(action: settings) { Image(systemName: "gearshape") }.buttonStyle(.plain).help("设置")
            }.padding(16)
            TextField("搜索剪贴板", text: $query)
                .textFieldStyle(.roundedBorder).focused($searchFocused)
                .padding(.horizontal, 14).padding(.bottom, 12)
            Divider()
            if !store.ready {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: query.isEmpty ? "clipboard" : "magnifyingglass").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text(query.isEmpty ? "复制文字、文件或图片，历史会出现在这里" : "没有匹配的内容").foregroundStyle(.secondary)
                    Text("置顶内容会保留；密码管理器标记的内容不记录。")
                        .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(entries) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Button { select(entry) } label: {
                                        VStack(alignment: .leading, spacing: 7) {
                                            if entry.kind == .image, let data = entry.imageData {
                                                ImagePreview(data: data)
                                            } else {
                                                HStack(alignment: .top, spacing: 6) {
                                                    if entry.kind == .files {
                                                        Text("文件").font(.system(size: 10, weight: .medium))
                                                            .padding(.horizontal, 6).padding(.vertical, 3)
                                                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                                                    }
                                                    Text(String(entry.text.prefix(600))).font(.system(size: 13))
                                                        .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                            HStack(spacing: 5) {
                                                if entry.isPinned { Image(systemName: "pin.fill").foregroundStyle(.tint) }
                                                EntryAgeView(date: entry.createdAt)
                                                Spacer()
                                                switch entry.kind {
                                                case .text: Text("\(entry.text.count) 字符")
                                                case .files: Text("\(entry.filePaths.count) 个文件")
                                                case .image: Text("图片")
                                                }
                                            }.font(.system(size: 10)).foregroundStyle(.secondary)
                                        }.contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                    VStack(spacing: 12) {
                                        Button { store.pin(entry) } label: {
                                            Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                                        }.help(entry.isPinned ? "取消置顶" : "永久置顶")
                                        Button { store.remove(entry) } label: { Image(systemName: "xmark") }.help("删除")
                                    }.buttonStyle(.plain).foregroundStyle(.secondary).font(.system(size: 11))
                                }
                                .padding(12)
                                .background(selected == entry.id ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected == entry.id ? Color.accentColor.opacity(0.5) : .clear))
                                .id(entry.id)
                            }
                        }.padding(10)
                    }
                    .onChange(of: selected) { _, value in
                        if let value { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(value) } }
                    }
                }
            }
            Divider()
            HStack {
                Text("↑↓ 选择 · 回车粘贴 · Esc 关闭")
                Spacer()
                Text("\(entries.count) 条")
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(12)
        }
        .frame(width: 380, height: 510)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 22).fill(.clear).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
            } else {
                RoundedRectangle(cornerRadius: 22).fill(.regularMaterial)
            }
        }
        .onAppear { searchFocused = true; selected = entries.first?.id }
        .onChange(of: query) { _, _ in selected = entries.first?.id }
        .onChange(of: entries.map(\.id)) { _, ids in
            if selected == nil || !ids.contains(selected!) { selected = ids.first }
        }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.return) {
            if let item = entries.first(where: { $0.id == selected }) ?? entries.first { select(item) }
            return .handled
        }
        .onExitCommand(perform: dismiss)
    }

    private func move(_ delta: Int) {
        guard !entries.isEmpty else { return }
        let index = entries.firstIndex { $0.id == selected } ?? 0
        selected = entries[min(max(index + delta, 0), entries.count - 1)].id
    }
}

struct Recorder: NSViewRepresentable {
    let onRecord: (Shortcut) -> Void
    let onCancel: () -> Void
    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.onRecord = onRecord
        view.onCancel = onCancel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.onRecord = onRecord
        nsView.onCancel = onCancel
    }
}

struct SettingsView: View {
    @ObservedObject var store: Store
    @State private var recording = false
    @State private var confirmClear = false
    @State private var limitDraft = "1000"
    @State private var limitError: String?
    @State private var pendingLimit: Int?
    @State private var confirmLimit = false
    @State private var accessibilityGranted = AXIsProcessTrusted()
    var body: some View {
        Form {
            Section("通用") {
                HStack {
                    Text("打开剪贴板")
                    Spacer()
                    Button(recording ? "请按组合键（Esc 取消）" : store.shortcut.display) { recording.toggle() }
                        .overlay {
                            if recording {
                                Recorder(onRecord: { value in store.setShortcut(value); recording = false },
                                         onCancel: { recording = false }).frame(width: 1, height: 1)
                            }
                        }
                    Button("还原") { store.setShortcut(Shortcut()); recording = false }
                }
                Text("组合键必须包含 Control、Option 或 Command。").font(.caption).foregroundStyle(.secondary)
                Toggle("开机启动", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
                Toggle("显示菜单栏图标", isOn: $store.showMenuBarIcon)
                Text("隐藏图标后快捷键仍有效。再次打开 iClip 应用即可进入设置。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("退出 iClip") { NSApp.terminate(nil) }
            }
            Section("粘贴权限") {
                Text("自动粘贴需要辅助功能权限。未授权时，选择条目只复制内容，再按 ⌘V 即可粘贴。")
                    .font(.callout).foregroundStyle(.secondary)
                Label(accessibilityGranted ? "辅助功能已授权" : "当前进程未获得辅助功能授权",
                      systemImage: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(accessibilityGranted ? Color.green : Color.orange)
                if !accessibilityGranted {
                    Button("授权辅助功能") {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
                    }
                    Text("若系统设置中已开启权限，但这里仍未授权，请完整退出 iClip 后重新打开。更新临时签名的本地构建后，可能需要移除旧授权并重新添加当前应用。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("退出 iClip 以重新启动") { NSApp.terminate(nil) }
                }
            }
            Section("历史与隐私") {
                HStack {
                    TextField("保留条目数量", text: $limitDraft).onSubmit(applyLimit)
                    Button("应用", action: applyLimit).disabled(!store.ready)
                }
                if let limitError { Text(limitError).font(.caption).foregroundStyle(.red) }
                Text("默认保留 1000 条普通历史，0 表示无限制。降低数量会清除超出限制的普通历史，置顶不受限制。支持文字、文件引用与图片，保存在本机，不会联网或上传剪贴板。文件引用不备份文件本身。")
                    .font(.callout).foregroundStyle(.secondary)
                Button("清除未置顶历史…", role: .destructive) { confirmClear = true }
            }
            if let error = store.error {
                Section("提示") {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                    Button("关闭提示") { store.error = nil }
                }
            }
            Section {
                HStack {
                    Text("iClip · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Link(destination: URL(string: "https://github.com/GamerNoTitle/iClip")!) {
                        GitHubIcon().fill(.secondary).frame(width: 18, height: 18)
                            .padding(4).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("在 GitHub 查看 iClip")
                    .accessibilityLabel("在 GitHub 查看 iClip")
                }
            }
        }
        .formStyle(.grouped).frame(width: 520, height: 540)
        .onAppear {
            limitDraft = String(store.history.limit)
            store.refreshLaunchAtLogin()
            accessibilityGranted = AXIsProcessTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshLaunchAtLogin()
            accessibilityGranted = AXIsProcessTrusted()
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                accessibilityGranted = AXIsProcessTrusted()
            }
        }
        .onChange(of: store.ready) { _, ready in
            if ready { limitDraft = String(store.history.limit) }
        }
        .alert("降低保留数量？", isPresented: $confirmLimit) {
            Button("取消", role: .cancel) { pendingLimit = nil }
            Button("应用并删除旧历史", role: .destructive) {
                if let pendingLimit { store.setHistoryLimit(pendingLimit) }
                pendingLimit = nil
            }
        } message: {
            Text("超过新限制的普通历史将被永久删除，置顶内容不受影响。")
        }
        .confirmationDialog("清除所有未置顶历史？置顶内容不会被删除。", isPresented: $confirmClear) {
            Button("清除", role: .destructive) { store.clear() }
        }
    }

    private func applyLimit() {
        guard store.ready else { return }
        guard let value = Int(limitDraft.trimmingCharacters(in: .whitespacesAndNewlines)), value >= 0 else {
            limitError = "请输入非负整数；0 表示无限制。"
            return
        }
        limitError = nil
        limitDraft = String(value)
        let unpinnedCount = store.history.entries.filter { !$0.isPinned }.count
        if value > 0 && unpinnedCount > value {
            pendingLimit = value
            confirmLimit = true
        } else {
            store.setHistoryLimit(value)
        }
    }
}
