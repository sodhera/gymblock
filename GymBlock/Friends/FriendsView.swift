import SwiftUI

/// Friends are a list of weeks, not a feed. Each row is a person and their
/// seven circles — who's showing up is visible at a glance. No likes, no
/// comments; the only social verb is a nudge.
struct FriendsView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GBSpace.xl) {
                    content
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.bottom, 120)
            }
            .paperBackground()
            .refreshable { await store.refreshFriends() }
            .navigationTitle("Friends")
            .toolbar {
                if canUseFriends && store.myPublicProfile != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add friend", systemImage: "person.badge.plus") { adding = true }
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let card = store.friends.friends.first(where: { $0.id == id }) {
                    FriendDetailView(card: card)
                }
            }
            .sheet(isPresented: $adding) { AddFriendSheet(initialUsername: store.pendingInvite ?? "") }
            .onChange(of: store.pendingInvite) { _, invite in
                if invite != nil, canUseFriends { adding = true }
            }
            .task { await store.refreshFriends() }
        }
    }

    private var canUseFriends: Bool { store.friendsService.isConfigured && store.account != nil }

    @ViewBuilder
    private var content: some View {
        if !canUseFriends {
            EmptyState(
                icon: "person.2",
                title: "Friends need an account",
                message: store.friendsService.isConfigured ? "Sign in to add friends." : "Friends aren't set up in this build yet."
            )
        } else if store.myPublicProfile == nil {
            ClaimUsernameCard()
        } else {
            meCard
            if !store.friends.incoming.isEmpty { incomingSection }
            friendsSection
            if !store.friends.outgoing.isEmpty { outgoingSection }
        }
    }

    // MARK: Me

    private var meCard: some View {
        let username = store.myPublicProfile?.username ?? ""
        return HStack(spacing: GBSpace.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your username").kicker()
                Text("@\(username)").font(GBFont.headline(18)).foregroundStyle(GBColor.ink)
            }
            Spacer()
            ShareLink(
                item: URL(string: "gymblock://add/\(username)")!,
                message: Text("Lift with me on GymBlock. My username is @\(username).")
            ) {
                Label("Invite", systemImage: "square.and.arrow.up")
                    .font(GBFont.label(15))
                    .foregroundStyle(GBColor.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .glassEffect(.regular.tint(GBColor.glassTint).interactive(), in: Capsule())
            }
        }
        .padding(GBSpace.md)
        .solidCard(cornerRadius: GBRadius.md)
    }

    // MARK: Sections

    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: GBSpace.sm) {
            Text("Requests").kicker(GBColor.orange)
            ForEach(store.friends.incoming) { person in
                HStack(spacing: GBSpace.sm) {
                    Avatar(profile: person)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name).font(GBFont.headline(16)).foregroundStyle(GBColor.ink)
                        Text("@\(person.username)").font(GBFont.body(13)).foregroundStyle(GBColor.steel)
                    }
                    Spacer()
                    Button {
                        Task {
                            try? await store.friendsService.remove(person.id)
                            await store.refreshFriends()
                        }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(GBColor.steel)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    Button("Accept") {
                        Haptics.success()
                        Task {
                            try? await store.friendsService.accept(person.id)
                            await store.refreshFriends()
                        }
                    }
                    .font(GBFont.label(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(GBColor.orange, in: Capsule())
                }
                .padding(GBSpace.sm)
                .solidCard(cornerRadius: GBRadius.md)
            }
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        if store.friends.friends.isEmpty {
            VStack(spacing: GBSpace.md) {
                EmptyState(icon: "person.2", title: "Lift with friends", message: "See each other's week, streak and PRs.\nInvite someone who'll keep you honest.")
                Button("Add friend") { adding = true }
                    .buttonStyle(.primary)
            }
        } else {
            VStack(alignment: .leading, spacing: GBSpace.sm) {
                Text("This week").kicker()
                ForEach(store.friends.friends) { card in
                    NavigationLink(value: card.id) {
                        FriendRow(card: card)
                    }
                    .buttonStyle(ScaleOnPress(scale: 0.98))
                }
            }
        }
    }

    private var outgoingSection: some View {
        VStack(alignment: .leading, spacing: GBSpace.xs) {
            Text("Pending").kicker()
            ForEach(store.friends.outgoing) { person in
                Text("Waiting on @\(person.username)")
                    .font(GBFont.body(15))
                    .foregroundStyle(GBColor.steel)
                    .padding(.horizontal, GBSpace.xxs)
            }
        }
    }
}

// MARK: - Rows

struct Avatar: View {
    var profile: PublicProfile
    var size: CGFloat = 40

