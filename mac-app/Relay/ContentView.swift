import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @State private var showSettings   = false
    @State private var showOnboarding = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .environmentObject(store)
            } else if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .environmentObject(store)
            } else {
                header
                Divider()

                if store.apiKey.isEmpty {
                    noKeyView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            statsBar
                            Divider().padding(.horizontal, 12)
                            taskSections
                        }
                    }
                }

                Divider()
                footer
            }
        }
        .frame(width: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if !hasSeenOnboarding && store.apiKey.isEmpty {
                hasSeenOnboarding = true
                showOnboarding    = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(RelayTheme.blue)
                    Text("Relay")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                Spacer()
                HStack(spacing: 6) {
                    if store.loading {
                        ProgressView().scaleEffect(0.6).frame(width: 16, height: 16)
                    }
                    Button(action: { Task { await store.refresh() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    Button(action: { (NSApp.delegate as? AppDelegate)?.openMainWindow() }) {
                        Image(systemName: "rectangle.expand.vertical")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Open full window")

                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Brand gradient rule
            RelayTheme.brandGradient
                .frame(height: 2)
        }
    }

    // ── Stats bar ─────────────────────────────────────────────────────────────

    private var statsBar: some View {
        HStack(spacing: 0) {
            statPill(label: "active",   value: store.inProgress.count,   color: RelayTheme.active)
            statPill(label: "pending",  value: store.pending.count,      color: .secondary)
            statPill(label: "blocked",  value: store.blocked.count,      color: RelayTheme.blocked)
            statPill(label: "done",     value: store.done.count,         color: RelayTheme.done)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func statPill(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(value > 0 ? color : Color.secondary.opacity(0.4))
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // ── Task sections ─────────────────────────────────────────────────────────

    private var taskSections: some View {
        VStack(spacing: 0) {
            if !store.actionNeeded.isEmpty {
                TaskSection(title: "⚡ Action Needed", tasks: store.actionNeeded, accent: RelayTheme.pink)
            }
            if !store.inProgress.isEmpty {
                TaskSection(title: "In Progress", tasks: store.inProgress)
            }
            if !store.pending.isEmpty {
                TaskSection(title: "Pending", tasks: store.pending)
            }
            if !store.blocked.isEmpty {
                TaskSection(title: "Blocked", tasks: store.blocked)
            }
            if !store.done.isEmpty {
                TaskSection(title: "Done", tasks: store.done)
            }
            if store.tasks.isEmpty && !store.loading {
                Text("No tasks yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(24)
            }
        }
    }

    // ── No key ────────────────────────────────────────────────────────────────

    private var noKeyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Not connected")
                .font(.system(size: 13, weight: .semibold))
            Text("Get your Relay Token at:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Button("tryrelayapp.com") {
                NSWorkspace.shared.open(URL(string: "https://tryrelayapp.com/get-started")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(RelayTheme.blue)
            Button("Open Settings") { showSettings = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }

    // ── Footer ────────────────────────────────────────────────────────────────

    private var footer: some View {
        HStack {
            if let last = store.lastRefresh {
                Text("Refreshed \(last.formatted(.dateTime.hour().minute()))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let err = store.lastError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

// ── Task section ──────────────────────────────────────────────────────────────

struct TaskSection: View {
    let title:  String
    let tasks:  [RelayTask]
    var accent: Color = .primary

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(accent == .primary ? .secondary : accent)
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            ForEach(tasks) { task in
                TaskRow(task: task)
                if task.id != tasks.last?.id {
                    Divider().padding(.leading, 14)
                }
            }
        }
    }
}

// ── Task row ──────────────────────────────────────────────────────────────────

struct TaskRow: View {
    let task: RelayTask
    @EnvironmentObject var store: TaskStore
    @State private var expanded    = false
    @State private var dragOffset: CGFloat = 0
    @State private var isUpdating  = false

    private let statusRevealWidth: CGFloat = 186
    private let blockRevealWidth:  CGFloat = 80
    private let snapThreshold:     CGFloat = 44

    var body: some View {
        ZStack(alignment: .leading) {
            if dragOffset > 0 { statusStrip }
            if dragOffset < 0 { blockButton }

            mainContent
                .offset(x: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { v in
                            let t = v.translation.width
                            guard abs(t) > abs(v.translation.height) else { return }
                            dragOffset = t > 0
                                ? min(t, statusRevealWidth + 16)
                                : max(t, -(blockRevealWidth + 16))
                        }
                        .onEnded { v in
                            let t = v.translation.width
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                if      t >  snapThreshold { dragOffset =  statusRevealWidth }
                                else if t < -snapThreshold { dragOffset = -blockRevealWidth  }
                                else                       { dragOffset =  0                 }
                            }
                        }
                )
        }
        .clipped()
    }

    // ── Main content ──────────────────────────────────────────────────────────

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(expanded ? nil : 2)
                    if let agent = task.agent_name {
                        Text(agent)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if isUpdating {
                    ProgressView().scaleEffect(0.55).frame(width: 16, height: 16)
                } else {
                    VStack(alignment: .trailing, spacing: 3) {
                        PriorityBadge(priority: task.priority)
                        StatusBadge(status: task.status)
                        if !task.updateAge.isEmpty {
                            Text(task.updateAge)
                                .font(.system(size: 9))
                                .foregroundColor(task.isStale ? RelayTheme.pink.opacity(0.8) : .secondary.opacity(0.5))
                        }
                    }
                }
            }

            if expanded {
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let action = task.action_needed {
                    HStack(alignment: .top, spacing: 4) {
                        Text("⚡")
                        Text(action)
                            .font(.system(size: 11))
                            .foregroundColor(RelayTheme.pink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            if dragOffset != 0 {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { dragOffset = 0 }
            } else {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            }
        }
    }

    // ── Status strip (right swipe) ────────────────────────────────────────────

    private var statusStrip: some View {
        HStack(spacing: 0) {
            statusButton("pending",     "clock",                 .secondary,      "pending")
            statusButton("in_progress", "bolt.fill",             RelayTheme.active, "active")
            statusButton("done",        "checkmark.circle.fill", RelayTheme.done,  "done")
        }
        .frame(width: statusRevealWidth)
        .frame(maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func statusButton(_ status: String, _ icon: String, _ color: Color, _ label: String) -> some View {
        let isCurrent = task.status == status
        return Button { applyStatus(status) } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 8, weight: .bold, design: .rounded))
            }
            .foregroundColor(isCurrent ? color : color.opacity(0.4))
            .frame(width: statusRevealWidth / 3)
            .frame(maxHeight: .infinity)
            .background(isCurrent ? color.opacity(0.13) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // ── Block button (left swipe) ─────────────────────────────────────────────

    private var blockButton: some View {
        HStack {
            Spacer()
            Button { applyStatus("blocked") } label: {
                VStack(spacing: 3) {
                    Image(systemName: "hand.raised.fill").font(.system(size: 13))
                    Text("block").font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(width: blockRevealWidth)
                .frame(maxHeight: .infinity)
                .background(RelayTheme.pink)
            }
            .buttonStyle(.plain)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func applyStatus(_ status: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { dragOffset = 0 }
        isUpdating = true
        Task {
            await store.updateStatus(taskId: task.id, status: status)
            isUpdating = false
        }
    }
}

// ── Badges ────────────────────────────────────────────────────────────────────

struct PriorityBadge: View {
    let priority: String

    var color: Color {
        switch priority {
        case "urgent": return RelayTheme.urgent
        case "high":   return RelayTheme.high
        case "medium": return RelayTheme.medium
        default:       return .secondary
        }
    }

    var body: some View {
        Text(priority)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "in_progress": return RelayTheme.active
        case "done":        return RelayTheme.done
        case "blocked":     return RelayTheme.blocked
        default:            return .secondary
        }
    }

    var label: String { status.replacingOccurrences(of: "_", with: " ") }

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
