import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var pin: String = ""
    @State private var errorMessage: String?
    @State private var isAttemptingBiometric = false
    @State private var attemptedBiometric = false
    @FocusState private var focusedField: Bool

    private let maxPinLength = 12

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)

                Text("Home Budgeting Locked")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Authenticate to continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if settings.hasPin {
                    VStack(spacing: 12) {
                        SecureField("Enter PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focusedField)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onChange(of: pin) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    pin = filtered
                                }
                                if pin.count > maxPinLength {
                                    pin = String(pin.prefix(maxPinLength))
                                }
                            }

                        Button {
                            verifyPin()
                        } label: {
                            Label("Unlock", systemImage: "lock.open")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(pin.isEmpty)
                    }
                    .padding(.horizontal)
                }

                if settings.canUseBiometrics {
                    Button {
                        attemptBiometric(force: true)
                    } label: {
                        HStack {
                            Image(systemName: settings.biometricState.iconName)
                            Text("Use \(settings.biometricState.displayName)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAttemptingBiometric)
                }

                if isAttemptingBiometric {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                }

                Spacer()
            }
            .padding(.top, 80)
            .padding(.bottom, 40)
            .frame(maxWidth: 420)
        }
        .onAppear {
            if settings.canUseBiometrics {
                attemptBiometric(force: false)
            } else if settings.hasPin {
                focusedField = true
            }
        }
    }

    private func verifyPin() {
        if settings.verifyPin(pin) {
            settings.unlock()
            pin = ""
            errorMessage = nil
        } else {
            errorMessage = "Incorrect PIN. Try again."
            pin = ""
            focusedField = true
        }
    }

    private func attemptBiometric(force: Bool) {
        guard settings.canUseBiometrics else { return }
        if attemptedBiometric && !force { return }
        attemptedBiometric = true
        isAttemptingBiometric = true
        errorMessage = nil
        settings.attemptBiometricUnlock { success, error in
            isAttemptingBiometric = false
            if !success {
                if let laError = error as? LAError {
                    switch laError.code {
                    case .userCancel, .systemCancel:
                        errorMessage = nil
                    case .userFallback:
                        errorMessage = nil
                    case .biometryNotEnrolled, .biometryLockout:
                        settings.setAllowBiometrics(false)
                        errorMessage = "Biometric authentication is unavailable. Enter your PIN."
                    default:
                        errorMessage = laError.localizedDescription
                    }
                } else if let error {
                    errorMessage = error.localizedDescription
                } else if force {
                    errorMessage = "Authentication failed. Try again."
                }
                if settings.hasPin {
                    focusedField = true
                }
            } else {
                pin = ""
                errorMessage = nil
            }
        }
    }
}
