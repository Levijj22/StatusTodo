import SwiftUI

struct TodoListView: View {
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
                        store.addItem(title: newItemText)
                        newItemText = ""
                        inputFocused = true
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(hex: "242424"))

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 1)

            if store.filteredItems.isEmpty {
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
                    ForEach(store.filteredItems) { item in
                        TodoItemRow(item: item)
                            .listRowBackground(
                                Rectangle()
                                    .fill(Color(hex: "1C1C1C"))
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    .onMove(perform: store.moveItems)
                    .onDelete(perform: store.deleteItems)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(hex: "1C1C1C"))
            }
        }
    }
}
