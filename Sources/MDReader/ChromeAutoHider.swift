import AppKit

/// Fades out the window's whole top bar (traffic lights, title, toolbar) so the page gets
/// the full window. Moving the mouse into the top strip brings it back; it hides again once
/// the mouse has been away from that strip for `hideDelay` seconds.
/// (Same approach as Mindmap Markdown's ChromeAutoHider.)
final class ChromeAutoHider {
    static let minRevealZone: CGFloat = 56
    static let hideDelay: TimeInterval = 3

    private(set) var visible = true
    private weak var window: NSWindow?
    private var monitor: Any?
    private var hideTimer: Timer?

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
        setVisible(true, animated: false)
        armHideTimer()   // start visible so the controls are discoverable
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
        hideTimer?.invalidate()
    }

    private func handle(_ event: NSEvent) {
        guard let window, event.window === window else { return }
        if event.locationInWindow.y >= window.frame.height - revealZone {
            setVisible(true)
            armHideTimer()                // restart the countdown on every move in the strip
        }
    }

    private func armHideTimer() {
        hideTimer?.invalidate()
        // Default run-loop mode on purpose: it doesn't fire while a menu is open,
        // so the bar never vanishes from under an open menu.
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.hideDelay, repeats: false) { [weak self] _ in
            self?.hideIfMouseAway()
        }
    }

    private func hideIfMouseAway() {
        guard let window else { return }
        if window.styleMask.contains(.fullScreen) { return }   // macOS handles the bar in full screen
        if window.attachedSheet != nil || mouseInZone(window) { armHideTimer(); return }
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
        visible = show
        if show {
            bar.isHidden = false
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = animated ? 0.18 : 0
                bar.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = animated ? 0.25 : 0
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                bar.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                // Once invisible, take it out of hit-testing so clicks reach the page.
                guard let self, !self.visible else { return }   // revealed again mid-fade
                bar.isHidden = true
            })
        }
    }
}
