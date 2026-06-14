import SwiftUI

/// A single, app-wide channel for surfacing user-facing errors as an alert, so
/// failures (an unavailable file, a folder that moved, a failed pin) produce a
/// clear message instead of a silent no-op. Injected into the environment by
/// `ContentView`; call `present(_:_:)` from anywhere in the view tree.
@MainActor
@Observable
final class ErrorPresenter {
    var current: PresentedError?

    func present(_ title: String, _ message: String) {
        current = PresentedError(title: title, message: message)
    }
}

struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
