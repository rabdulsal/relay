import SwiftUI

@main
struct RelayApp: App {
    @StateObject private var store = TaskStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
        } label: {
            MenuBarIconView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarIconView: View {
    @EnvironmentObject var store: TaskStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(store.apiKey.isEmpty ? .secondary : store.menuBarColor)
            if store.menuBarCount > 0 {
                Text("\(store.menuBarCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(store.menuBarColor)
            }
        }
    }
}
