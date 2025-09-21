import SwiftUI

struct AppDialog: Identifiable {
    enum Style {
        case info
        case error
        case confirm(destructive: Bool)
    }

    let id = UUID()
    let style: Style
    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String?
    let onConfirm: (() -> Void)?

    init(style: Style, title: String, message: String? = nil, confirmTitle: String = "OK", cancelTitle: String? = nil, onConfirm: (() -> Void)? = nil) {
        self.style = style
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.onConfirm = onConfirm
    }
}

extension AppDialog {
    static func info(title: String, message: String? = nil, buttonTitle: String = "OK", onDismiss: (() -> Void)? = nil) -> AppDialog {
        AppDialog(style: .info, title: title, message: message, confirmTitle: buttonTitle, onConfirm: onDismiss)
    }

    static func error(title: String, message: String? = nil, buttonTitle: String = "OK", onDismiss: (() -> Void)? = nil) -> AppDialog {
        AppDialog(style: .error, title: title, message: message, confirmTitle: buttonTitle, onConfirm: onDismiss)
    }

    static func confirm(title: String, message: String? = nil, confirmTitle: String = "Confirm", cancelTitle: String = "Cancel", destructive: Bool = false, onConfirm: (() -> Void)? = nil) -> AppDialog {
        AppDialog(style: .confirm(destructive: destructive), title: title, message: message, confirmTitle: confirmTitle, cancelTitle: cancelTitle, onConfirm: onConfirm)
    }
}

extension AppDialog {
    fileprivate func makeAlert() -> Alert {
        let messageText = message.map(Text.init)
        switch style {
        case .info, .error:
            return Alert(
                title: Text(title),
                message: messageText,
                dismissButton: .default(Text(confirmTitle)) {
                    onConfirm?()
                }
            )
        case .confirm(let destructive):
            let primary: Alert.Button = destructive
                ? .destructive(Text(confirmTitle)) { onConfirm?() }
                : .default(Text(confirmTitle)) { onConfirm?() }
            let cancelButton: Alert.Button = {
                if let cancelTitle {
                    return .cancel(Text(cancelTitle))
                } else {
                    return .cancel()
                }
            }()
            return Alert(
                title: Text(title),
                message: messageText,
                primaryButton: primary,
                secondaryButton: cancelButton
            )
        }
    }
}

extension View {
    func appDialog(_ dialog: Binding<AppDialog?>) -> some View {
        alert(item: dialog) { dialog in
            dialog.makeAlert()
        }
    }
}
