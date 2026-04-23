import AppIntents
import Foundation

/// Focus Filter that the system invokes when a configured Focus mode activates or deactivates.
///
/// Setup: System Settings > Focus > [mode] > Focus Filters > Add Filter > WAIWO
/// The "Hide Overlay" toggle should be ON (which it is by default when adding the filter).
///
/// When the Focus mode activates, perform() is called with hideOverlay = true (configured value).
/// When it deactivates, perform() is called with hideOverlay = false (the parameter default).
struct WAIWOFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Hide WAIWO Overlay"
    static let description: IntentDescription = "Hides the WAIWO overlay when this Focus mode is active."

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Hide WAIWO Overlay")
    }

    /// Default is false. When the user adds this filter, they toggle it to true.
    /// On deactivation, the system resets to the default (false).
    @Parameter(title: "Hide Overlay", default: false)
    var hideOverlay: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        print("FocusFilter: perform() called, hideOverlay=\(hideOverlay)")
        FocusMonitor.shared.setFocusActive(hideOverlay)
        return .result()
    }
}

@MainActor
final class FocusMonitor {
    static let shared = FocusMonitor()
    var onFocusModeChanged: ((Bool) -> Void)?
    private(set) var isFocusActive = false

    private init() {}

    func start() {}
    func stop() {}

    func setFocusActive(_ active: Bool) {
        guard active != isFocusActive else { return }
        isFocusActive = active
        print("FocusMonitor: Focus mode \(active ? "activated" : "deactivated")")
        onFocusModeChanged?(active)
    }
}
