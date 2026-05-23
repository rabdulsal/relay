import SwiftUI

struct MenuBarIconView: View {
    @EnvironmentObject var store: TaskStore

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(store.menuBarColor)
            if store.menuBarCount > 0 {
                Text("\(store.menuBarCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(store.menuBarColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
