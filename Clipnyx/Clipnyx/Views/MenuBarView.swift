import SwiftUI

struct MenuBarView: View {
    @Environment(ClipboardManager.self) private var clipboardManager

    var body: some View {
        PopupContentView(
            clipboardManager: clipboardManager,
            isMenuBar: true,
            onDismiss: {},
            onPaste: {}
        )
        .frame(width: 360)
        .onAppear {
            NotificationCenter.default.post(name: .closePopupPanel, object: nil)
        }
    }
}
