import AppKit
import SwiftUI

class NotchHoverHandler: NSResponder {
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?
    private var hoverTimer: Timer?
    
    override func mouseEntered(with event: NSEvent) {
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
    private var panelWidth: CGFloat = 170
    private var panelHeight: CGFloat = 24
    private var trackingArea: NSTrackingArea?
    private var hoverHandler: NotchHoverHandler?
    let notchState = NotchState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 === applicationDidFinishLaunching START ===")
        NSApp.setActivationPolicy(.accessory)
        createPanel()
        
        DispatchQueue.main.async {
            self.positionAtNotch()
            self.setupTrackingArea()
        }
        
        print("🚀 === applicationDidFinishLaunching END ===")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func createPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
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

        let mainView = MainNotchView(state: notchState)
        let hostingView = NSHostingView(rootView: mainView)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        panel.orderFrontRegardless()
    }
    
    private func setupTrackingArea() {
        guard let contentView = panel?.contentView else { return }
        
        if let existingTrackingArea = trackingArea {
            contentView.removeTrackingArea(existingTrackingArea)
        }
        
        let handler = NotchHoverHandler()
        handler.onHoverEnter = { [weak self] in
            guard let self = self, !self.notchState.isExpanded else { return }
            self.resizePanel(expanded: true)
        }
        handler.onHoverExit = { [weak self] in
            guard let self = self, self.notchState.isExpanded else { return }
            self.resizePanel(expanded: false)
        }
        self.hoverHandler = handler
        
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: handler,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    private func positionAtNotch() {
        guard let panel = panel,
              let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let notchX = screenFrame.midX - (panelWidth / 2)
        let notchY = screenFrame.maxY - panelHeight - 4

        panel.setFrameOrigin(NSPoint(x: notchX, y: notchY))
        print("📍 Positioned at: \(NSPoint(x: notchX, y: notchY))")
    }

    func toggleExpansion() {
        resizePanel(expanded: !notchState.isExpanded)
    }

    private func resizePanel(expanded: Bool) {
        print("🔄 resizePanel called: expanded=\(expanded)")
        guard let panel = panel,
              let screen = NSScreen.main else { return }

        let newWidth: CGFloat = expanded ? 370 : 170
        let newHeight: CGFloat = expanded ? 160 : 24

        panelWidth = newWidth
        panelHeight = newHeight

        let screenFrame = screen.frame
        let notchX = screenFrame.midX - (newWidth / 2)
        let notchY = screenFrame.maxY - newHeight - 4

        DispatchQueue.main.async {
            self.notchState.isExpanded = expanded
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            panel.animator().setFrame(
                NSRect(x: notchX, y: notchY, width: newWidth, height: newHeight),
                display: true
            )
        }
        
        print("📦 Resized to: \(NSRect(x: notchX, y: notchY, width: newWidth, height: newHeight))")
    }
}
