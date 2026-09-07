import SwiftUI

struct TodoListView: View {
    let categoryId: String?
    @EnvironmentObject var store: TodoStore
    @State private var newItemText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Add item row
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.system(size: 12))
                TextField("Add item...", text: $newItemText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .focused($inputFocused)
                    .onSubmit {
                        guard !newItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.addItem(title: newItemText, in: categoryId)
                        newItemText = ""
                        inputFocused = true
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.06))

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 1)

            if store.items(in: categoryId).isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("All clear")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.items(in: categoryId)) { item in
                        TodoItemRow(item: item)
                            .listRowBackground(
                                Rectangle()
                                    .fill(Color.clear)
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    .onMove { store.moveItems(from: $0, to: $1, in: categoryId) }
                    .onDelete { store.deleteItems(at: $0, in: categoryId) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
    }
}
