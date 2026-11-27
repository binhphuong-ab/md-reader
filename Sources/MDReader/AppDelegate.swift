import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)   // the whole app is dark, whatever the system says
        NSApp.mainMenu = MainMenu.build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `MDReader path/to/file.md` from a shell also works.
        let paths = CommandLine.arguments.dropFirst()
            .filter { !$0.hasPrefix("-") && FileManager.default.fileExists(atPath: $0) }
        for path in paths {
            NSDocumentController.shared.openDocument(withContentsOf: URL(fileURLWithPath: path), display: true) { _, _, _ in }
        }
        // Launched with nothing to show (double-clicked in /Applications): ask for a file.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if NSDocumentController.shared.documents.isEmpty {
                NSDocumentController.shared.openDocument(nil)
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSDocumentController.shared.openDocument(nil) }
        return false
    }
}

/// The menu bar, built in code (there is no nib). Items without a target go
/// down the responder chain, so `ViewerWindowController` answers the View ones.
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        let appName = ProcessInfo.processInfo.processName == "MDReader" ? "MD Reader" : ProcessInfo.processInfo.processName

        main.addItem(submenu("", [
            item("About \(appName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Hide \(appName)", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item("Quit \(appName)", #selector(NSApplication.terminate(_:)), "q"),
        ]))

        // NSDocumentController finds and fills "Open Recent" by its clearRecentDocuments: item.
        let recent = submenu("Open Recent", [
            item("Clear Menu", #selector(NSDocumentController.clearRecentDocuments(_:))),
        ])
        main.addItem(submenu("File", [
            item("Open…", #selector(NSDocumentController.openDocument(_:)), "o"),
            recent,
            .separator(),
            item("Reload", #selector(ViewerWindowController.reloadDocument(_:)), "r"),
            item("Show in Finder", #selector(ViewerWindowController.showInFinder(_:)), "r", [.command, .shift]),
            item("Open in Default Editor", #selector(ViewerWindowController.openInEditor(_:)), "e"),
            .separator(),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Print…", #selector(NSDocument.printDocument(_:)), "p"),
        ]))

        main.addItem(submenu("Edit", [
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item("Find…", #selector(ViewerWindowController.showFind(_:)), "f"),
            item("Find Next", #selector(ViewerWindowController.findNext(_:)), "g"),
            item("Find Previous", #selector(ViewerWindowController.findPrevious(_:)), "g", [.command, .shift]),
        ]))

        main.addItem(submenu("View", [
            item("Show/Hide Outline", #selector(ViewerWindowController.toggleOutline(_:)), "s", [.command, .control]),
            .separator(),
            item("Actual Size", #selector(ViewerWindowController.actualSize(_:)), "0"),
            item("Zoom In", #selector(ViewerWindowController.zoomIn(_:)), "="),
            item("Zoom Out", #selector(ViewerWindowController.zoomOut(_:)), "-"),
            .separator(),
            item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]),
        ]))

        let window = submenu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:))),
            .separator(),
            item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
        ])
        main.addItem(window)
        NSApp.windowsMenu = window.submenu
        return main
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "",
                             _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { i.keyEquivalentModifierMask = mods }
        return i
    }

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        holder.submenu = menu
        return holder
    }
}
