import SwiftUI

struct TodoItemRow: View {
    let item: TodoItem
    @EnvironmentObject var store: TodoStore
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var focused: Bool

    var isDone: Bool { item.status == .done }

    var body: some View {
        HStack(spacing: 12) {
            StatusPill(item: item)

            Group {
                if isEditing {
                    TextField("", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .focused($focused)
                        .onSubmit { commitEdit() }
                        .onExitCommand { isEditing = false }
                } else {
                    Text(item.title)
                        .font(.system(size: 14))
                        .foregroundColor(isDone ? Color.gray.opacity(0.6) : .white)
                        .strikethrough(isDone, color: .gray.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture { beginEdit() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "line.3.horizontal")
                .foregroundColor(.gray.opacity(0.35))
                .font(.system(size: 12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onChange(of: focused) { _, isFocused in
            if !isFocused && isEditing { commitEdit() }
        }
    }

    private func beginEdit() {
        editText = item.title
        isEditing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
    }

    private func commitEdit() {
        store.updateTitle(item, to: editText)
        isEditing = false
    }
}
