import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showPinEditor = false
    @State private var pendingLockEnable = false
    @State private var pendingBiometricDisable = false
    @State private var activeDialog: AppDialog?

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                securitySection
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showPinEditor) {
            PinSetupView { result in
                handlePinResult(result)
            }
            .environmentObject(settings)
        }
        .onAppear {
            settings.refreshBiometricState()
        }
        .appDialog($activeDialog)
    }

    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Picker("Theme", selection: Binding(get: {
                settings.selectedTheme
            }, set: { newValue in
                settings.selectedTheme = newValue
            })) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var securitySection: some View {
        Section(header: Text("Security"), footer: Text(securityFooterText)) {
            Toggle("App Lock", isOn: appLockBinding)

            if settings.isAppLockEnabled {
                if settings.biometricState.available {
                    Toggle("Use \(settings.biometricState.displayName)", isOn: biometricBinding)
                } else {
                    Label("Biometrics are not available on this device.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                showPinEditor = true
            } label: {
                Label(settings.hasPin ? "Change PIN" : "Set PIN", systemImage: "key")
            }
        }
    }

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { settings.isAppLockEnabled },
            set: { newValue in
                if newValue {
                    settings.refreshBiometricState()
                    if settings.hasPin {
                        settings.isAppLockEnabled = true
                    } else if settings.biometricState.available {
                        settings.setAllowBiometrics(true)
                        settings.isAppLockEnabled = true
                    } else {
                        pendingLockEnable = true
                        showPinEditor = true
                    }
                } else {
                    settings.isAppLockEnabled = false
                }
            }
        )
    }

    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { settings.canUseBiometrics },
            set: { newValue in
                if newValue {
                    settings.refreshBiometricState()
                    if settings.biometricState.available {
                        settings.setAllowBiometrics(true)
                    }
                } else {
                    if settings.isAppLockEnabled && !settings.hasPin {
                        pendingBiometricDisable = true
                        showPinEditor = true
                    } else {
                        settings.setAllowBiometrics(false)
                    }
                }
            }
        )
    }

    private var securityFooterText: String {
        if settings.isAppLockEnabled {
            if settings.canUseBiometrics && settings.hasPin {
                return "Unlock with \(settings.biometricState.displayName) or your PIN."
            } else if settings.canUseBiometrics {
                return "Unlock with \(settings.biometricState.displayName). Set a PIN as a fallback."
            } else if settings.hasPin {
                return "Enter your PIN whenever you open the app."
            } else {
                return "Add a PIN so you have a fallback method in case biometrics are unavailable."
            }
        } else if settings.hasPin {
            return "Enable app lock to require your PIN or biometrics on launch."
        } else {
            return "Set a PIN or enable biometrics to turn on app lock."
        }
    }

    private func handlePinResult(_ result: PinSetupResult) {
        switch result {
        case .saved:
            if pendingLockEnable {
                settings.isAppLockEnabled = true
            }
            if pendingBiometricDisable {
                settings.setAllowBiometrics(false)
            }
        case .cleared:
            if settings.isAppLockEnabled && !settings.canUseBiometrics {
                settings.isAppLockEnabled = false
                activeDialog = AppDialog.info(title: "App Lock Disabled", message: "App lock was turned off because no PIN or biometrics are configured.")
            }
        case .cancelled:
            if pendingLockEnable {
                activeDialog = AppDialog.info(title: "App Lock Not Enabled", message: "Set a PIN or enable biometrics to secure the app.")
            }
            if pendingBiometricDisable {
                settings.setAllowBiometrics(true)
            }
        }

        pendingLockEnable = false
        pendingBiometricDisable = false
    }
}

private enum PinSetupResult {
    case saved
    case cleared
    case cancelled
}

private struct PinSetupView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var newPin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    let onFinish: (PinSetupResult) -> Void

    private enum Field {
        case pin
        case confirm
    }

    private let minimumLength = 4
    private let maximumLength = 12

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("PIN")) {
                    SecureField("New PIN", text: $newPin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .pin)
                        .onChange(of: newPin) { _, newValue in
                            sanitize(&newPin, newValue: newValue)
                        }

                    SecureField("Confirm PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .confirm)
                        .onChange(of: confirmPin) { _, newValue in
                            sanitize(&confirmPin, newValue: newValue)
                        }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if settings.hasPin {
                    Section {
                        Button(role: .destructive) {
                            removePin()
                        } label: {
                            Label("Remove PIN", systemImage: "trash")
                        }
                        .disabled(settings.isAppLockEnabled && !settings.canUseBiometrics)
                    } footer: {
                        if settings.isAppLockEnabled && !settings.canUseBiometrics {
                            Text("Add biometrics or disable app lock before removing your PIN.")
                        } else {
                            Text("Removing your PIN leaves biometrics as the only way to unlock the app.")
                        }
                    }
                }
            }
            .navigationTitle(settings.hasPin ? "Change PIN" : "Set PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePin() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    private var canSave: Bool {
        !newPin.isEmpty && !confirmPin.isEmpty
    }

    private func sanitize(_ binding: inout String, newValue: String) {
        let filtered = newValue.filter { $0.isNumber }
        if filtered != newValue {
            binding = filtered
        }
        if binding.count > maximumLength {
            binding = String(binding.prefix(maximumLength))
        }
        if !binding.isEmpty {
            errorMessage = nil
        }
    }

    private func savePin() {
        guard newPin.count >= minimumLength else {
            errorMessage = "PIN must be at least \(minimumLength) digits long."
            return
        }
        guard newPin == confirmPin else {
            errorMessage = "PIN entries do not match."
            return
        }
        settings.setPin(newPin)
        onFinish(.saved)
        dismiss()
    }

    private func removePin() {
        settings.clearPin()
        onFinish(.cleared)
        dismiss()
    }

    private func cancel() {
        onFinish(.cancelled)
        dismiss()
    }
}
