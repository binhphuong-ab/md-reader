import AppKit

/// Keeps the window's whole top bar (traffic lights, title, toolbar) hidden so the page gets
/// the full window. The bar shows only while the mouse is in the top strip and hides as soon
/// as it leaves. (Grew out of Mindmap Markdown's ChromeAutoHider, minus the 3 s delay.)
final class ChromeAutoHider {
    static let minRevealZone: CGFloat = 56

    private(set) var visible = true
    private weak var window: NSWindow?
    private var monitor: Any?
    private var leaveCheck: Timer?

    func attach(to window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        // The page runs underneath the bar, so showing/hiding it never shifts the text.
        window.styleMask.insert(.fullSizeContentView)
        window.acceptsMouseMovedEvents = true
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
                self?.handle(event)
                return event
            }
        }
        setVisible(false, animated: false)
    }

    /// Height of the bar in points: the page leaves this much room at the top.
    var barHeight: CGFloat {
        guard let window else { return 0 }
        return max(0, window.frame.height - window.contentLayoutRect.height)
    }

    /// The top strip that reveals the bar: at least the bar itself (66 pt on macOS 27).
    private var revealZone: CGFloat { max(Self.minRevealZone, barHeight) }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        leaveCheck?.invalidate()
    }

    private func handle(_ event: NSEvent) {
        guard let window, event.window === window else { return }
        if event.locationInWindow.y >= window.frame.height - revealZone {
            setVisible(true)
        } else {
            hideIfAllowed()
        }
    }

    /// Mouse-moved events stop once the pointer leaves the window (e.g. up to the menu bar),
    /// so while the bar is up a light 0.1 s check notices that and hides it.
    private func startLeaveCheck() {
        guard leaveCheck == nil else { return }
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let window = self.window else { return }
            if !self.mouseInZone(window) { self.hideIfAllowed() }
        }
        RunLoop.main.add(t, forMode: .common)
        leaveCheck = t
    }

    private func hideIfAllowed() {
        guard visible, let window else { return }
        if window.styleMask.contains(.fullScreen) { return }    // macOS handles the bar in full screen
        if window.attachedSheet != nil { return }               // a dialog hangs from the bar
        if NSEvent.pressedMouseButtons != 0 { return }          // mid-click or dragging the window
        setVisible(false)
    }

    private func mouseInZone(_ window: NSWindow) -> Bool {
        let p = NSEvent.mouseLocation
        let f = window.frame
        return f.contains(p) && p.y >= f.maxY - revealZone
    }

    /// The title-bar container holds the traffic lights, title and toolbar; fading it as
    /// one layer looks smooth.
    private var titlebarContainer: NSView? {
        window?.standardWindowButton(.closeButton)?.superview?.superview
    }

    private func setVisible(_ show: Bool, animated: Bool = true) {
        guard let bar = titlebarContainer else { return }
        guard show != visible || !animated else { return }
        visible = show
        if show {
            startLeaveCheck()
            bar.isHidden = false
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = animated ? 0.12 : 0
                bar.animator().alphaValue = 1
            }
        } else {
            leaveCheck?.invalidate()
            leaveCheck = nil
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = animated ? 0.12 : 0      // starts at once; just a quick fade, not a delay
                bar.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                // Once invisible, take it out of hit-testing so clicks reach the page.
                guard let self, !self.visible else { return }   // revealed again mid-fade
                bar.isHidden = true
            })
        }
    }
}
