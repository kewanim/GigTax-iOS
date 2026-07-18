import UIKit

extension UIApplication: @retroactive UIGestureRecognizerDelegate {
    /// Attaches a window-level tap recognizer that resigns first responder on any tap,
    /// so tapping outside a text field dismisses the keyboard app-wide (including sheets).
    func addKeyboardDismissRecognizer() {
        guard let window = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }

        guard !(window.gestureRecognizers ?? []).contains(where: { $0.name == "keyboardDismissTap" }) else { return }

        let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tapGesture.name = "keyboardDismissTap"
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        window.addGestureRecognizer(tapGesture)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
