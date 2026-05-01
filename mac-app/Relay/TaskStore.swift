import SwiftUI
import Combine

@MainActor
class TaskStore: ObservableObject {
    @Published var tasks:    [RelayTask]   = []
    @Published var summary:  RelaySummary? = nil
    @Published var loading   = false
    @Published var lastError: String?      = nil
    @Published var lastRefresh: Date?      = nil

    @AppStorage("relay_api_url") var apiURL = "https://agent-task-tracker.onrender.com"
    @AppStorage("relay_api_key") var apiKey = ""

    private var timer: Timer?

    init() {
        Task { await refresh() }
        startPolling()
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        guard !apiKey.isEmpty else { return }
        loading = true
        do {
            async let t = fetchTasks()
            async let s = fetchSummary()
            let (tasks, summary) = try await (t, s)
            self.tasks      = tasks.sorted { $0.priorityOrder < $1.priorityOrder }
            self.summary    = summary
            self.lastError  = nil
            self.lastRefresh = Date()
        } catch {
            self.lastError = error.localizedDescription
        }
        loading = false
    }

    // ── API helpers ───────────────────────────────────────────────────────────

    private func fetchTasks() async throws -> [RelayTask] {
        let data = try await get("/tasks")
        return try JSONDecoder().decode(TasksResponse.self, from: data).tasks
    }

    private func fetchSummary() async throws -> RelaySummary {
        let data = try await get("/tasks/summary")
        return try JSONDecoder().decode(RelaySummary.self, from: data)
    }

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: apiURL.trimmingCharacters(in: .whitespaces) + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (data, res) = try await URLSession.shared.data(for: req)
        guard (res as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // ── Derived state ─────────────────────────────────────────────────────────

    var actionNeeded: [RelayTask] { tasks.filter { $0.action_needed != nil && $0.status != "done" } }
    var inProgress:   [RelayTask] { tasks.filter { $0.status == "in_progress" } }
    var pending:      [RelayTask] { tasks.filter { $0.status == "pending" } }
    var blocked:      [RelayTask] { tasks.filter { $0.status == "blocked" } }
    var done:         [RelayTask] { tasks.filter { $0.status == "done" } }

    var menuBarColor: Color {
        if !actionNeeded.isEmpty { return .red }
        if !blocked.isEmpty      { return .orange }
        if !inProgress.isEmpty   { return .blue }
        return .secondary
    }

    var menuBarCount: Int { inProgress.count + blocked.count + actionNeeded.count }
}
