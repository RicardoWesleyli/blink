import AppKit

private enum Bootstrap {
    @MainActor static var delegate: AppDelegate?
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    Bootstrap.delegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
