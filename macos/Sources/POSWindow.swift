import Cocoa
import AppKit
import SwiftUI

// MARK: - Custom NSHostingView that overrides mouse handling to ensure buttons receive clicks

public class POSHostingView<Content: View>: NSHostingView<Content> {
    // 1. Accept first mouse: ensure immediate response on the first click even if window is not key/active
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    // 2. Disable mouseDownCanMoveWindow: prevent AppKit from hijacking mouse-down events as window drag attempts
    public override var mouseDownCanMoveWindow: Bool {
        return false
    }
}

// MARK: - Custom Window ensuring Key & Main Window Status

public class POSWindow: NSWindow {
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
}
