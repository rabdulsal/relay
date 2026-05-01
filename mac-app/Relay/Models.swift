import Foundation

struct RelayTask: Codable, Identifiable, Equatable {
    let id:            String
    let title:         String
    let status:        String
    let priority:      String
    let notes:         String?
    let action_needed: String?
    let agent_name:    String?
    let created_at:    String
    let updated_at:    String
    let completed_at:  String?

    var priorityOrder: Int {
        switch priority {
        case "urgent": return 0
        case "high":   return 1
        case "medium": return 2
        default:       return 3
        }
    }
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

struct TasksResponse: Codable  { let tasks: [RelayTask] }
struct SummaryResponse: Codable { }
