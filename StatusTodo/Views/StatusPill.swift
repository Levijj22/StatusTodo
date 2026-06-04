import SwiftUI

struct StatusPill: View {
    let item: TodoItem
    @EnvironmentObject var store: TodoStore
    @State private var showPicker = false

    var body: some View {
        Button { showPicker.toggle() } label: {
            ZStack {
                Circle()
                    .fill(item.status.color)
                    .frame(width: 22, height: 22)
                if item.status == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else if item.status == .waiting {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                } else if item.status == .inProgress {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .leading) {
            StatusPickerMenu(item: item, isPresented: $showPicker)
                .environmentObject(store)
        }
    }
}

private struct StatusPickerMenu: View {
    let item: TodoItem
    @Binding var isPresented: Bool
    @EnvironmentObject var store: TodoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(TodoStatus.allCases) { status in
                Button {
                    store.updateStatus(item, to: status)
                    isPresented = false
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(status.color)
                            .frame(width: 12, height: 12)
                        Text(status.label)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Spacer()
                        if item.status == status {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(item.status == status ? Color.white.opacity(0.08) : Color.clear)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(hex: "252525"))
        .frame(width: 170)
    }
}
