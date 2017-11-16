//
//  main.swift
//  num_mouse
//
//  Created by Matthew Riley on 2017-11-12.
//  Copyright © 2017 Matthew Riley. All rights reserved.
//

import Foundation
import Cocoa

/*
 TODO:
 Figure out how to draw lines and points to the window
 
 see styleMask for some more options
 see NSPanel, and Key vs Main window
 Also see NSWindowCollectionBehaviour
 
 Neat for some other time:
 can set canBecomeKeyWindow false for a window that can be clicked but still not become the
 key window
 
 Notice:
 when launches, it is default active
 if becomes inactive for any reason, close the app
 */
class MainView: NSView {
    var inputs = [Int]()
    
    init() {
        super.init(frame: NSMakeRect(0, 0, 200, 200))
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func modifyView(newNum: Int) {
        inputs.append(newNum)
        Swift.print("modify with: \(newNum)")
        // rewdraw the view
    }
    
    func numToPoint(num: Int) -> CGPoint {
        return CGPoint(x: (num - 1) % 3, y: 2 - (num - 1) / 3)
    }
    
    func selectedBounds(bounds: NSRect, num: Int) -> NSRect {
        let pt = self.numToPoint(num: num)
        let newOrigin =
            bounds.origin + CGPoint(x: bounds.width, y: bounds.height) * pt / 3.0
        let newW = bounds.width / 3
        let newH = bounds.height / 3
        return NSRect(origin: newOrigin, size: CGSize(width: newW, height: newH))
    }
    
    func mouseBounds() -> NSRect {
        // compute the outer bounds of the current section
        var newBounds = self.bounds
        for n in inputs {
            newBounds = self.selectedBounds(bounds: newBounds, num: n)
        }
        return newBounds
    }
    
    func mousePosition() -> CGPoint {
        let b = self.mouseBounds()
        return CGPoint(x: b.midX, y: b.midY)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current()!.cgContext
        
        // clear current canvas
        context.clear(self.bounds)
        
        let mouseBounds = self.mouseBounds()
        let mousePos = self.mousePosition()
        
        // draw the current mouse bounds
        context.setFillColor(gray: 1.0, alpha: 0.5)
        context.fill(mouseBounds)
        
        // divide the mouse bounds into sections
        context.setStrokeColor(gray: 0, alpha: 1)
        for i in 1...9 {
            let rect = self.selectedBounds(bounds: mouseBounds, num: i)
            context.stroke(rect, width: 1.0)
        }
        
        // draw current mouse position
        context.setFillColor(gray: 0, alpha: 1)
        let diameter = 4
        context.fill(CGRect(origin:
            mousePos + CGPoint(x: -diameter, y: -diameter) / 2.0,
                            size: CGSize(width: diameter, height: diameter)))
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    // if window loses its key status, it cannot regain it, so terminate the app
    func windowDidResignKey(_ notification: Notification) {
        NSApp.terminate(self)
    }
}

/*
 Make a panel b/c a panel can be the key window even though another window is the main window
 */
class InputWindow: NSPanel {
    
    // it is resized upon setting to content view, so frame doesn't matter
    let view = MainView()
    let winDelegate = WindowDelegate()
    
    init() {
        super.init(contentRect:
            NSMakeRect(0, 0, NSScreen.main()!.frame.width, NSScreen.main()!.frame.height),
                   styleMask: [.borderless,
                               //.fullScreen,
                    //.texturedBackground,
                    .utilityWindow,
                    .docModalWindow,
                    .nonactivatingPanel,
                    .hudWindow],
                   backing: .buffered,
                   defer: true)
        
        self.delegate = winDelegate
        self.contentView = view
        self.title = "New Window"
        
        // panel-specific
        self.isFloatingPanel = true
        self.worksWhenModal = true
        
        // window settings
        self.isOpaque = false
        self.level = Int(CGWindowLevelForKey(CGWindowLevelKey.assistiveTechHighWindow))
        self.ignoresMouseEvents = true
        self.isMovableByWindowBackground = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        
    }
    
    // defaults to false for borderless windows
    override var canBecomeKey: Bool {
        get {
            return true
        }
    }
    
    // TODO: must convert the mousePosition point from view/window space to monitor space
    func mouseMoveAndClick() {
        // convert the view's mouse position to screen coords
        let viewPt = view.mousePosition()
        let winPt = view.convert(viewPt, to: nil)
        var screenPt =
            self.convertToScreen(CGRect(origin: winPt, size: CGSize(width: 1, height: 1))).origin
        screenPt.x = CGFloat(Int(screenPt.x))
        screenPt.y = CGFloat(Int(screenPt.y))
        screenPt.y = NSScreen.main()!.frame.height - screenPt.y
        Swift.print("view: \(viewPt), win: \(winPt), screen: \(screenPt)")
        
        guard let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: screenPt, mouseButton: .left) else {
            return
        }
        guard let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: screenPt, mouseButton: .left) else {
            return
        }
        guard let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: screenPt, mouseButton: .left) else {
            return
        }
        moveEvent.post(tap: CGEventTapLocation.cghidEventTap)
        downEvent.post(tap: CGEventTapLocation.cghidEventTap)
        upEvent.post(tap: CGEventTapLocation.cghidEventTap)
    }
    
    override func keyDown(with event: NSEvent) {
        let chars: String = event.characters!
        Swift.print("pressed: \(chars)")
        
        let num: Int? = Int(chars)
        if num != nil && 1 <= num! && num! <= 9 {
            view.modifyView(newNum: num!)
            view.setNeedsDisplay(view.bounds)
        } else if event.keyCode == 36 || event.keyCode == 76 {
            self.mouseMoveAndClick()
            NSApp.terminate(self)
        } else {
            // any other key should terminate the click
            NSApp.terminate(self)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let inputWindow = InputWindow()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        //inputWindow.center()
        //inputWindow.toggleFullScreen(self)
        inputWindow.makeKeyAndOrderFront(self)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Insert code here to tear down your application
    }
}

Swift.print("running")
let app = NSApplication.shared()
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()
print("app run")
//app.activate(ignoringOtherApps: true)



