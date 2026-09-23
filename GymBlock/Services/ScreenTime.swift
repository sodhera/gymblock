import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

// App blocking via Apple's Screen Time APIs.
//
//   authorize  → FamilyControls individual authorization (one system prompt)
//   select     → FamilyActivityPicker; the opaque selection is stored in the
//                app group so it survives relaunch
//   lock       → shield the selection in the named `.gymblock` store, and
//                schedule the safety-cap DeviceActivity interval
//   unlock     → clear the store and stop the safety monitor
//
// The block is tied to the workout, not a schedule ("earn your unlock"):
// Start Workout locks, holding Finish unlocks. See DESIGN.md → "The block".

enum ScreenTimeState: Equatable {
    case notDetermined, denied, approved
}

@MainActor
@Observable
final class ScreenTimeController {
    private(set) var state: ScreenTimeState = .notDetermined
    private(set) var selection = FamilyActivitySelection()
    private let store = ManagedSettingsStore(named: .gymblock)
    private let center = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()

    private static let selectionKey = "blocking.selection.v1"

    /// The Simulator has no Screen Time daemon; authorization never succeeds.
    var isSupported: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    init() {
        selection = Self.loadSelection()
        refreshState()
    }

    func refreshState() {
        switch center.authorizationStatus {
        case .approved: state = .approved
        case .denied: state = .denied
        default: state = .notDetermined
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            try await center.requestAuthorization(for: .individual)
        } catch {
            AppLog.block.error("Screen Time authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshState()
        return state == .approved
    }

    // MARK: Selection

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    var appCount: Int { selection.applicationTokens.count }
    var categoryCount: Int { selection.categoryTokens.count }

    /// "6 apps", "2 categories", "6 apps, 1 category", "None".
    var selectionSummary: String {
        var parts: [String] = []
        if appCount > 0 { parts.append(appCount == 1 ? "1 app" : "\(appCount) apps") }
        if categoryCount > 0 { parts.append(categoryCount == 1 ? "1 category" : "\(categoryCount) categories") }
        return parts.isEmpty ? "None" : parts.joined(separator: ", ")
    }

    func updateSelection(_ new: FamilyActivitySelection) {
        selection = new
        if let data = try? JSONEncoder().encode(new) {
            SharedWorkoutState.defaults.set(data, forKey: Self.selectionKey)
        }
        // A workout already running picks up the new selection immediately.
        if isLocked { applyShield() }
    }

    private static func loadSelection() -> FamilyActivitySelection {
        guard let data = SharedWorkoutState.defaults.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    // MARK: Lock / unlock

    /// Whether the store currently holds a shield we applied.
    var isLocked: Bool {
        store.shield.applications != nil || store.shield.applicationCategories != nil
    }

    /// True when starting a workout will actually block something.
    var willBlock: Bool { state == .approved && hasSelection }

    func lock() {
        guard willBlock else {
            AppLog.block.info("Lock skipped (authorized=\(self.state == .approved), selection=\(self.hasSelection))")
            return
        }
        applyShield()
        scheduleSafetyCap()
        AppLog.block.info("Apps locked")
    }

    func unlock() {
        store.clearAllSettings()
        activityCenter.stopMonitoring([DeviceActivityName(SharedSchedule.safetyActivity)])
        SharedWorkoutState.clear()
        AppLog.block.info("Apps unlocked")
    }

    private func applyShield() {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func scheduleSafetyCap() {
        let cal = Calendar.current
        let now = Date()
        guard let end = cal.date(byAdding: .hour, value: SharedSchedule.safetyCapHours, to: now) else { return }
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(components, from: now),
            intervalEnd: cal.dateComponents(components, from: end),
            repeats: false
        )
        do {
            try activityCenter.startMonitoring(DeviceActivityName(SharedSchedule.safetyActivity), during: schedule)
        } catch {
            AppLog.block.error("Safety cap schedule failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Picker sheet

/// Apple's app picker in GymBlock chrome. The selection only commits on Done.
struct BlockedAppsPicker: View {
    @Environment(ScreenTimeController.self) private var screenTime
    @Environment(\.dismiss) private var dismiss
    @State private var draft = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $draft)
                .navigationTitle("Apps to lock")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            Haptics.lock()
                            screenTime.updateSelection(draft)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .onAppear { draft = screenTime.selection }
    }
}
