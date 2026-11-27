import AppKit
import WebKit

/// One window = one WKWebView showing Web/viewer.html, fed the document's text.
final class ViewerWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate,
                                    NSToolbarDelegate {
    private var webView: WKWebView!
    private let chrome = ChromeAutoHider()
    private var pageReady = false

    private static let background = NSColor(srgbRed: 0x15 / 255.0, green: 0x17 / 255.0, blue: 0x1c / 255.0, alpha: 1)
    private static let zoomKey = "pageZoom", outlineKey = "showOutline"
    private static let zoomChanged = Notification.Name("MDReaderZoomChanged")

    private var doc: MarkdownDocument? { document as? MarkdownDocument }

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 480, height: 360)
        window.backgroundColor = Self.background
        window.toolbarStyle = .unified
        window.tabbingMode = .preferred
        super.init(window: window)
        window.delegate = self
        shouldCascadeWindows = true
        setUpToolbar()
        chrome.attach(to: window)   // before the web view, so it is created full-window
        setUpWebView()
        if !window.setFrameUsingName("MDReaderWindow") { window.center() }
        window.setFrameAutosaveName("MDReaderWindow")
        NotificationCenter.default.addObserver(self, selector: #selector(applyZoom),
                                               name: Self.zoomChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var document: AnyObject? {
        didSet {
            render(keepScroll: false)
            if let url = doc?.fileURL {
                window?.subtitle = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
            }
        }
    }

    // MARK: - web view

    private func setUpWebView() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(SchemeHandler(), forURLScheme: SchemeHandler.scheme)
        config.userContentController.add(MessageProxy(self), name: "mdr")
        config.preferences.isElementFullscreenEnabled = false

        webView = WKWebView(frame: window!.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")   // no white flash before the CSS loads
        webView.underPageBackgroundColor = Self.background
        webView.allowsMagnification = true
        webView.pageZoom = CGFloat(UserDefaults.standard.object(forKey: Self.zoomKey) as? Double ?? 1.0)
        window!.contentView!.addSubview(webView)
        webView.load(URLRequest(url: SchemeHandler.viewerURL))
    }

    func render(keepScroll: Bool) {
        guard pageReady, let doc else { return }
        let dir = doc.fileURL?.deletingLastPathComponent().path ?? ""
        webView.callAsyncJavaScript("MDR.render(md, dir, keep)",
                                    arguments: ["md": doc.text, "dir": dir, "keep": keepScroll],
                                    in: nil, in: .page) { result in
            if case .failure(let error) = result { NSLog("MDReader render failed: \(error)") }
        }
    }

    fileprivate func receive(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            pageReady = true
            setOutline(UserDefaults.standard.object(forKey: Self.outlineKey) as? Bool ?? true)
            webView.evaluateJavaScript("MDR.setTopInset(\(Int(chrome.barHeight.rounded())))")
            render(keepScroll: false)
            window?.makeFirstResponder(webView)
        case "open":
            if let href = body["href"] as? String { openLink(href) }
        case "copy":
            if let text = body["text"] as? String {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        default:
            break
        }
    }

    private func openLink(_ href: String) {
        guard let url = URL(string: href) else { return }
        guard url.scheme == SchemeHandler.scheme, url.host == "file" else {
            NSWorkspace.shared.open(url)      // http(s), mailto, …
            return
        }
        let file = URL(fileURLWithPath: url.path)
        let markdown = ["md", "markdown", "mdown", "mkd", "mkdn", "mdx"]
        if markdown.contains(file.pathExtension.lowercased()) {
            NSDocumentController.shared.openDocument(withContentsOf: file, display: true) { _, _, error in
                if let error { NSApp.presentError(error) }
            }
        } else {
            NSWorkspace.shared.open(file)
        }
    }

    // Anything that tries to navigate the page itself (a stray link, a drag-and-drop)
    // is cancelled; drops of .md files open them as documents instead.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        if url.scheme == SchemeHandler.scheme && url.host == "app" { return decisionHandler(.allow) }
        decisionHandler(.cancel)
        if url.isFileURL {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        } else if action.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        pageReady = false
        webView.load(URLRequest(url: SchemeHandler.viewerURL))
    }

    func printOperation(printInfo: NSPrintInfo) -> NSPrintOperation {
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.topMargin = 36; printInfo.bottomMargin = 36
        printInfo.leftMargin = 40; printInfo.rightMargin = 40
        let op = webView.printOperation(with: printInfo)
        op.view?.frame = webView.bounds
        op.jobTitle = doc?.displayName ?? "Markdown"
        return op
    }

    // MARK: - menu actions

    @objc func reloadDocument(_ sender: Any?) { doc?.reloadFromDisk(); render(keepScroll: true) }

    @objc func showInFinder(_ sender: Any?) {
        if let url = doc?.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    @objc func openInEditor(_ sender: Any?) {
        guard let url = doc?.fileURL else { return }
        let ws = NSWorkspace.shared
        let mine = Bundle.main.bundleURL.standardizedFileURL
        // 1. the editor chosen with `defaults write com.binhphuong-ab.mdreader editorBundleID <id>`
        // 2. the system default for .md, unless that is MD Reader itself
        // 3. TextEdit
        var candidates: [URL] = []
        if let id = UserDefaults.standard.string(forKey: "editorBundleID"),
           let app = ws.urlForApplication(withBundleIdentifier: id) { candidates.append(app) }
        if let app = ws.urlForApplication(toOpen: url) { candidates.append(app) }
        if let app = ws.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") { candidates.append(app) }
        if let editor = candidates.first(where: { $0.standardizedFileURL != mine }) {
            ws.open([url], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    @objc func toggleOutline(_ sender: Any?) {
        let on = !(UserDefaults.standard.object(forKey: Self.outlineKey) as? Bool ?? true)
        UserDefaults.standard.set(on, forKey: Self.outlineKey)
        for case let w as ViewerWindowController in NSApp.windows.compactMap(\.windowController) {
            w.setOutline(on, animate: true)
        }
    }

    private func setOutline(_ on: Bool, animate: Bool = false) {
        guard pageReady else { return }
        webView.evaluateJavaScript("MDR.setOutline(\(on), \(animate))")
    }

    @objc func zoomIn(_ sender: Any?) { setZoom(webView.pageZoom + 0.1) }
    @objc func zoomOut(_ sender: Any?) { setZoom(webView.pageZoom - 0.1) }
    @objc func actualSize(_ sender: Any?) { setZoom(1.0) }

    private func setZoom(_ z: CGFloat) {
        let clamped = min(max((z * 10).rounded() / 10, 0.5), 3.0)
        UserDefaults.standard.set(Double(clamped), forKey: Self.zoomKey)
        NotificationCenter.default.post(name: Self.zoomChanged, object: nil)
    }

    @objc private func applyZoom() {
        webView.pageZoom = CGFloat(UserDefaults.standard.object(forKey: Self.zoomKey) as? Double ?? 1.0)
    }

    // MARK: - toolbar

    private static let outlineItem = NSToolbarItem.Identifier("outline")

    private func setUpToolbar() {
        let toolbar = NSToolbar(identifier: "MDReaderToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.outlineItem]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case Self.outlineItem:
            let item = NSToolbarItem(itemIdentifier: id)
            item.label = "Outline"
            item.toolTip = "Show/Hide Outline (⌃⌘S)"
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Outline")
            item.isBordered = true
            item.target = self
            item.action = #selector(toggleOutline(_:))
            return item
        default:
            return nil
        }
    }
}

/// WKUserContentController retains its handlers; this breaks the cycle.
private final class MessageProxy: NSObject, WKScriptMessageHandler {
    weak var target: ViewerWindowController?
    init(_ target: ViewerWindowController) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.receive(message)
    }
}
