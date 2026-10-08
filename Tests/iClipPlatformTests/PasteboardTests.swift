import AppKit
import Testing
import iClipCore
import iClipPlatform

@MainActor
private func withPasteboard(_ body: (NSPasteboard) throws -> Void) rethrows {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    try body(pasteboard)
}

@Test @MainActor func textPasteboardRoundTrip() throws {
    try withPasteboard { board in
        #expect(PasteboardBridge.write(ClipboardEntry(text: "  hello\nworld  "), to: board))
        let entry = try #require(PasteboardBridge.read(from: board))
        #expect(entry.kind == .text)
        #expect(entry.text == "  hello\nworld  ")
    }
}

@Test @MainActor func fileURLsRoundTripWithoutTextConversion() throws {
    try withPasteboard { board in
        let paths = ["/tmp/iClip test 文件.txt", "/tmp/second.png"]
        let files = ClipboardEntry(text: paths.joined(separator: "\n"), kind: .files, filePaths: paths)
        #expect(PasteboardBridge.write(files, to: board))
        let entry = try #require(PasteboardBridge.read(from: board))
        #expect(entry.kind == .files)
        #expect(entry.filePaths == paths)
        #expect(board.types?.contains(.fileURL) == true)
    }
}

@Test @MainActor func pngAndTIFFRoundTrip() throws {
    try withPasteboard { board in
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for format in [NSBitmapImageRep.FileType.png, .tiff] {
            let data = try #require(bitmap.representation(using: format, properties: [:]))
            let image = ClipboardEntry(text: "图片", kind: .image, imageData: data)
            #expect(PasteboardBridge.write(image, to: board))
            let result = try #require(PasteboardBridge.read(from: board))
            #expect(result.kind == .image)
            #expect(result.imageData == data)
            #expect(NSImage(pasteboard: board) != nil)
        }
    }
}

@Test @MainActor func concealedClipboardIsIgnored() {
    withPasteboard { board in
        board.clearContents()
        board.setString("private", forType: .string)
        board.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        #expect(PasteboardBridge.read(from: board) == nil)
    }
}

@Test @MainActor func invalidPayloadDoesNotClearClipboard() {
    withPasteboard { board in
        board.clearContents()
        board.setString("keep", forType: .string)
        let invalid = ClipboardEntry(text: "图片", kind: .image)
        #expect(!PasteboardBridge.write(invalid, to: board))
        #expect(board.string(forType: .string) == "keep")
    }
}
