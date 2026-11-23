// Today, your night (recap), the group with reactions, history. Same screens as the web app.

import SwiftUI

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject var model: AppModel
    @Binding var tab: Int

    var body: some View {
        GroupGate { g in
            let me = g.me
            let now = Date()
            let h = Calendar.current.component(.hour, from: now)
            let greet = h >= 5 && h < 12 ? "today.greeting.morning" : h >= 12 && h < 18 ? "today.greeting.day" : "today.greeting.evening"
            let active = Dates.inNightWindow(goal: me.goal)
            let until = Dates.minutesUntilWindow(goal: me.goal)
            let tips = L10n.tips
            let tip = tips[Int(now.timeIntervalSince1970 / 86400) % tips.count]
            let night = g.last.flatMap { me.nights[NightWindow.isoDate($0)] }
            let nightNo = g.last.map { (Calendar.current.dateComponents([.day], from: g.start, to: $0).day ?? 0) + 1 } ?? 0

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t(greet, ["name": me.name])).font(.largeTitle.bold())
                    Text(Fmt.longDate(now) + (nightNo > 0 ? " · " + t("today.challenge", ["n": nightNo, "total": g.nightsTotal]) : ""))
                        .foregroundStyle(Color.text2)

                    Card {
                        if active {
                            Text(t("today.window.active")).font(.title3.weight(.semibold))
                            Text(t("today.window.active.body")).foregroundStyle(Color.text2)
                        } else {
                            Text(t("today.window.upcoming", ["time": me.goal])).font(.title3.weight(.semibold))
                            Text(t("today.window.in", ["h": until / 60, "m": until % 60])).foregroundStyle(Color.text2)
                        }
                    }

                    if let night, let last = g.last {
                        NavigationLink {
                            RecapView(group: g, date: last, tab: $tab)
                        } label: {
                            Card {
                                HStack(spacing: 12) {
                                    MoonView(bucket: night.bucket, size: 44)
                                    VStack(alignment: .leading) {
                                        Text(t("today.lastNight")).font(.footnote).foregroundStyle(Color.text2)
                                        Text(t("bucket.\(night.bucket.rawValue)")).font(.headline)
                                    }
                                    Spacer()
                                    Text(t("today.seeRecap") + " ›").foregroundStyle(Color.moon).font(.subheadline)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 12) {
                            stat(t("today.streak"), Fmt.nights(g.personalStreak(me)))
                            stat(t("today.groupStreak"), Fmt.nights(g.groupStreak()))
                        }
                    } else {
                        EmptyNightsCard()
                    }

                    Card {
                        Text(t("today.tip")).font(.footnote).foregroundStyle(Color.text2)
                        Text(tip)
                    }
                }
                .padding(16)
            }
            .refreshable { await model.load() }
            .screen()
        }
    }
}

func stat(_ label: String, _ value: String) -> some View {
    Card {
        Text(label).font(.footnote).foregroundStyle(Color.text2)
        Text(value).font(.title2.weight(.semibold))
    }
}

// MARK: - Recap

struct RecapView: View {
    let group: GroupModel
    let date: Date
    @Binding var tab: Int

