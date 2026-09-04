import SwiftUI
import AppKit

/// Frosted window backing, matching the desktop widgets.
///
/// `.behindWindow` blending samples the wallpaper behind the window, which is
/// what gives widgets their translucency; the window itself must be
/// non-opaque with a clear background for it to show through.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
