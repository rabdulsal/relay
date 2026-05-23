import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var mainWindow: NSWindow?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // Single store shared across popover, window, and icon
    let store = TaskStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        observeStore()
    }

    // ── Status item ───────────────────────────────────────────────────────────

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "RelayStatusItem"   // persists position across launches

        guard let button = statusItem.button else { return }
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        embedIconView(in: button)
    }

    private func embedIconView(in button: NSStatusBarButton) {
        let iconView = NSHostingView(rootView: MenuBarIconView().environmentObject(store))
        let w: CGFloat = 46
        iconView.frame = NSRect(x: 0, y: 0, width: w, height: 22)
        button.frame = iconView.frame
        button.addSubview(iconView)
    }

    private func observeStore() {
        store.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncIconWidth() }
            .store(in: &cancellables)
    }

    private func syncIconWidth() {
        guard let button = statusItem.button,
              let iconView = button.subviews.first as? NSHostingView<MenuBarIconView>
        else { return }
        let w: CGFloat = store.menuBarCount > 0 ? 54 : 28
        guard iconView.frame.width != w else { return }
        let frame = NSRect(x: 0, y: 0, width: w, height: 22)
        iconView.frame = frame
        button.frame   = frame
    }

    // ── Popover ───────────────────────────────────────────────────────────────

    private func setupPopover() {
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(store)
        )
        popover.behavior = .transient
        popover.animates = false
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in self?.closePopover() }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopover()
        }
    }

    func togglePopover() { popover.isShown ? closePopover() : openPopover() }

    func openPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closePopover() { popover.performClose(nil) }

    // ── Context menu (right-click) ────────────────────────────────────────────

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let win = NSMenuItem(title: "Open Window", action: #selector(openMainWindow), keyEquivalent: "")
        win.target = self
        menu.addItem(win)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshTasks), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Relay",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { self.statusItem.menu = nil }
    }

    // ── Main window ───────────────────────────────────────────────────────────

    @objc func openMainWindow() {
        closePopover()

        if let win = mainWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 580),
            styleMask:   [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing:     .buffered,
            defer:       false
        )
        win.title = "Relay"
        win.minSize = NSSize(width: 620, height: 440)
        win.titlebarAppearsTransparent = true
        win.toolbarStyle = .unified
        win.isReleasedWhenClosed = false
        win.contentViewController = NSHostingController(
            rootView: MainWindowView().environmentObject(store)
        )
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = win
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
        openPopover()
    }

    @objc private func refreshTasks() { Task { await store.refresh() } }

    deinit {
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
    }
}