    var body: some View {
        let me = group.me
        let night = me.nights[NightWindow.isoDate(date)]!
        let len = Double(Dates.windowLength(goal: me.goal))
        let used = night.min ?? 0
        let share = night.bucket == .missing ? 0 : max(0, 1 - used / len)

        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text(Fmt.longDate(date)).foregroundStyle(Color.text2)
                    Text(t("recap.title")).font(.largeTitle.bold())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle().stroke(Color.surface2, lineWidth: 14)
                    Circle().trim(from: 0, to: share)
                        .stroke(Color.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack {
                        Text("\(Int((share * 100).rounded()))%").font(.system(size: 32, weight: .semibold))
                        Text(t("recap.phoneFree")).font(.subheadline).foregroundStyle(Color.text2)
                    }
                }
                .frame(width: 160, height: 160)
                .padding(.vertical, 8)

                Text(t("recap.window", ["start": me.goal])).font(.footnote).foregroundStyle(Color.text2)
                if !night.atLeast {
                    timeline(night: night, len: len, goal: me.goal)
                }

                Card {
                    Text(message(night))
                    if night.atLeast && night.bucket != .free {
                        Text(t("recap.st.note")).font(.footnote).foregroundStyle(Color.text2)
                    }
                }

                Button(t("recap.toGroup")) { tab = 1 }.buttonStyle(PrimaryButton())
            }
            .padding(16)
        }
        .screen()
    }

    private func message(_ n: Night) -> String {
        let used = n.min ?? 0
        let time = n.crossedAt.map(Fmt.time) ?? crossedFromSessions(n)
        if n.bucket == .missing { return t("bucket.missing") }
        if used == 0 { return t("recap.free") }
        if n.bucket == .free { return t("recap.freeSmall", ["min": Fmt.minutes(used)]) }
        if n.atLeast {
            return time.map { t("recap.atLeast", ["min": Int(used), "time": $0]) } ?? t("recap.atLeastNoTime", ["min": Int(used)])
        }
        return t("recap.used", ["min": Int(used.rounded()), "time": time ?? "?"])
    }

    private func crossedFromSessions(_ n: Night) -> String? {
        var total = 0.0
        for s in n.sessions {
            if total + s.min >= 2 { return Dates.clock(goal: group.me.goal, offset: s.offset + (2 - total)) }
            total += s.min
        }
        return nil
    }

    private func timeline(night: Night, len: Double, goal: String) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.surface)
                    ForEach(Array(night.sessions.enumerated()), id: \.offset) { _, s in
                        RoundedRectangle(cornerRadius: 2).fill(Color.moon)
                            .frame(width: max(2, geo.size.width * s.min / len))
                            .offset(x: geo.size.width * s.offset / len)
                    }
                }
            }
            .frame(height: 24)
            HStack {
                Text(goal)
                Spacer()
                Text(Dates.clock(goal: goal, offset: len / 2))
                Spacer()
                Text(String(format: "%02d:%02d", Config.windowEnd.hour, Config.windowEnd.minute))
            }
            .font(.caption).foregroundStyle(Color.text2)
        }
    }
}

// MARK: - Group

