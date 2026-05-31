import Foundation

nonisolated enum FinanceFormatting {
    static func currencyString(from amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "en_IE")
        return formatter.string(from: amount as NSDecimalNumber) ?? "€0.00"
    }

    static func signedCurrencyString(from amount: Decimal) -> String {
        if amount == 0 {
            return currencyString(from: amount)
        }

        let prefix = amount > 0 ? "+" : "-"
        return prefix + currencyString(from: amount < 0 ? -amount : amount)
    }

    static func decimal(from input: String) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: normalized), decimal > 0 else {
            return nil
        }

        return decimal
    }
}
