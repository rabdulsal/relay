import SwiftUI

// ── Main window ───────────────────────────────────────────────────────────────

struct MainWindowView: View {
    @EnvironmentObject var store: TaskStore
    @State private var filter:        FilterTab    = .all
    @State private var showCreate     = false
    @State private var selectedId:    String?      = nil
    @State private var displayTasks:  [RelayTask]  = []

    private func filteredFrom(_ tasks: [RelayTask]) -> [RelayTask] {
        switch filter {
        case .all:          return tasks
        case .actionNeeded: return tasks.filter { $0.action_needed != nil && $0.status != "done" }
        case .active:       return tasks.filter { $0.status == "in_progress" }
        case .pending:      return tasks.filter { $0.status == "pending" }
        case .blocked:      return tasks.filter { $0.status == "blocked" }
        case .done:         return tasks.filter { $0.status == "done" }
        }
    }

    var filteredTasks: [RelayTask] { filteredFrom(store.tasks) }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 160, idealWidth: 176, maxWidth: 200)

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    toolbar
                    Divider()

                    if store.apiKey.isEmpty {
                        notConnectedView
                    } else if displayTasks.isEmpty && !showCreate && !store.loading {
                        emptyView
                    } else {
                        List {
                            if showCreate {
                                CreateTaskRow(isPresented: $showCreate)
                                    .environmentObject(store)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color(NSColor.controlBackgroundColor))
                                    .listRowSeparator(.hidden)
                            }
                            ForEach(displayTasks) { task in
                                WindowTaskRow(task: task, isSelected: selectedId == task.id) {
                                    selectedId = selectedId == task.id ? nil : task.id
                                }
                                .environmentObject(store)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color(NSColor.windowBackgroundColor))
                                .listRowSeparator(.visible, edges: .bottom)
                            }
                            .onMove { from, to in
                                withAnimation { displayTasks.move(fromOffsets: from, toOffset: to) }
                                Task { await store.reorderTasks(displayTasks.map(\.id)) }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .frame(minWidth: 440)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { displayTasks = filteredTasks }
        .onChange(of: store.tasks) { newTasks in
            let currentIds = Set(displayTasks.map(\.id))
            let newIds     = Set(filteredFrom(newTasks).map(\.id))
            if currentIds == newIds {
                // Content-only update — preserve manual order
                displayTasks = displayTasks.compactMap { t in newTasks.first { $0.id == t.id } }
            } else {
                displayTasks = filteredFrom(newTasks)
            }
        }
        .onChange(of: filter) { _ in displayTasks = filteredTasks }
    }

    // ── Sidebar ───────────────────────────────────────────────────────────────

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // spacer for titlebar
            Color.clear.frame(height: 52)

            Text("FILTER")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

            ForEach(FilterTab.allCases) { tab in
                SidebarRow(
                    tab: tab,
                    count: count(for: tab),
                    isSelected: filter == tab
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.12)) { filter = tab }
                    selectedId = nil
                    showCreate = false
                }
            }

            Spacer()

            Divider().padding(.horizontal, 10)

            // Footer stats
            VStack(alignment: .leading, spacing: 4) {
                if store.loading {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                        Text("Refreshing…")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else if let date = store.lastRefresh {
                    Text("Updated \(date, style: .relative) ago")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                if let err = store.lastError {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .padding(.top, 0)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
    }

    // ── Toolbar ───────────────────────────────────────────────────────────────

    private var toolbar: some View {
        HStack(spacing: 10) {
            // Title + count
            Text(filter.label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            if count(for: filter) > 0 {
                Text("\(count(for: filter))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { Task { await store.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(store.loading)

            Button(action: {
                showCreate = true
                filter = .all
                selectedId = nil
            }) {
                Label("New Task", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // ── Empty / not-connected ─────────────────────────────────────────────────

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No tasks")
                .font(.system(size: 13, weight: .semibold))
            Text(filter == .all ? "Agents haven't posted anything yet." : "Nothing in this category.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notConnectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Not connected")
                .font(.system(size: 13, weight: .semibold))
            Text("Add your Relay Token in Settings.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Button("Open Settings") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func count(for tab: FilterTab) -> Int {
        switch tab {
        case .all:          return store.tasks.count
        case .actionNeeded: return store.actionNeeded.count
        case .active:       return store.inProgress.count
        case .pending:      return store.pending.count
        case .blocked:      return store.blocked.count
        case .done:         return store.done.count
        }
    }
}

// ── Filter tabs ───────────────────────────────────────────────────────────────

enum FilterTab: String, CaseIterable, Identifiable {
    case all, actionNeeded, active, pending, blocked, done
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:          return "All Tasks"
        case .actionNeeded: return "Action Needed"
        case .active:       return "In Progress"
        case .pending:      return "Pending"
        case .blocked:      return "Blocked"
        case .done:         return "Done"
        }
    }

    var icon: String {
        switch self {
        case .all:          return "tray.full"
        case .actionNeeded: return "bolt.fill"
        case .active:       return "arrow.trianglehead.2.clockwise"
        case .pending:      return "clock"
        case .blocked:      return "hand.raised.fill"
        case .done:         return "checkmark.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .actionNeeded: return RelayTheme.pink
        case .active:       return RelayTheme.active
        case .blocked:      return RelayTheme.blocked
        case .done:         return RelayTheme.done
        default:            return .secondary
        }
    }
}

// ── Sidebar row ───────────────────────────────────────────────────────────────

struct SidebarRow: View {
    let tab:        FilterTab
    let count:      Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tab.icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 16)
                .foregroundColor(isSelected ? tab.accentColor : .secondary)

            Text(tab.label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? tab.accentColor : .secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((isSelected ? tab.accentColor : Color.secondary).opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? tab.accentColor.opacity(0.1) : Color.clear)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}

// ── Window task row (richer than popover row) ─────────────────────────────────

struct WindowTaskRow: View {
    let task:       RelayTask
    let isSelected: Bool
    let onTap:      () -> Void

    @EnvironmentObject var store: TaskStore
    @State private var editingTitle  = ""
    @State private var editingNotes  = ""
    @State private var isEditing     = false
    @State private var isSaving      = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Row header ────────────────────────────────────────────────────
            HStack(alignment: .top, spacing: 10) {
                statusDot
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 3) {
                    if isEditing {
                        TextField("Task title", text: $editingTitle)
                            .font(.system(size: 13, weight: .medium))
                            .textFieldStyle(.plain)
                            .onSubmit { Task { await saveEdits() } }
                    } else {
                        Text(task.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(isSelected ? nil : 2)
                    }

                    HStack(spacing: 6) {
                        if let agent = task.agent_name {
                            Text(agent)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        if let branch = task.git_branch {
                            Label(branch, systemImage: "arrow.triangle.branch")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !task.updateAge.isEmpty {
                            Text(task.updateAge)
                                .font(.system(size: 10))
                                .foregroundColor(task.isStale ? RelayTheme.pink.opacity(0.8) : .secondary.opacity(0.6))
                        }
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView().scaleEffect(0.55).frame(width: 14, height: 14)
                    }
                    PriorityBadge(priority: task.priority)
                    StatusBadge(status: task.status)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            // ── Expanded detail ───────────────────────────────────────────────
            if isSelected {
                VStack(alignment: .leading, spacing: 12) {
                    // Action needed callout
                    if let action = task.action_needed {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                                .foregroundColor(RelayTheme.pink)
                            Text(action)
                                .font(.system(size: 12))
                                .foregroundColor(RelayTheme.pink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(RelayTheme.pink.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Notes
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextEditor(text: $editingNotes)
                                .font(.system(size: 12))
                                .frame(minHeight: 60, maxHeight: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        }
                    } else if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Code refs
                    let refs = task.parsedCodeRefs
                    if !refs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CODE REFS")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            FlowLayout(spacing: 6) {
                                ForEach(refs, id: \.path) { ref in
                                    CodeRefChip(ref: ref)
                                }
                            }
                        }
                    }

                    // Links
                    let lnks = task.parsedLinks
                    if !lnks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LINKS")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            ForEach(lnks, id: \.url) { link in
                                if let url = URL(string: link.url) {
                                    Link(destination: url) {
                                        Label(link.label, systemImage: "link")
                                            .font(.system(size: 11))
                                            .foregroundColor(RelayTheme.blue)
                                    }
                                }
                            }
                        }
                    }

                    // Evidence
                    if let evidence = task.evidence {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(RelayTheme.done)
                            Text(evidence)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Priority picker
                    HStack(spacing: 8) {
                        Text("Priority")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        ForEach(["low", "medium", "high", "urgent"], id: \.self) { p in
                            Button(action: {
                                Task { await store.updateTask(taskId: task.id, fields: ["priority": p]) }
                            }) {
                                Text(p)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(task.priority == p ? priorityColor(p).opacity(0.2) : Color.secondary.opacity(0.08))
                                    .foregroundColor(task.priority == p ? priorityColor(p) : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    // Status picker
                    HStack(spacing: 8) {
                        Text("Status")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        ForEach(["pending", "in_progress", "done", "blocked"], id: \.self) { s in
                            Button(action: {
                                Task { await store.updateStatus(taskId: task.id, status: s) }
                            }) {
                                Text(s.replacingOccurrences(of: "_", with: " "))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(task.status == s ? statusColor(s).opacity(0.2) : Color.secondary.opacity(0.08))
                                    .foregroundColor(task.status == s ? statusColor(s) : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    // Due date (optional)
                    HStack(spacing: 8) {
                        Text("Due")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        if let dateStr = task.due_date, let date = Self.parseDueDate(dateStr) {
                            DatePicker("", selection: Binding(
                                get: { date },
                                set: { newDate in
                                    let fmt = DateFormatter()
                                    fmt.dateFormat = "yyyy-MM-dd"
                                    Task { await store.updateTask(taskId: task.id, fields: ["due_date": fmt.string(from: newDate)]) }
                                }
                            ), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            Button {
                                Task { await store.updateTask(taskId: task.id, fields: ["due_date": NSNull()]) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button("+ Set") {
                                let fmt = DateFormatter()
                                fmt.dateFormat = "yyyy-MM-dd"
                                Task { await store.updateTask(taskId: task.id, fields: ["due_date": fmt.string(from: Date())]) }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    // Edit / delete actions
                    HStack(spacing: 10) {
                        if isEditing {
                            Button("Save") { Task { await saveEdits() } }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .keyboardShortcut(.defaultAction)
                            Button("Cancel") { cancelEdits() }
                                .buttonStyle(.plain)
                                .controlSize(.small)
                                .foregroundColor(.secondary)
                        } else {
                            Button("Edit") { startEditing() }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(RelayTheme.blue)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .confirmationDialog("Delete this task?", isPresented: $confirmDelete) {
                            Button("Delete", role: .destructive) {
                                Task { await store.deleteTask(taskId: task.id) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isSelected ? Color.accentColor.opacity(0.04) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor(task.status))
            .frame(width: 8, height: 8)
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "in_progress": return RelayTheme.active
        case "done":        return RelayTheme.done
        case "blocked":     return RelayTheme.blocked
        default:            return .secondary
        }
    }

    private func startEditing() {
        editingTitle = task.title
        editingNotes = task.notes ?? ""
        isEditing = true
    }

    private func cancelEdits() {
        isEditing = false
    }

    private func priorityColor(_ p: String) -> Color {
        switch p {
        case "urgent": return RelayTheme.urgent
        case "high":   return RelayTheme.high
        case "medium": return RelayTheme.medium
        default:       return .secondary
        }
    }

    private static func parseDueDate(_ str: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: str)
    }

    private func saveEdits() async {
        let newTitle = editingTitle.trimmingCharacters(in: .whitespaces)
        guard !newTitle.isEmpty else { return }
        isSaving = true
        isEditing = false
        var fields: [String: Any] = [:]
        if newTitle != task.title { fields["title"] = newTitle }
        if editingNotes != (task.notes ?? "") { fields["notes"] = editingNotes }
        if !fields.isEmpty { await store.updateTask(taskId: task.id, fields: fields) }
        isSaving = false
    }
}

// ── Code ref chip ─────────────────────────────────────────────────────────────

struct CodeRefChip: View {
    let ref: CodeRef

    var body: some View {
        Button(action: openInVSCode) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 9))
                Text(ref.display)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RelayTheme.blue.opacity(0.1))
            .foregroundColor(RelayTheme.blue)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(ref.label ?? ref.path)
    }

    private func openInVSCode() {
        guard let url = ref.vscodeURL else { return }
        NSWorkspace.shared.open(url)
    }
}

// ── Create task row ───────────────────────────────────────────────────────────

struct CreateTaskRow: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: TaskStore
    @State private var title    = ""
    @State private var priority = "medium"
    @State private var notes    = ""
    @State private var saving   = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("New Task")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            TextField("Task title", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(8)
                .background(Color.secondary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .focused($titleFocused)
                .onSubmit { Task { await create() } }

            HStack(spacing: 8) {
                Text("Priority")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                ForEach(["low", "medium", "high", "urgent"], id: \.self) { p in
                    Button(p) { priority = p }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(priority == p ? priorityColor(p).opacity(0.18) : Color.secondary.opacity(0.07))
                        .foregroundColor(priority == p ? priorityColor(p) : .secondary)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Button(action: { Task { await create() } }) {
                    if saving {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                            Text("Creating…")
                        }
                    } else {
                        Text("Create Task")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear { titleFocused = true }
    }

    private func create() async {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        saving = true
        _ = await store.createTask(title: t, status: "pending", priority: priority, notes: notes.isEmpty ? nil : notes)
        saving = false
        isPresented = false
    }

    private func priorityColor(_ p: String) -> Color {
        switch p {
        case "urgent": return RelayTheme.urgent
        case "high":   return RelayTheme.high
        case "medium": return RelayTheme.medium
        default:       return .secondary
        }
    }
}

// ── Simple flow layout for code ref chips ─────────────────────────────────────

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
