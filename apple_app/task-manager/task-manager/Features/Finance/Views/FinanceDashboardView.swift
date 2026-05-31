import Charts
import SwiftUI

struct FinanceDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FinanceDashboardViewModel
    @State private var entryKind: TransactionKind?
    @State private var isShowingTransactions = false

    private let onChange: () -> Void

    init(
        financeRepository: any FinanceRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: FinanceDashboardViewModel(repository: financeRepository)
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            header

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            donutCard
            balanceRow
            Spacer(minLength: 0)
            actionButtons
        }
        .padding()
        .navigationTitle("Finance")
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(item: $entryKind) { kind in
            NavigationStack {
                FinanceTransactionEntryView(
                    kind: kind,
                    categories: kind == .expense ? viewModel.expenseCategories : viewModel.incomeCategories,
                    onSelectCategory: { amount, name, note, category in
                        if viewModel.saveTransaction(name: name, amount: amount, kind: kind, category: category, note: note) {
                            onChange()
                            entryKind = nil
                        }
                    },
                    onCreateCategory: { amount, name, note, categoryName in
                        if viewModel.createCategoryAndSaveTransaction(
                            categoryName: categoryName,
                            transactionName: name,
                            amount: amount,
                            kind: kind,
                            note: note
                        ) {
                            onChange()
                            entryKind = nil
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingTransactions) {
            NavigationStack {
                FinanceTransactionListView(
                    month: viewModel.selectedMonth,
                    transactions: viewModel.transactions,
                    onDelete: { transaction in
                        viewModel.deleteTransaction(withID: transaction.id)
                        onChange()
                    }
                )
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

    private var header: some View {
        HStack {
            Button {
                viewModel.selectPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(viewModel.monthTitle)
                .font(.headline)

            Spacer()

            Button {
                viewModel.selectNextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var donutCard: some View {
        VStack(spacing: 12) {
            if viewModel.spendingBreakdown.isEmpty {
                ContentUnavailableView(
                    "No Expenses This Month",
                    systemImage: "chart.pie",
                    description: Text("Add an expense to see category spending.")
                )
                .frame(height: 240)
            } else {
                Chart(viewModel.spendingBreakdown) { slice in
                    SectorMark(
                        angle: .value("Amount", NSDecimalNumber(decimal: slice.amount).doubleValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", slice.displayName))
                }
                .frame(height: 240)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.spendingBreakdown.prefix(5)) { slice in
                        HStack {
                            Text(slice.displayName)
                            Spacer()
                            Text(FinanceFormatting.currencyString(from: slice.amount))
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var balanceRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(FinanceFormatting.signedCurrencyString(from: viewModel.monthlyBalance))
                    .font(.title2.weight(.semibold))
            }

            Spacer()

            Button {
                isShowingTransactions = true
            } label: {
                Label("Transactions", systemImage: "list.bullet")
            }
            .buttonStyle(.bordered)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 32) {
            actionButton(symbol: "minus", color: .red) {
                entryKind = .expense
            }

            actionButton(symbol: "plus", color: .green) {
                entryKind = .income
            }
        }
        .padding(.bottom, 12)
    }

    private func actionButton(symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(color, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
