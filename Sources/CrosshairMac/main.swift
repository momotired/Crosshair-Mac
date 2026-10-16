import AppKit
import SwiftUI

@main
enum CrosshairMacApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = CrosshairSettings()
    private var overlayController: OverlayController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var settingsObservation: AnyObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlayController = OverlayController(settings: settings)
        makeStatusItem()
        overlayController.refresh()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        settingsObservation = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.overlayController.refresh()
                self?.updateStatusMenu()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func displaysChanged() {
        overlayController.refresh()
    }

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "准星")
            button.toolTip = "Crosshair Mac"
        }
        updateStatusMenu()
    }

    private func updateStatusMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: settings.isEnabled ? "隐藏准星" : "显示准星",
            action: #selector(toggleCrosshair),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = settings.isEnabled ? .on : .off
        menu.addItem(toggle)

        menu.addItem(.separator())
        let configure = NSMenuItem(title: "准星设置…", action: #selector(openSettings), keyEquivalent: ",")
        configure.target = self
        menu.addItem(configure)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 Crosshair Mac", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggleCrosshair() {
        settings.isEnabled.toggle()
        overlayController.refresh()
        updateStatusMenu()
    }

    @objc private func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 590),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "准星设置"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class CrosshairSettings: ObservableObject {
    enum Style: String, CaseIterable, Identifiable {
        case cross = "标准十字"
        case dot = "十字带点"
        case circle = "圆圈"
        var id: String { rawValue }
    }

    @Published var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Key.enabled) } }
    @Published var style: Style { didSet { defaults.set(style.rawValue, forKey: Key.style) } }
    @Published var lineWidth: Double { didSet { defaults.set(lineWidth, forKey: Key.lineWidth) } }
    @Published var lineLength: Double { didSet { defaults.set(lineLength, forKey: Key.lineLength) } }
    @Published var gapSize: Double { didSet { defaults.set(gapSize, forKey: Key.gapSize) } }
    @Published var opacity: Double { didSet { defaults.set(opacity, forKey: Key.opacity) } }
    @Published var outline: Bool { didSet { defaults.set(outline, forKey: Key.outline) } }
    @Published var red: Double { didSet { defaults.set(red, forKey: Key.red) } }
    @Published var green: Double { didSet { defaults.set(green, forKey: Key.green) } }
    @Published var blue: Double { didSet { defaults.set(blue, forKey: Key.blue) } }

    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "crosshair.enabled"
        static let style = "crosshair.style"
        static let lineWidth = "crosshair.lineWidth"
        static let lineLength = "crosshair.lineLength"
        static let gapSize = "crosshair.gapSize"
        static let opacity = "crosshair.opacity"
        static let outline = "crosshair.outline"
        static let red = "crosshair.red"
        static let green = "crosshair.green"
        static let blue = "crosshair.blue"
    }

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        style = Style(rawValue: defaults.string(forKey: Key.style) ?? "") ?? .cross
        lineWidth = defaults.object(forKey: Key.lineWidth) as? Double ?? 2
        lineLength = defaults.object(forKey: Key.lineLength) as? Double ?? 18
        gapSize = defaults.object(forKey: Key.gapSize) as? Double ?? 5
        opacity = defaults.object(forKey: Key.opacity) as? Double ?? 0.85
        outline = defaults.object(forKey: Key.outline) as? Bool ?? true
        red = defaults.object(forKey: Key.red) as? Double ?? 0.15
        green = defaults.object(forKey: Key.green) as? Double ?? 1.0
        blue = defaults.object(forKey: Key.blue) as? Double ?? 0.35
    }

    var color: NSColor {
        get { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
        set {
            let color = newValue.usingColorSpace(.deviceRGB) ?? newValue
            red = Double(color.redComponent)
            green = Double(color.greenComponent)
            blue = Double(color.blueComponent)
        }
    }
}

@MainActor
final class OverlayController {
    private let settings: CrosshairSettings
    private var windows: [OverlayWindow] = []

    init(settings: CrosshairSettings) {
        self.settings = settings
    }

    func refresh() {
        let screens = NSScreen.screens
        if windows.count != screens.count {
            windows.forEach { $0.orderOut(nil) }
            windows = screens.map { screen in
                let window = OverlayWindow(screen: screen, settings: settings)
                window.orderFrontRegardless()
                return window
            }
        } else {
            for (window, screen) in zip(windows, screens) {
                window.setFrame(screen.frame, display: true)
            }
        }

        for window in windows {
            if settings.isEnabled {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
            window.overlayView?.needsDisplay = true
        }
    }
}

@MainActor
final class OverlayWindow: NSWindow {
    weak var overlayView: CrosshairView?