    var body: some View {
        Text(profile.initials.isEmpty ? "?" : profile.initials)
            .font(.system(size: size * 0.38, weight: .bold).width(.expanded))
            .foregroundStyle(GBColor.ink)
            .frame(width: size, height: size)
            .background(GBColor.paper, in: Circle())
            .overlay(Circle().strokeBorder(GBColor.hairline))
    }
}

struct FriendRow: View {
    var card: FriendCard

    var body: some View {
        let week = card.week
        VStack(alignment: .leading, spacing: GBSpace.sm) {
            HStack(spacing: GBSpace.sm) {
                Avatar(profile: card.profile)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.profile.name).font(GBFont.headline(16)).foregroundStyle(GBColor.ink)
                    HStack(spacing: 4) {
                        if card.streak > 0 {
                            Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(GBColor.orange)
                            Text("\(card.streak) wk").foregroundStyle(GBColor.ink2)
                            Text("·")
                        }
                        Text(card.lastWorkout.map { "Last: \(Format.day($0.startedAt))" } ?? "No workouts yet")
                    }
                    .font(GBFont.body(13))
                    .foregroundStyle(GBColor.steel)
                }
                Spacer()
                Text("\(week.count)/\(week.target)")
                    .font(GBFont.number(17, weight: .bold))
                    .foregroundStyle(week.isComplete ? GBColor.orange : GBColor.ink)
            }
            WeekStrip(week: week, compact: true)
        }
        .padding(GBSpace.md)
        .solidCard(cornerRadius: GBRadius.md)
    }
}

// MARK: - Claim username

struct ClaimUsernameCard: View {
    @Environment(AppStore.self) private var store
    @State private var username = ""
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: GBSpace.md) {
            Text("Pick a username").font(GBFont.title(22)).foregroundStyle(GBColor.ink)
            Text("It's how friends find you. Letters, numbers and underscores.")
                .font(GBFont.body(15)).foregroundStyle(GBColor.steel)
            HStack(spacing: 2) {
                Text("@").font(GBFont.headline(18)).foregroundStyle(GBColor.fog)
                TextField("username", text: $username)
                    .font(GBFont.headline(18))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: username) { _, new in
                        let clean = Usernames.sanitize(new)
                        if clean != new { username = clean }
                        error = nil
                    }
            }
            .padding(.horizontal, GBSpace.md)
            .frame(height: 52)
            .background(GBColor.paper, in: RoundedRectangle(cornerRadius: GBRadius.sm, style: .continuous))
            if let error {
                Text(error).font(GBFont.body(14)).foregroundStyle(GBColor.danger)
            }
            Button(saving ? "Saving…" : "Claim @\(username.isEmpty ? "username" : username)") {
                saving = true
                Task {
                    do {
                        try await store.claimUsername(username)
                        Haptics.success()
                    } catch {
                        self.error = error.localizedDescription
                        Haptics.warning()
                    }
                    saving = false
                }
            }
            .buttonStyle(.primary)
            .disabled(!Usernames.isValid(username) || saving)
        }
        .padding(GBSpace.lg)
        .solidCard()
        .onAppear {
            if username.isEmpty { username = Usernames.sanitize(store.profile.name.replacingOccurrences(of: " ", with: "")) }
        }
    }
}

// MARK: - Add friend

struct AddFriendSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var initialUsername = ""
    @State private var username = ""
    @State private var message: String?
    @State private var isError = false
    @State private var sending = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GBSpace.md) {
                Text("Their username").kicker()
                HStack(spacing: 2) {
                    Text("@").font(GBFont.headline(20)).foregroundStyle(GBColor.fog)
                    TextField("username", text: $username)
                        .font(GBFont.headline(20))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit(send)
                }
                .padding(.horizontal, GBSpace.md)
                .frame(height: 56)
                .solidCard(cornerRadius: GBRadius.sm)

                if let message {
                    Text(message).font(GBFont.body(15)).foregroundStyle(isError ? GBColor.danger : GBColor.steel)
                }
                Spacer()
                Button(sending ? "Sending…" : "Send request", action: send)
                    .buttonStyle(.primary)
                    .disabled(Usernames.sanitize(username).count < 3 || sending)
            }
            .padding(GBSpace.margin)
            .paperBackground()
            .navigationTitle("Add friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { username = initialUsername }
        .onDisappear { store.pendingInvite = nil }
    }

    private func send() {
        sending = true
        Task {
            do {
                let person = try await store.friendsService.sendRequest(toUsername: username)
                Haptics.success()
                isError = false
                message = "Request sent to \(person.name)."
                await store.refreshFriends()
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            } catch {
                Haptics.warning()
                isError = true
                message = error.localizedDescription
            }
            sending = false
        }
    }
}

// MARK: - Friend detail