struct GroupScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var trayFor: Member?

    var body: some View {
        GroupGate { g in
            if let last = g.last {
                let date = NightWindow.isoDate(last)
                let ok = g.members.filter { $0.nights[date]?.bucket == .free }.count
                let canReact = !Dates.inNightWindow(goal: g.me.goal)
                let days = (0..<7).map { Dates.addDays(last, $0 - 6) }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(t("group.lastNight") + " · " + Fmt.longDate(last)).foregroundStyle(Color.text2)
                        Text(t("group.title", ["ok": ok, "n": g.members.count])).font(.largeTitle.bold())
                        Text(t("today.groupStreak") + ": " + Fmt.nights(g.groupStreak())).foregroundStyle(Color.text2)

                        ForEach(g.members) { m in
                            memberRow(g, m, date: date, canReact: canReact)
                        }
                        Text(canReact ? t("group.react.hint") : t("group.react.closed"))
                            .font(.footnote).foregroundStyle(Color.text2)
                            .frame(maxWidth: .infinity)

                        Card {
                            Text(t("group.week")).font(.title3.weight(.semibold))
                            Grid(horizontalSpacing: 4, verticalSpacing: 8) {
                                GridRow {
                                    Text("")
                                    ForEach(days, id: \.self) { Text(Fmt.dayLabel($0)).font(.caption2).foregroundStyle(Color.text2) }
                                }
                                ForEach(g.members) { m in
                                    GridRow {
                                        Text(m.name).font(.footnote).lineLimit(1).gridColumnAlignment(.leading)
                                        ForEach(days, id: \.self) { d in
                                            MoonView(bucket: m.nights[NightWindow.isoDate(d)]?.bucket ?? .future, size: 20)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await model.load() }
                .screen()
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(g.name).font(.largeTitle.bold())
                        EmptyNightsCard()
                    }
                    .padding(16)
                }
                .refreshable { await model.load() }
                .screen()
            }
        }
    }

    private func memberRow(_ g: GroupModel, _ m: Member, date: String, canReact: Bool) -> some View {
        let n = m.nights[date]
        let bucket = n?.bucket ?? .missing
        let (counts, mine) = g.reactions(for: m, night: date)
        return HStack(spacing: 12) {
            Text(String(m.name.prefix(1)).uppercased())
                .font(.headline)
                .frame(width: 40, height: 40)
                .background(Color.surface2, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(m.name).font(.headline)
                    if m.isMe { Text("(\(t("group.you")))").font(.footnote).foregroundStyle(Color.text2) }
                }
                Text(t("bucket.\(bucket.rawValue)") + " · " + t("group.goal", ["time": m.goal]))
                    .font(.footnote).foregroundStyle(Color.text2)
                if !counts.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(counts, id: \.0) { e, c in
                            Text(c > 1 ? "\(e) \(c)" : e)
                                .font(.footnote)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(e == mine ? Color.surface2 : Color.bg, in: Capsule())
                                .overlay(Capsule().stroke(e == mine ? Color.moon : .clear, lineWidth: 1))
                        }
                    }
                }
            }
            Spacer()
            if m.isMe || !canReact {
                MoonView(bucket: bucket, size: 36)
            } else {
                MoonView(bucket: bucket, size: 36)
                    .padding(6)
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await model.react(to: m, night: date, emoji: "🌙") } }
                    .onLongPressGesture(minimumDuration: 0.45) { trayFor = m }
                    .popover(isPresented: Binding(get: { trayFor?.id == m.id }, set: { if !$0 { trayFor = nil } })) {
                        ReactionTray(mine: mine) { e in
                            trayFor = nil
                            Task { await model.react(to: m, night: date, emoji: e) }
                        }
                        .presentationCompactAdaptation(.popover)
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(t("group.react.hint"))
            }
        }
        .padding(12)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ReactionTray: View {
    let mine: String?
    let pick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(reactionEmoji, id: \.self) { e in
                    Button { pick(e) } label: {
                        Text(e).font(.system(size: 30))
                            .frame(width: 46, height: 46)
                            .background(e == mine ? Color.surface2 : .clear, in: Circle())
                    }
                }
            }
            .padding(6)
        }
        .frame(width: 260, height: 58)
    }
}

// MARK: - History

struct HistoryView: View {
    var body: some View {
        GroupGate { g in
            let me = g.me
            let days = (0..<g.nightsTotal).map { Dates.addDays(g.start, $0) }
            let done = Array(me.nights.values)
            let free = done.filter { $0.bucket == .free }.count

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("history.title")).font(.largeTitle.bold())
                    Card {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                            ForEach(days, id: \.self) { d in
                                VStack(spacing: 2) {
                                    MoonView(bucket: me.nights[NightWindow.isoDate(d)]?.bucket ?? .future, size: 34)
                                    Text("\(Calendar.current.component(.day, from: d))").font(.caption2).foregroundStyle(Color.text2)
                                }
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        stat(t("history.free"), "\(free) / \(done.count)")
                        stat(t("history.best"), Fmt.nights(g.bestStreak(me)))
                    }
                    Card {
                        Text(t("history.legend")).font(.title3.weight(.semibold))
                        ForEach(Bucket.allCases, id: \.self) { b in
                            HStack(spacing: 10) {
                                MoonView(bucket: b, size: 22)
                                Text(b == .future ? t("history.future") : t("bucket.\(b.rawValue)"))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .screen()
        }
    }
}
