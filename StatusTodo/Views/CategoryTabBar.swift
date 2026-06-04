import SwiftUI

struct CategoryTabBar: View {
    @EnvironmentObject var store: TodoStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(store.sortedCategories) { category in
                    TabButton(
                        label: category.name,
                        count: store.items.filter { $0.categoryId == category.id && $0.status != .done }.count,
                        isSelected: store.selectedCategoryId == category.id
                    ) {
                        store.selectedCategoryId = category.id
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(Color(hex: "181818"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .frame(height: 1)
        }
    }
}

private struct TabButton: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color.gray.opacity(0.7))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .gray.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(isSelected ? 0.12 : 0.06))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.white.opacity(0.12) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
