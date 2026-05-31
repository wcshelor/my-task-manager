import Foundation

nonisolated struct ViceCardSummary: Identifiable, Equatable, Sendable {
    let vice: Vice
    let todayCount: Int
    let lastLogAt: Date?

    var id: UUID {
        vice.id
    }
}

@MainActor
final class VicesViewModel: ObservableObject {
    @Published private(set) var vices: [Vice] = []
    @Published private(set) var logs: [ViceLog] = []
    @Published private(set) var pendingUndoLogID: UUID?
    @Published private(set) var pendingUndoViceName: String?
    @Published private(set) var errorMessage: String?

    private let viceRepository: any ViceRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false
    private var undoExpirationTask: Task<Void, Never>?

    init(
        viceRepository: any ViceRepository,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.viceRepository = viceRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    deinit {
        undoExpirationTask?.cancel()
    }

    var activeVices: [Vice] {
        vices.filter { $0.isArchived == false }
    }

    var summaries: [ViceCardSummary] {
        let logsByViceID = Dictionary(grouping: logs, by: \.viceID)
        let now = nowProvider()

        return activeVices.map { vice in
            let viceLogs = logsByViceID[vice.id] ?? []
            let todayCount = viceLogs
                .filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
                .reduce(0) { partialResult, log in
                    partialResult + log.amount
                }

            return ViceCardSummary(
                vice: vice,
                todayCount: todayCount,
                lastLogAt: viceLogs.first?.timestamp
            )
        }
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func load() {
        do {
            vices = try viceRepository.fetchVices(includeArchived: true)
            logs = try viceRepository.fetchViceLogs()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load Vices: \(error.localizedDescription)"
        }
    }

    func saveVice(
        name: String,
        unitLabel: String,
        replacingViceWithID originalID: UUID? = nil
    ) -> Bool {
        guard var vice = Vice(newName: name, unitLabel: unitLabel, createdAt: nowProvider()) else {
            errorMessage = "Enter a vice name and unit label."
            return false
        }

        if let originalID,
           let existingVice = vices.first(where: { $0.id == originalID }) {
            vice = Vice(
                id: existingVice.id,
                name: vice.name,
                unitLabel: vice.unitLabel,
                createdAt: existingVice.createdAt,
                updatedAt: nowProvider(),
                isArchived: existingVice.isArchived
            )
        }

        do {
            try viceRepository.saveVice(vice, replacingViceWithID: originalID)
            load()
            return true
        } catch {
            errorMessage = "Unable to save vice: \(error.localizedDescription)"
            return false
        }
    }

    func archiveVice(withID id: UUID) {
        do {
            try viceRepository.archiveVice(withID: id, archivedAt: nowProvider())
            load()
        } catch {
            errorMessage = "Unable to archive vice: \(error.localizedDescription)"
        }
    }

    func logViceHit(viceID: UUID) {
        guard let vice = vices.first(where: { $0.id == viceID }) else {
            return
        }

        let log = ViceLog(
            viceID: viceID,
            timestamp: nowProvider(),
            amount: 1
        )

        do {
            try viceRepository.saveViceLog(log)
            load()
            setUndoState(logID: log.id, viceName: vice.name)
        } catch {
            errorMessage = "Unable to log vice: \(error.localizedDescription)"
        }
    }

    func undoLastLog() {
        guard let logID = pendingUndoLogID else {
            return
        }

        do {
            try viceRepository.deleteViceLog(withID: logID)
            clearUndoState()
            load()
        } catch {
            errorMessage = "Unable to undo log: \(error.localizedDescription)"
        }
    }

    private func setUndoState(logID: UUID, viceName: String) {
        pendingUndoLogID = logID
        pendingUndoViceName = viceName
        undoExpirationTask?.cancel()
        undoExpirationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard Task.isCancelled == false else {
                return
            }
            await self?.clearUndoState()
        }
    }

    private func clearUndoState() {
        pendingUndoLogID = nil
        pendingUndoViceName = nil
        undoExpirationTask?.cancel()
        undoExpirationTask = nil
    }
}
