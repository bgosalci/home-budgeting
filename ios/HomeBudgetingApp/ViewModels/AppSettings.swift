import SwiftUI
import LocalAuthentication

@MainActor
public final class AppSettings: ObservableObject {
    struct BiometricState {
        let available: Bool
        let type: LABiometryType

        var displayName: String {
            switch type {
            case .faceID:
                return "Face ID"
            case .touchID:
                return "Touch ID"
            case .opticID:
                return "Optic ID"
            default:
                return "Biometrics"
            }
        }

        var iconName: String {
            switch type {
            case .faceID:
                return "faceid"
            case .touchID:
                return "touchid"
            case .opticID:
                return "opticid"
            default:
                return "lock"
            }
        }
    }

    @Published var selectedTheme: AppTheme {
        didSet {
            defaults.set(selectedTheme.rawValue, forKey: themeKey)
        }
    }

    @Published var isAppLockEnabled: Bool {
        didSet {
            guard !isBootstrapping else { return }
            defaults.set(isAppLockEnabled, forKey: lockEnabledKey)
            if isAppLockEnabled {
                lock()
            } else {
                unlock()
            }
        }
    }

    @Published private(set) var allowBiometrics: Bool
    @Published private(set) var hasPin: Bool
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var biometricState: BiometricState

    private let defaults: UserDefaults
    private let contextProvider: () -> LAContext
    private var isBootstrapping = true

    private let themeKey = "app_theme"
    private let lockEnabledKey = "app_lock_enabled"
    private let allowBiometricsKey = "app_lock_allow_biometrics"
    private let pinKey = "app_lock_pin"

    public init(
        defaults: UserDefaults = .standard,
        contextProvider: @escaping () -> LAContext = { LAContext() }
    ) {
        self.defaults = defaults
        self.contextProvider = contextProvider

        let storedTheme = defaults.string(forKey: themeKey).flatMap(AppTheme.init(rawValue:)) ?? .system
        selectedTheme = storedTheme

        let storedLock = defaults.bool(forKey: lockEnabledKey)
        isUnlocked = storedLock ? false : true
        isAppLockEnabled = storedLock

        let storedPin = defaults.string(forKey: pinKey)
        hasPin = !(storedPin ?? "").isEmpty

        let context = contextProvider()
        let computedBiometricState = Self.computeBiometricState(context: context)

        let storedBiometrics = defaults.object(forKey: allowBiometricsKey) as? Bool ?? true
        let allowBiometricsValue: Bool
        if computedBiometricState.available {
            allowBiometricsValue = storedBiometrics
        } else {
            allowBiometricsValue = false
            defaults.set(false, forKey: allowBiometricsKey)
        }

        biometricState = computedBiometricState
        allowBiometrics = allowBiometricsValue
        isBootstrapping = false
    }

    var canUseBiometrics: Bool {
        allowBiometrics && biometricState.available
    }

    func setAllowBiometrics(_ value: Bool) {
        if value && !biometricState.available {
            allowBiometrics = false
            defaults.set(false, forKey: allowBiometricsKey)
        } else {
            allowBiometrics = value
            defaults.set(value, forKey: allowBiometricsKey)
        }
    }

    func setPin(_ newPin: String) {
        defaults.set(newPin, forKey: pinKey)
        hasPin = true
    }

    func clearPin() {
        defaults.removeObject(forKey: pinKey)
        hasPin = false
    }

    func verifyPin(_ pin: String) -> Bool {
        guard let stored = defaults.string(forKey: pinKey) else { return false }
        return stored == pin
    }

    func lock() {
        guard isAppLockEnabled else {
            isUnlocked = true
            return
        }
        isUnlocked = false
    }

    func unlock() {
        isUnlocked = true
    }

    func refreshBiometricState() {
        let context = contextProvider()
        biometricState = Self.computeBiometricState(context: context)
        if !biometricState.available {
            allowBiometrics = false
            defaults.set(false, forKey: allowBiometricsKey)
        }
    }

    func attemptBiometricUnlock(completion: @escaping (Bool, Error?) -> Void) {
        guard isAppLockEnabled else {
            unlock()
            completion(true, nil)
            return
        }
        guard canUseBiometrics else {
            completion(false, nil)
            return
        }
        let context = contextProvider()
        context.localizedFallbackTitle = "Enter PIN"
        let reason = "Authenticate to access your budget."
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.unlock()
                }
                completion(success, error)
            }
        }
    }

    private static func computeBiometricState(context: LAContext) -> BiometricState {
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return BiometricState(available: available, type: context.biometryType)
    }
}
