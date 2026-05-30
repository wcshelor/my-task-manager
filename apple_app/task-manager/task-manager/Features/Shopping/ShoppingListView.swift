import SwiftUI

struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ShoppingListViewModel
    @State private var listMode: ShoppingListMode = .active
    @State private var searchText = ""
    @State private var quickAddTitle = ""
    @State private var editingItem: ShoppingItem?

    private let onChange: () -> Void

    init(
        shoppingRepository: any ShoppingRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: ShoppingListViewModel(shoppingRepository: shoppingRepository)
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Shopping View", selection: $listMode) {
                ForEach(ShoppingListMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if listMode == .active {
                quickAdd
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            content
        }
        .navigationTitle("Shopping")
        .searchable(text: $searchText, prompt: "Search shopping")
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ShoppingItemFormView(initialItem: item) { updatedItem in
                    viewModel.saveItem(updatedItem, replacingItemWithID: item.id)
                    onChange()
                    editingItem = nil
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch listMode {
        case .active:
            activeList
        case .history:
            historyList
        }
    }

    private var quickAdd: some View {
        HStack(spacing: 8) {
            TextField("Add item", text: $quickAddTitle)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit(addQuickItem)

            Button {
                addQuickItem()
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .disabled(ShoppingItem.cleanedTitle(from: quickAddTitle) == nil)
        }
        .padding(.horizontal)
    }

    private var activeList: some View {
        let groups = viewModel.activeTripGroups(searchText: searchText)

        return Group {
            if viewModel.activeItems.isEmpty {
                ContentUnavailableView(
                    "No Shopping Items",
                    systemImage: "cart",
                    description: Text("Add an item when you notice something to buy.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                ContentUnavailableView(
                    "No Matching Items",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { item in
                                ShoppingItemRow(item: item)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingItem = item
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            viewModel.markBought(withID: item.id)
                                            onChange()
                                        } label: {
                                            Label("Bought", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            viewModel.skipItem(withID: item.id)
                                            onChange()
                                        } label: {
                                            Label("Skip", systemImage: "forward.end.fill")
                                        }
                                        .tint(.orange)

                                        Button(role: .destructive) {
                                            viewModel.archiveItem(withID: item.id)
                                            onChange()
                                        } label: {
                                            Label("Archive", systemImage: "archivebox.fill")
                                        }
                                    }
                            }
                        } header: {
                            Text("\(group.title) (\(group.items.count))")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var historyList: some View {
        let items = viewModel.history(searchText: searchText)

        return Group {
            if viewModel.historyItems.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Bought and skipped items will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView(
                    "No Matching History",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        ShoppingItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingItem = item
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    viewModel.reopenItem(withID: item.id)
                                    listMode = .active
                                    onChange()
                                } label: {
                                    Label("Reopen", systemImage: "arrow.uturn.backward.circle.fill")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteItem(withID: item.id)
                                    onChange()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func addQuickItem() {
        guard ShoppingItem.cleanedTitle(from: quickAddTitle) != nil else {
            return
        }

        viewModel.quickAdd(title: quickAddTitle)
        quickAddTitle = ""
        onChange()
    }
}

private enum ShoppingListMode: String, CaseIterable, Identifiable {
    case active
    case history

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .history:
            return "History"
        }
    }
}

private struct ShoppingItemRow: View {
    let item: ShoppingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.title)
                    .font(.body.weight(.semibold))

                Spacer()

                Text(item.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 8) {
                Label(item.urgency.displayName, systemImage: "clock")
                Label(item.necessity.displayName, systemImage: "tag")
                if let storeName = item.storeName {
                    Label(storeName, systemImage: "mappin.and.ellipse")
                } else if let storeType = item.storeType {
                    Label(storeType, systemImage: "storefront")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let notes = item.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch item.status {
        case .needed:
            return .blue
        case .bought:
            return .green
        case .skipped:
            return .orange
        case .archived:
            return .secondary
        }
    }
}

struct ShoppingItemFormData: Equatable {
    var title: String
    var notes: String
    var category: String
    var storeType: String
    var storeName: String
    var urgency: ShoppingUrgency
    var necessity: ShoppingNecessity

    init(
        title: String = "",
        notes: String = "",
        category: String = "",
        storeType: String = "",
        storeName: String = "",
        urgency: ShoppingUrgency = .nextTrip,
        necessity: ShoppingNecessity = .necessary
    ) {
        self.title = title
        self.notes = notes
        self.category = category
        self.storeType = storeType
        self.storeName = storeName
        self.urgency = urgency
        self.necessity = necessity
    }

    init(item: ShoppingItem) {
        self.init(
            title: item.title,
            notes: item.notes ?? "",
            category: item.category ?? "",
            storeType: item.storeType ?? "",
            storeName: item.storeName ?? "",
            urgency: item.urgency,
            necessity: item.necessity
        )
    }

    func makeItem(
        id: UUID = UUID(),
        status: ShoppingItemStatus = .needed,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        completedAt: Date? = nil
    ) -> ShoppingItem? {
        guard ShoppingItem.cleanedTitle(from: title) != nil else {
            return nil
        }

        return ShoppingItem(
            id: id,
            title: title,
            notes: notes,
            category: category,
            storeType: storeType,
            storeName: storeName,
            urgency: urgency,
            necessity: necessity,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }
}

enum ShoppingItemFieldSuggestions {
    static let categories = [
        "Groceries",
        "Household",
        "Pharmacy",
        "Personal Care",
        "Hardware",
        "Clothing",
    ]

    static let storeTypes = [
        "Grocery",
        "Drugstore",
        "Hardware",
        "Online",
        "Department Store",
        "Market",
    ]

    static let storeNames = [
        "Aldi",
        "dm",
        "Rewe",
        "Edeka",
        "Amazon",
    ]
}

private struct ShoppingItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialItem: ShoppingItem
    let onSave: (ShoppingItem) -> Void

    @State private var formData: ShoppingItemFormData

    init(
        initialItem: ShoppingItem,
        onSave: @escaping (ShoppingItem) -> Void
    ) {
        self.initialItem = initialItem
        self.onSave = onSave
        _formData = State(initialValue: ShoppingItemFormData(item: initialItem))
    }

    var body: some View {
        Form {
            Section("Item") {
                TextField("Title", text: $formData.title)
                TextField("Notes", text: $formData.notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Trip") {
                suggestionField(
                    title: "Category",
                    text: $formData.category,
                    suggestions: ShoppingItemFieldSuggestions.categories
                )
                suggestionField(
                    title: "Store Type",
                    text: $formData.storeType,
                    suggestions: ShoppingItemFieldSuggestions.storeTypes
                )
                suggestionField(
                    title: "Store",
                    text: $formData.storeName,
                    suggestions: ShoppingItemFieldSuggestions.storeNames
                )
            }

            Section("Priority") {
                Picker("Urgency", selection: $formData.urgency) {
                    ForEach(ShoppingUrgency.allCases, id: \.self) { urgency in
                        Text(urgency.displayName).tag(urgency)
                    }
                }

                Picker("Necessity", selection: $formData.necessity) {
                    ForEach(ShoppingNecessity.allCases, id: \.self) { necessity in
                        Text(necessity.displayName).tag(necessity)
                    }
                }
            }
        }
        .navigationTitle("Shopping Item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(ShoppingItem.cleanedTitle(from: formData.title) == nil)
            }
        }
    }

    private func suggestionField(
        title: String,
        text: Binding<String>,
        suggestions: [String]
    ) -> some View {
        HStack {
            TextField(title, text: text)

            Menu {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        text.wrappedValue = suggestion
                    }
                }
            } label: {
                Image(systemName: "text.badge.plus")
            }
            .accessibilityLabel("\(title) Suggestions")
        }
    }

    private func save() {
        let now = Date()
        guard let item = formData.makeItem(
            id: initialItem.id,
            status: initialItem.status,
            createdAt: initialItem.createdAt,
            updatedAt: now,
            completedAt: initialItem.completedAt
        ) else {
            return
        }

        onSave(item)
    }
}
