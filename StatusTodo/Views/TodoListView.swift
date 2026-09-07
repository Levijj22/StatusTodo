import SwiftUI

struct TodoListView: View {
    let categoryId: String?
    @EnvironmentObject var store: TodoStore
    @State private var newItemText = ""
    @FocusState private var inputFocused: Bool
    @State private var scrollToTop = false

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
                        // The new row goes to the top; make sure the list is
                        // actually scrolled there so it isn't hidden above the fold.
                        scrollToTop = true
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.06))
            // Above the list, which is translucent and would otherwise show
            // rows sliding underneath it.
            .zIndex(1)

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
                ScrollViewReader { proxy in
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
                .clipped()
                .onChange(of: scrollToTop) { _, wants in
                    guard wants else { return }
                    // A beat, so the inserted row exists before we scroll to it.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        if let first = store.items(in: categoryId).first?.id {
                            withAnimation { proxy.scrollTo(first, anchor: .top) }
                        }
                        scrollToTop = false
                    }
                }
                }
                .background(Color.clear)
            }
        }
    }
}
