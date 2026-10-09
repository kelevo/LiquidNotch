import AppKit
import SwiftUI

class NotchHoverHandler: NSResponder {
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?
    private var hoverTimer: Timer?

    override func mouseEntered(with event: NSEvent) {
        let expandOnHover = UserDefaults.standard.object(forKey: "liquidNotch.expandOnHover") as? Bool ?? true
        guard expandOnHover else { return }
        hoverTimer?.invalidate()
        hoverTimer = nil
        onHoverEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.onHoverExit?()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private var trackingArea: NSTrackingArea?
    private var hoverHandler: NotchHoverHandler?
    let notchState = NotchState()
    private let mediaManager = MediaRemoteManager()

    private let capsuleWidth: CGFloat = 170
    private let capsuleHeight: CGFloat = 24
    private let expandedWidth: CGFloat = 370
    private let expandedHeight: CGFloat = 180
    private let screenOffset: CGFloat = 4

    private var topEdgeY: CGFloat = 0
    private var centerX: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        createPanel()

        DispatchQueue.main.async {
            self.positionPanel()
            self.setupTrackingArea()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Panel Creation

    private func createPanel() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        centerX = screenFrame.midX
        topEdgeY = screenFrame.maxY - screenOffset

        let panelX = centerX - (capsuleWidth / 2)
        let panelY = topEdgeY - capsuleHeight

        panel = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: capsuleWidth, height: capsuleHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        guard let panel = panel else { return }

        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        let mainView = UnifiedNotchView(mediaManager: mediaManager, notchState: notchState)
        let hostingView = NSHostingView(rootView: mainView)
        hostingView.frame = NSRect(x: 0, y: 0, width: capsuleWidth, height: capsuleHeight)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        panel.orderFrontRegardless()
    }

    // MARK: - Positioning

    private func positionPanel() {
        guard let panel = panel else { return }

        let panelX = centerX - (capsuleWidth / 2)
        let panelY = topEdgeY - capsuleHeight
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
    }

    // MARK: - Tracking Area

    private func setupTrackingArea() {
        guard let contentView = panel?.contentView else { return }

        if let existing = trackingArea {
            contentView.removeTrackingArea(existing)
        }

        let handler = NotchHoverHandler()
        handler.onHoverEnter = { [weak self] in
            self?.expand()
        }
        handler.onHoverExit = { [weak self] in
            self?.scheduleCollapseIfNeeded()
        }
        self.hoverHandler = handler

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: handler,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        self.trackingArea = area
    }

    // MARK: - Expand / Collapse

    private var collapseTimer: Timer?

    private func expand() {
        guard let panel = panel, !notchState.isExpanded else { return }

        collapseTimer?.invalidate()
        collapseTimer = nil

        // Panel inicia desde la posición de la cápsula
        let capsuleX = centerX - (capsuleWidth / 2)
        let capsuleY = topEdgeY - capsuleHeight
        panel.setFrame(NSRect(x: capsuleX, y: capsuleY, width: capsuleWidth, height: capsuleHeight), display: false)

        notchState.isExpanded = true

        let expandedX = centerX - (expandedWidth / 2)
        let expandedY = topEdgeY - expandedHeight

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.4, 0.0, 0.2, 1.0
            )
            panel.animator().setFrame(
                NSRect(x: expandedX, y: expandedY, width: expandedWidth, height: expandedHeight),
                display: true
            )
        }
    }

    private func scheduleCollapseIfNeeded() {
        guard notchState.isExpanded else { return }

        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.collapse()
        }
    }

    private func cancelCollapseIfNeeded() {
        collapseTimer?.invalidate()
        collapseTimer = nil
    }

    private func collapse() {
        guard let panel = panel, notchState.isExpanded else { return }

        collapseTimer?.invalidate()
        collapseTimer = nil
        notchState.isExpanded = false

        let capsuleX = centerX - (capsuleWidth / 2)
        let capsuleY = topEdgeY - capsuleHeight

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.4, 0.0, 0.2, 1.0
            )
            panel.animator().setFrame(
                NSRect(x: capsuleX, y: capsuleY, width: capsuleWidth, height: capsuleHeight),
                display: true
            )
        }
    }

    func toggleExpansion() {
        if notchState.isExpanded {
            collapse()
        } else {
            expand()
        }
    }
}
