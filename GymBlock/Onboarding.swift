import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: GymStore
    @FocusState private var nameFocused: Bool
    @State private var annual = true
    private var step: Int { store.profile.onboardingStep }
    private var valid: Bool {
        switch step {
        case 0: return !store.profile.language.isEmpty
        case 1: return !store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: return !store.profile.training.isEmpty
        case 4: return store.profile.blockWholePhone || !store.profile.blockedApps.isEmpty
        default: return true
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step > 0 {
                    Button { nameFocused = false; store.updateProfile { $0.onboardingStep -= 1 } } label: {
                        Image(systemName: "arrow.left").frame(width: 44, height: 44)
                    }.accessibilityLabel(store.t("Back")).accessibilityIdentifier("onboarding.back")
                } else { Image(systemName: "dumbbell.fill").frame(width: 44, height: 44) }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<6) { index in Capsule().fill(index <= step ? GymColor.red : GymColor.ink.opacity(0.12)).frame(width: index == step ? 28 : 12, height: 5) }
                }.accessibilityLabel("\(step + 1) / 6")
                Spacer()
                Text(String(format: "%02d", step + 1)).font(.caption.monospacedDigit()).frame(width: 44)
            }.padding(.horizontal, 16).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { content }
                    .padding(24).padding(.top, 10)
            }.scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                GymButton(title: store.t(step == 5 ? "Enter prototype" : "Continue"), icon: "arrow.right", enabled: valid, id: "onboarding.continue") {
                    nameFocused = false
                    let currentStep = step
                    store.updateProfile { profile in
                        profile.name = String(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                        if currentStep == 5 { profile.onboarded = true }
                        else { profile.onboardingStep += 1 }
                    }
                }
                if step == 5 { Text(store.t("No payment. No trial. No charge.")).font(.caption).foregroundStyle(GymColor.dim) }
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
        }
    }
    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            GymMark(size: 124).frame(maxWidth: .infinity).padding(.vertical, 14)
            PageTitle(eyebrow: "GYMBLOCK", title: "Choose your language.", subtitle: "Your workout. Your words.")
            ChoiceRow(title: "English", subtitle: "Let's get moving", selected: store.profile.language == "en", id: "language.en") { store.updateProfile { $0.language = "en" } }
            ChoiceRow(title: "Español", subtitle: "Vamos a movernos", selected: store.profile.language == "es", id: "language.es") { store.updateProfile { $0.language = "es" } }
        case 1:
            PageTitle(eyebrow: store.t("Your name"), title: store.t("What should we call you?"), subtitle: store.t("Just a name. No account needed."))
            TextField(store.t("Your name"), text: $store.data.profile.name)
                .font(.system(.largeTitle, design: .default, weight: .semibold))
                .textContentType(.givenName).submitLabel(.done).focused($nameFocused)
                .padding(24).background(GymColor.surface, in: RoundedRectangle(cornerRadius: 24))
                .accessibilityIdentifier("name.field").onSubmit { nameFocused = false }
                .onChange(of: store.data.profile.name) { _, _ in store.persist() }
            GymMark(size: 155).frame(maxWidth: .infinity).padding(.top, 35)
        case 2:
            PageTitle(eyebrow: store.t("Your training"), title: store.t("How do you like to move?"), subtitle: store.t("Pick as many as you like."))
            ForEach(Array(zip(["Cardio", "Weightlifting", "Stretching", "Compound movements", "Martial arts"], ["figure.run", "dumbbell.fill", "figure.flexibility", "figure.strengthtraining.traditional", "figure.boxing"])), id: \.0) { type, icon in
                ChoiceRow(title: store.t(type), icon: icon, selected: store.profile.training.contains(type), id: "training.\(type)") {
                    store.updateProfile { profile in
                        if profile.training.contains(type) { profile.training.removeAll { $0 == type } }
                        else { profile.training.append(type) }
                    }
                }
            }
        case 3:
            PageTitle(eyebrow: store.t("Your favorites"), title: store.t("The moves you love."), subtitle: store.t("Pick a few. They'll be ready for your first workout."))
            FavoritePicker()
        case 4:
            PageTitle(eyebrow: store.t("Your focus"), title: store.t("Less scroll. More strength."), subtitle: store.t("Choose what goes quiet during a session."))
            BlockingPicker()
        default:
            GymMark(size: 116).frame(maxWidth: .infinity)
            PageTitle(eyebrow: "GYMBLOCK PLUS", title: store.t("Make room for your workout."), subtitle: store.t("Your focus, your workouts, your progress. One simple place."))
            VStack(alignment: .leading, spacing: 14) {
                ForEach(["Unlimited sessions", "Simple workout logging", "A little consistency, every week"], id: \.self) { text in
                    Label(store.t(text), systemImage: "checkmark.circle.fill").foregroundStyle(GymColor.blue).font(.subheadline.weight(.medium))
                }
            }
            VStack(spacing: 10) {
                ChoiceRow(title: store.t("Annual"), subtitle: "$29.99 / " + (store.profile.language == "es" ? "año" : "year"), selected: annual, id: "price.annual") { annual = true }
                ChoiceRow(title: store.t("Monthly"), subtitle: "$3.99 / " + (store.profile.language == "es" ? "mes" : "month"), selected: !annual, id: "price.monthly") { annual = false }
                Text(store.t("Placeholder prices · USD")).font(.caption).foregroundStyle(GymColor.dim)
            }
        }
    }
}
struct FavoritePicker: View {
    @EnvironmentObject private var store: GymStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Exercise.areas, id: \.self) { area in
                Text(store.t(area == "Back" ? "Back & lats" : area)).font(.subheadline.weight(.bold)).foregroundStyle(GymColor.dim).padding(.top, 12)
                ForEach(Exercise.catalog.filter { $0.area == area }) { exercise in
                    ChoiceRow(title: store.t(exercise.name), selected: store.profile.favorites.contains(exercise.id), id: "favorite.\(exercise.id)") {
                        store.updateProfile { profile in
                            if profile.favorites.contains(exercise.id) { profile.favorites.removeAll { $0 == exercise.id } }
                            else { profile.favorites.append(exercise.id) }
                        }
                    }
                }
            }
        }
    }
}
struct BlockingPicker: View {
    @EnvironmentObject private var store: GymStore
    var body: some View {
        VStack(spacing: 12) {
            ChoiceRow(title: store.t("Whole phone"), subtitle: store.t("Everything except GymBlock"), icon: "iphone", selected: store.profile.blockWholePhone, id: "blocking.whole") { store.updateProfile { $0.blockWholePhone = true } }
            ChoiceRow(title: store.t("Selected apps"), subtitle: store.t("Only the distractions you choose"), icon: "square.grid.2x2", selected: !store.profile.blockWholePhone, id: "blocking.selected") { store.updateProfile { $0.blockWholePhone = false } }
            if !store.profile.blockWholePhone {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(["Instagram", "TikTok", "YouTube", "Safari"], id: \.self) { name in
                        Button {
                            store.updateProfile { profile in
                                if profile.blockedApps.contains(name) { profile.blockedApps.removeAll { $0 == name } }
                                else { profile.blockedApps.append(name) }
                            }
                        } label: {
                            Label(name, systemImage: store.profile.blockedApps.contains(name) ? "checkmark.circle.fill" : "circle")
                                .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                                .background(GymColor.surface, in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain).accessibilityIdentifier("app.\(name)")
                    }
                }
                if store.profile.blockedApps.isEmpty { Text(store.t("Choose at least one app.")).font(.caption).foregroundStyle(GymColor.dim) }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label(store.t("SIMULATOR PREVIEW"), systemImage: "info.circle").font(.caption.weight(.bold)).tracking(1)
                    Text(store.t("Blocking is simulated. This prototype cannot restrict your phone or other apps.")).font(.subheadline).foregroundStyle(GymColor.dim)
                }
            }.padding(.top, 4)
        }
    }
}
