import SwiftUI

struct SignedDecimalKeyboardModifier: ViewModifier {
    @Binding var text: String

    func body(content: Content) -> some View {
        content
            .keyboardType(.decimalPad)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(action: toggleSign) {
                        Text("±")
                            .font(.headline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .accessibilityLabel(Text("Toggle sign"))
                }
            }
    }

    private func toggleSign() {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNegative = trimmed.hasPrefix("-")
        trimmed = trimmed.replacingOccurrences(of: "-", with: "")

        if isNegative {
            text = trimmed
        } else {
            text = trimmed.isEmpty ? "-" : "-\(trimmed)"
        }
    }
}

extension View {
    func signedDecimalKeyboard(text: Binding<String>) -> some View {
        modifier(SignedDecimalKeyboardModifier(text: text))
    }
}
