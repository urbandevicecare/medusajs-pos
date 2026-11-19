import Cocoa
import SwiftUI

// MARK: - App Delegate & Main Entry (MacVDMTool Architecture with Robust AppKit Event Dispatching)

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    public var window: POSWindow!
    public var viewModel: POSViewModel!
    
    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Ensure regular application activation policy so window receives keyboard and mouse clicks
        NSApp.setActivationPolicy(.regular)
        
        // Setup standard application menu bar (Quit, Close, Text Editing shortcuts)
        setupMainMenu()
        
        let vm = POSViewModel()
        self.viewModel = vm
        let contentView = ContentView(viewModel: vm)
        
        // Wrap root view in POSHostingView to guarantee first-mouse click acceptance
        // and prevent mouseDownCanMoveWindow from hijacking button clicks
        let hostingView = POSHostingView(rootView: contentView)
        
        window = POSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 820, height: 540)
        window.center()
        window.title = "Urban Device Care POS"
        window.titleVisibility = .visible
        // Disallow moving window by clicking background so button clicks are never intercepted
        window.isMovableByWindowBackground = false
        window.contentView = hostingView
        
        // Make key and bring application frontmost
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Application Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Urban Device Care POS", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Urban Device POS", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit Menu (crucial for Cut/Copy/Paste/Select All in barcode & amount textfields)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSStandardKeyBindingResponding.selectAll(_:)), keyEquivalent: "a")
        
        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        
        NSApp.mainMenu = mainMenu
    }
}

@main
struct MainEntry {
    // Retain strong reference to AppDelegate across whole runtime lifecycle
    static var appDelegate: AppDelegate?
    
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        self.appDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}
