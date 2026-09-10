import SwiftUI

/// A tick box. One click completes, another reopens.
struct StatusPill: View {
    let item: TodoItem
    @EnvironmentObject var store: TodoStore

    var body: some View {
        Button {
            store.updateStatus(item, to: item.status == .done ? .todo : .done)
        } label: {
            ZStack {
                Circle()
                    .fill(item.status.color)
                    .frame(width: 22, height: 22)
                if item.status == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(item.status == .done ? "Mark not done" : "Mark done")
    }
}
