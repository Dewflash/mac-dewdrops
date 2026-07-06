import AppKit
import WebKit

private enum AppConfig {
    static let appName = "Dewdrops"
    static let popoverSize = NSSize(width: 430, height: 560)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let webViewController = WebViewController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = DropStatusIcon.image()
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.toolTip = AppConfig.appName
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = AppConfig.popoverSize
        popover.contentViewController = webViewController
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            webViewController.loadIfNeeded()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Dewdrops", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class WebViewController: NSViewController, WKUIDelegate, WKScriptMessageHandler {
    private var didLoad = false
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(self, name: "dewdropsNative")

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.uiDelegate = self
        return view
    }()

    override func loadView() {
        view = webView
        view.frame = NSRect(origin: .zero, size: AppConfig.popoverSize)
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        guard let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") else {
            webView.loadHTMLString("<body style='font:14px -apple-system;color:white;background:#111'>Missing index.html</body>", baseURL: nil)
            return
        }

        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.begin { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == "dewdropsNative",
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else { return }

        switch type {
        case "copy":
            if let text = body["text"] as? String {
                copyToPasteboard(text)
                callJavaScriptCallback("dewdropsNativeCopied")
            }
        default:
            break
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func callJavaScriptCallback(_ name: String) {
        webView.evaluateJavaScript("window['\(name)'] && window['\(name)']();")
    }
}

private enum DropStatusIcon {
    static func image() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.black.setFill()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 9, y: 16))
        path.curve(to: NSPoint(x: 15, y: 7), controlPoint1: NSPoint(x: 13, y: 11), controlPoint2: NSPoint(x: 15, y: 9))
        path.curve(to: NSPoint(x: 9, y: 1.8), controlPoint1: NSPoint(x: 15, y: 3.5), controlPoint2: NSPoint(x: 12.4, y: 1.8))
        path.curve(to: NSPoint(x: 3, y: 7), controlPoint1: NSPoint(x: 5.6, y: 1.8), controlPoint2: NSPoint(x: 3, y: 3.5))
        path.curve(to: NSPoint(x: 9, y: 16), controlPoint1: NSPoint(x: 3, y: 9), controlPoint2: NSPoint(x: 5, y: 11))
        path.close()
        path.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

