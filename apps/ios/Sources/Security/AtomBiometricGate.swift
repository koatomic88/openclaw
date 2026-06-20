import Foundation
import LocalAuthentication

enum AtomBiometricGate {
    static func authorize(reason: String) async -> String? {
        await withCheckedContinuation { continuation in
            let context = LAContext()
            context.localizedCancelTitle = "Cancel"
            context.localizedFallbackTitle = "Use Passcode"

            var authError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
                let message = authError?.localizedDescription ?? "Face ID or passcode is not available on this device."
                continuation.resume(returning: message)
                return
            }

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: nil)
                    return
                }
                let message = error?.localizedDescription ?? "Authorization was cancelled."
                continuation.resume(returning: message)
            }
        }
    }
}