struct FriendDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var card: FriendCard
    @State private var nudged = false
    @State private var confirmRemove = false
    @State private var openDetail: WorkoutDetailRow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GBSpace.xl) {
                HStack(spacing: GBSpace.md) {
                    Avatar(profile: card.profile, size: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.profile.name).font(GBFont.title(24)).foregroundStyle(GBColor.ink)
                        Text("@\(card.profile.username)").font(GBFont.body(15)).foregroundStyle(GBColor.steel)
                    }
                }

                VStack(alignment: .leading, spacing: GBSpace.lg) {
                    Text("\(card.week.count) of \(card.week.target) this week")
                        .font(GBFont.headline(17)).foregroundStyle(GBColor.ink)
                    WeekStrip(week: card.week)
                }
                .padding(GBSpace.lg)
                .solidCard()

                HStack(spacing: 0) {
                    stat("Streak", card.streak == 1 ? "1 week" : "\(card.streak) weeks")
                    stat("Consistency", card.consistency.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                    stat("Workouts", "\(card.workouts.count)")
                }

                if !card.records.isEmpty {
                    VStack(alignment: .leading, spacing: GBSpace.sm) {
                        Text("Records").kicker()
                        VStack(spacing: 0) {
                            ForEach(card.records.prefix(8), id: \.exerciseID) { record in
                                HStack {
                                    Text(record.exerciseName).font(GBFont.headline(15)).foregroundStyle(GBColor.ink)
                                    Spacer()
                                    Text("\(Format.weight(record.weightKg, unit: store.profile.unit)) \(store.profile.unit.rawValue) × \(record.reps)")
                                        .font(GBFont.number(15, weight: .semibold))
                                        .foregroundStyle(GBColor.ink2)
                                }
                                .padding(GBSpace.md)
                            }
                        }
                        .solidCard(cornerRadius: GBRadius.md)
                    }
                }

                VStack(alignment: .leading, spacing: GBSpace.sm) {
                    Text("Recent").kicker()
                    ForEach(card.workouts.prefix(10)) { w in
                        Button {
                            guard w.isShared else { return }
                            Task { openDetail = await store.friendsService.sharedDetail(for: w.id) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.title).font(GBFont.headline(16)).foregroundStyle(GBColor.ink)
                                    Text("\(Format.day(w.startedAt)) · \(Format.duration(w.endedAt.timeIntervalSince(w.startedAt))) · \(w.setCount) sets")
                                        .font(GBFont.body(13)).foregroundStyle(GBColor.steel)
                                }
                                Spacer()
                                Image(systemName: w.isShared ? "chevron.right" : "lock")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(GBColor.fog)
                            }
                            .padding(GBSpace.md)
                            .solidCard(cornerRadius: GBRadius.md)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !card.week.isComplete {
                    Button(nudged ? "Nudged" : "Nudge \(card.profile.name.components(separatedBy: " ").first ?? "")") {
                        Task {
                            try? await store.friendsService.nudge(card.id)
                            Haptics.lock()
                            nudged = true
                        }
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(nudged)
                }

                Button("Remove friend") { confirmRemove = true }
                    .buttonStyle(QuietButtonStyle(color: GBColor.danger))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, GBSpace.margin)
            .padding(.bottom, 120)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove \(card.profile.name)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove friend", role: .destructive) {
                Task {
                    try? await store.friendsService.remove(card.id)
                    await store.refreshFriends()
                    dismiss()
                }
            }
        }
        .sheet(item: Binding(
            get: { openDetail.map { IdentifiedDetail(row: $0) } },
            set: { openDetail = $0?.row }
        )) { item in
            SharedWorkoutSheet(detail: item.row)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).kicker()
            Text(value).font(GBFont.number(17, weight: .bold)).foregroundStyle(GBColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IdentifiedDetail: Identifiable {
    var row: WorkoutDetailRow
    var id: UUID { row.workoutID }
}

struct SharedWorkoutSheet: View {
    @Environment(AppStore.self) private var store
    var detail: WorkoutDetailRow

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GBSpace.md) {
                    if !detail.note.isEmpty {
                        Text(detail.note).font(GBFont.body(15)).foregroundStyle(GBColor.ink2)
                    }
                    ForEach(detail.exercises) { log in
                        let exercise = store.exercise(log.exerciseID)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise?.displayName ?? log.exerciseID).font(GBFont.headline(16))
                            if !log.note.isEmpty {
                                Text(log.note).font(GBFont.body(14)).foregroundStyle(GBColor.steel)
                            }
                            ForEach(log.sets) { set in
                                Text(Format.set(set, unit: store.profile.unit, metric: exercise?.metric ?? .weightReps))
                                    .font(GBFont.number(15, weight: .medium))
                                    .foregroundStyle(GBColor.ink2)
                            }
                        }
                        .padding(GBSpace.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .solidCard(cornerRadius: GBRadius.md)
                    }
                }
                .padding(GBSpace.margin)
            }
            .paperBackground()
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
}
