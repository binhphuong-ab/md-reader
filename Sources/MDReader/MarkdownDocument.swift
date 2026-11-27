import AppKit

/// A read-only Markdown document. It never saves; it re-reads the file when
/// something else (an editor, Claude, git) changes it on disk.
@objc(MarkdownDocument)   // Info.plist's NSDocumentClass names this
final class MarkdownDocument: NSDocument {
    private(set) var text = ""
    private var watcher: Timer?
    private var lastStamp: (Date, Int)?

    override class var autosavesInPlace: Bool { false }
    override var isDocumentEdited: Bool { false }

    override func makeWindowControllers() {
        addWindowController(ViewerWindowController())
    }

    override func read(from data: Data, ofType typeName: String) throws {
        text = Self.decode(data)
        lastStamp = fileURL.flatMap(Self.stamp)
        startWatching()
    }

    override func data(ofType typeName: String) throws -> Data {
        throw CocoaError(.featureUnsupported)   // viewer only
    }

    override func close() {
        watcher?.invalidate()
        watcher = nil
        super.close()
    }

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        guard let viewer = windowControllers.first as? ViewerWindowController else {
            throw CocoaError(.featureUnsupported)
        }
        return viewer.printOperation(printInfo: printInfo)
    }

    // MARK: - live reload

    /// Polling the modification date once a second is boring but robust: it also
    /// catches editors that save by writing a temp file and renaming it over ours,
    /// which a file-descriptor watcher loses track of.
    private func startWatching() {
        guard watcher == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.checkDisk() }
        RunLoop.main.add(t, forMode: .common)
        watcher = t
    }

    private func checkDisk() {
        guard let url = fileURL, let stamp = Self.stamp(url) else { return }  // mid-save: file briefly missing
        if let last = lastStamp, last.0 == stamp.0, last.1 == stamp.1 { return }
        guard let data = try? Data(contentsOf: url) else { return }
        lastStamp = stamp
        fileModificationDate = stamp.0
        let newText = Self.decode(data)
        guard newText != text else { return }
        text = newText
        for case let viewer as ViewerWindowController in windowControllers {
            viewer.render(keepScroll: true)
        }
    }

    func reloadFromDisk() {
        lastStamp = nil
        checkDisk()
    }

    private static func stamp(_ url: URL) -> (Date, Int)? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = a[.modificationDate] as? Date else { return nil }
        return (date, (a[.size] as? NSNumber)?.intValue ?? 0)
    }

    private static func decode(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        return String(decoding: data, as: UTF8.self)
    }
}
