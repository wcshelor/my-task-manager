import SwiftUI

struct FinanceTransactionEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FinanceTransactionEntryViewModel
    @State private var isCreatingCategory = false

    let categories: [FinanceCategory]
    let onSelectCategory: (Decimal, String, String?, FinanceCategory) -> Void
    let onCreateCategory: (Decimal, String, String?, String) -> Void

    init(
        kind: TransactionKind,
        categories: [FinanceCategory],
        onSelectCategory: @escaping (Decimal, String, String?, FinanceCategory) -> Void,
        onCreateCategory: @escaping (Decimal, String, String?, String) -> Void
    ) {
        self.categories = categories
        self.onSelectCategory = onSelectCategory
        self.onCreateCategory = onCreateCategory
        _viewModel = StateObject(wrappedValue: FinanceTransactionEntryViewModel(kind: kind))
    }

    var body: some View {
        List {
            Section("Details") {
                TextField("Amount", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                TextField("Transaction name", text: $viewModel.transactionName)
                TextField("Note", text: $viewModel.note)
            }

            Section("Choose Category") {
                ForEach(categories) { category in
                    Button(category.name) {
                        guard let amount = viewModel.parsedAmount else {
                            return
                        }
                        onSelectCategory(
                            amount,
                            viewModel.transactionName,
                            viewModel.note.isEmpty ? nil : viewModel.note,
                            category
                        )
                    }
                    .disabled(viewModel.canSubmit == false)
                }

                Button("+ Create New Category") {
                    isCreatingCategory = true
                }
                .disabled(viewModel.canSubmit == false)
            }
        }
        .navigationTitle(viewModel.kind.displayName)
        .sheet(isPresented: $isCreatingCategory) {
            NavigationStack {
                Form {
                    TextField("Category name", text: $viewModel.newCategoryName)
                }
                .navigationTitle("New Category")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isCreatingCategory = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let amount = viewModel.parsedAmount else {
                                return
                            }
                            onCreateCategory(
                                amount,
                                viewModel.transactionName,
                                viewModel.note.isEmpty ? nil : viewModel.note,
                                viewModel.newCategoryName
                            )
                            isCreatingCategory = false
                        }
                        .disabled(viewModel.canCreateCategory == false)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}
