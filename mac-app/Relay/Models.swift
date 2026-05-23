import Foundation

struct RelayTask: Codable, Identifiable, Equatable {
    let id:             String
    let title:          String
    let status:         String
    let priority:       String
    let notes:          String?
    let action_needed:  String?
    let agent_name:     String?
    let agent_platform: String?
    let code_refs:      String?  // JSON: [{path, lines?, label?}]
    let links:          String?  // JSON: [{url, label}]
    let git_branch:     String?
    let git_commit:     String?
    let git_repo:       String?
    let evidence:       String?
    let created_at:     String
    let updated_at:     String
    let completed_at:   String?

    var priorityOrder: Int {
        switch priority {
        case "urgent": return 0
        case "high":   return 1
        case "medium": return 2
        default:       return 3
        }
    }

    var parsedCodeRefs: [CodeRef] {
        guard let raw = code_refs,
              let data = raw.data(using: .utf8),
              let refs = try? JSONDecoder().decode([CodeRef].self, from: data)
        else { return [] }
        return refs
    }

    var parsedLinks: [TaskLink] {
        guard let raw = links,
              let data = raw.data(using: .utf8),
              let lnks = try? JSONDecoder().decode([TaskLink].self, from: data)
        else { return [] }
        return lnks
    }
}

struct CodeRef: Codable, Equatable {
    let path:  String
    let lines: String?
    let label: String?

    var display: String { lines.map { "\(path):\($0)" } ?? path }

    var vscodeURL: URL? {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let fragment = lines.flatMap { $0.split(separator: "-").first }.map { "L\($0)" } ?? ""
        return URL(string: "vscode://file/\(encoded)\(fragment.isEmpty ? "" : "#\(fragment)")")
    }
}

struct TaskLink: Codable, Equatable {
    let url:   String
    let label: String
}

struct RelaySummary: Codable {
    let total:         Int
    let by_status:     StatusCounts
    let action_needed: [ActionItem]
}

struct StatusCounts: Codable {
    let pending:     Int
    let in_progress: Int
    let done:        Int
    let blocked:     Int
}

struct ActionItem: Codable, Identifiable {
    let id:            String
    let title:         String
    let action_needed: String
    let priority:      String
}

struct TasksResponse:   Codable { let tasks: [RelayTask] }
struct TaskResponse:    Codable { let task:  RelayTask }
struct SummaryResponse: Codable { }