    init(screen: NSScreen, settings: CrosshairSettings) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let view = CrosshairView(settings: settings)
        contentView = view
        overlayView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class CrosshairView: NSView {
    private let settings: CrosshairSettings
    private var observation: AnyCancellable?

    init(settings: CrosshairSettings) {
        self.settings = settings
        super.init(frame: .zero)
        observation = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.needsDisplay = true }
        }
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard settings.isEnabled, let context = NSGraphicsContext.current?.cgContext else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let width = CGFloat(settings.lineWidth)
        let length = CGFloat(settings.lineLength)
        let gap = CGFloat(settings.gapSize)
        let alpha = CGFloat(settings.opacity)
        let color = settings.color.withAlphaComponent(alpha)
        let outline = NSColor.black.withAlphaComponent(alpha)

        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch settings.style {
        case .cross, .dot:
            let arms = crosshairPaths(center: center, length: length, gap: gap)
            if settings.outline {
                stroke(arms, in: context, color: outline, width: width + 2)
            }
            stroke(arms, in: context, color: color, width: width)
            if settings.style == .dot {
                let diameter = max(width * 2, 3)
                let dot = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
                if settings.outline {
                    context.setFillColor(outline.cgColor)
                    context.fillEllipse(in: dot.insetBy(dx: -1, dy: -1))
                }
                context.setFillColor(color.cgColor)
                context.fillEllipse(in: dot)
            }
        case .circle:
            let radius = length
            let ring = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            var paths = [CGPath(ellipseIn: ring, transform: nil)]
            let tickEnd = max(gap, radius - 3)
            if gap < tickEnd {
                paths += [
                    linePath(from: CGPoint(x: center.x - tickEnd, y: center.y), to: CGPoint(x: center.x - gap, y: center.y)),
                    linePath(from: CGPoint(x: center.x + gap, y: center.y), to: CGPoint(x: center.x + tickEnd, y: center.y)),
                    linePath(from: CGPoint(x: center.x, y: center.y - tickEnd), to: CGPoint(x: center.x, y: center.y - gap)),
                    linePath(from: CGPoint(x: center.x, y: center.y + gap), to: CGPoint(x: center.x, y: center.y + tickEnd))
                ]
            }
            if settings.outline {
                stroke(paths, in: context, color: outline, width: width + 2)
            }
            stroke(paths, in: context, color: color, width: width)
        }
        context.restoreGState()
    }

    private func crosshairPaths(center: CGPoint, length: CGFloat, gap: CGFloat) -> [CGPath] {
        [
            linePath(from: CGPoint(x: center.x - gap - length, y: center.y), to: CGPoint(x: center.x - gap, y: center.y)),
            linePath(from: CGPoint(x: center.x + gap, y: center.y), to: CGPoint(x: center.x + gap + length, y: center.y)),
            linePath(from: CGPoint(x: center.x, y: center.y - gap - length), to: CGPoint(x: center.x, y: center.y - gap)),
            linePath(from: CGPoint(x: center.x, y: center.y + gap), to: CGPoint(x: center.x, y: center.y + gap + length))
        ]
    }

    private func linePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private func stroke(_ paths: [CGPath], in context: CGContext, color: NSColor, width: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        paths.forEach { context.addPath($0) }
        context.strokePath()
    }
}

import Combine

private struct SettingsView: View {
    @ObservedObject var settings: CrosshairSettings

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: settings.color) },
            set: { settings.color = NSColor($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("准星设置").font(.title2.weight(.semibold))
                    Text("调整后会立即显示在所有屏幕中央").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("启用", isOn: $settings.isEnabled).labelsHidden()
                    .toggleStyle(.switch)
            }

            GroupBox("样式") {
                Picker("准星样式", selection: $settings.style) {
                    ForEach(CrosshairSettings.Style.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
            }

            GroupBox("外观") {
                VStack(spacing: 13) {
                    valueSlider("线宽", value: $settings.lineWidth, range: 1...10, unit: "pt")
                    valueSlider("长度", value: $settings.lineLength, range: 5...50, unit: "pt")
                    valueSlider("间隙", value: $settings.gapSize, range: 0...20, unit: "pt")
                    valueSlider("透明度", value: $settings.opacity, range: 0.1...1, unit: "%", percent: true)
                }
                .padding(.top, 6)
            }

            GroupBox("颜色") {
                VStack(alignment: .leading, spacing: 12) {
                    ColorPicker("准星颜色", selection: colorBinding, supportsOpacity: false)
                    Toggle("添加黑色描边", isOn: $settings.outline)
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "menubar.rectangle")
                Text("点击菜单栏的准星图标，可快速显示或隐藏。")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(width: 380, height: 590)
    }

    private func valueSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        percent: Bool = false
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(percent ? "\(Int(value.wrappedValue * 100))%" : "\(Int(value.wrappedValue)) \(unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
