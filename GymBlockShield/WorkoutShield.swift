import ManagedSettings
import ManagedSettingsUI
import UIKit

/// What iOS shows over a blocked app during a workout: the brand mark on the paper stage, ink type and
/// one ink button that sends you back (it posts a notification that opens GymBlock; see
/// `WorkoutShieldAction`). It runs in its own process, so it follows the iPhone's language rather than
/// GymBlock's in-app setting.
final class WorkoutShield: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ManagedSettingsUI.ShieldConfiguration {
    make(application.localizedDisplayName)
  }
  override func configuration(shielding application: Application, in category: ActivityCategory) -> ManagedSettingsUI.ShieldConfiguration {
    make(application.localizedDisplayName)
  }
  override func configuration(shielding webDomain: WebDomain) -> ManagedSettingsUI.ShieldConfiguration {
    make(webDomain.domain)
  }
  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ManagedSettingsUI.ShieldConfiguration {
    make(webDomain.domain)
  }

  private static let paper = UIColor(red: 0.961, green: 0.953, blue: 0.937, alpha: 1)
  private static let ink = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
  private static let secondary = UIColor(red: 0.40, green: 0.40, blue: 0.42, alpha: 1)
  private static let spanish = Locale.preferredLanguages.first?.hasPrefix("es") == true

  private func make(_ name: String?) -> ManagedSettingsUI.ShieldConfiguration {
    let es = Self.spanish
    let subject = name ?? (es ? "Esta app" : "This app")
    // The app's own mark (rendered by scripts/generate-app-icon.swift --mark), not a generic symbol.
    let icon = UIImage(named: "ShieldMark")
    return ManagedSettingsUI.ShieldConfiguration(
      backgroundBlurStyle: .systemThickMaterialLight,
      backgroundColor: Self.paper,
      icon: icon,
      title: .init(text: es ? "Estás entrenando." : "You’re mid-workout.", color: Self.ink),
      subtitle: .init(text: es ? "\(subject) se abre cuando termines o pauses el entrenamiento en GymBlock."
                               : "\(subject) opens when you finish or pause your workout in GymBlock.", color: Self.secondary),
      // Pure white: the paper tone read as a dimmed, disabled label on the ink button.
      primaryButtonLabel: .init(text: es ? "Volver al entrenamiento" : "Back to training", color: .white),
      primaryButtonBackgroundColor: Self.ink)
  }
}
