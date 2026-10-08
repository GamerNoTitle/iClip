import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32 = 9
    var modifiers: UInt32 = UInt32(controlKey | shiftKey)
    var label: String = "V"

    var display: String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") +
        (modifiers & UInt32(optionKey) != 0 ? "⌥" : "") +
        (modifiers & UInt32(shiftKey) != 0 ? "⇧" : "") +
        (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "") + label
    }
}

@MainActor
final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(pointer).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.action?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func register(_ shortcut: Shortcut) -> Bool {
        // Register first so an unavailable replacement does not destroy the working shortcut.
        var next: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: 0x69436C70, id: 1), GetApplicationEventTarget(), 0, &next)
        guard status == noErr else { return false }
        if let reference { UnregisterEventHotKey(reference) }
        reference = next
        return true
    }
}

final class ShortcutRecorderView: NSView {
    var onRecord: ((Shortcut) -> Void)?
    var onCancel: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        keyDown(with: event)
        return true
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            onCancel?()
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.control) || flags.contains(.command) || flags.contains(.option),
              let label = event.charactersIgnoringModifiers?.uppercased(), !label.isEmpty,
              event.keyCode != 48, event.keyCode != 36 else { NSSound.beep(); return }
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        onRecord?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label))
        window?.makeFirstResponder(nil)
    }
}
