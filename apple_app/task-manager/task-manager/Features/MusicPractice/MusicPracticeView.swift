import SwiftUI

struct MusicPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MusicPracticeViewModel
    @State private var presentedSheet: MusicPracticeSheet?

    private let onChange: () -> Void

    init(
        musicPracticeRepository: any MusicPracticeRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: MusicPracticeViewModel(
                musicPracticeRepository: musicPracticeRepository
            )
        )
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section {
                MusicPracticeSummaryCard(summary: viewModel.summary)
            }

            Section("Recent Sessions") {
                if viewModel.recentSessions.isEmpty {
                    ContentUnavailableView(
                        "No Practice Sessions",
                        systemImage: "music.note",
                        description: Text("Log a lightweight session after practicing.")
                    )
                } else {
                    ForEach(viewModel.recentSessions) { session in
                        PracticeSessionRow(
                            session: session,
                            pieceTitle: viewModel.pieceTitle(for: session.pieceID)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            presentedSheet = .practiceSession(session)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.deleteSession(withID: session.id)
                                onChange()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("Pieces") {
                if viewModel.pieces.isEmpty {
                    Text("No pieces yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.pieces) { piece in
                        PracticePieceRow(piece: piece)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                presentedSheet = .piece(piece)
                            }
                    }
                }
            }
        }
        .navigationTitle("Music Practice")
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .practiceSession(let session):
                    PracticeSessionFormView(
                        initialSession: session,
                        pieces: viewModel.pieces
                    ) { savedSession in
                        viewModel.saveSession(
                            savedSession,
                            replacingSessionWithID: session?.id
                        )
                        onChange()
                        presentedSheet = nil
                    }
                case .piece(let piece):
                    PracticePieceFormView(initialPiece: piece) { savedPiece in
                        viewModel.savePiece(
                            savedPiece,
                            replacingPieceWithID: piece?.id
                        )
                        onChange()
                        presentedSheet = nil
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    presentedSheet = .practiceSession(nil)
                } label: {
                    Label("Log Session", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    presentedSheet = .piece(nil)
                } label: {
                    Label("Piece", systemImage: "music.note.list")
                        .font(.headline)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(.regularMaterial)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private enum MusicPracticeSheet: Identifiable {
    case practiceSession(PracticeSession?)
    case piece(PracticePiece?)

    var id: String {
        switch self {
        case .practiceSession(let session):
            return "practiceSession-\(session?.id.uuidString ?? "new")"
        case .piece(let piece):
            return "piece-\(piece?.id.uuidString ?? "new")"
        }
    }
}

private struct MusicPracticeSummaryCard: View {
    let summary: MusicPracticeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Practice", systemImage: "music.note")
                .font(.headline)

            HStack(spacing: 12) {
                PracticeMetricView(
                    label: "7 days",
                    value: minutesText(summary.totalMinutesLast7Days)
                )
                PracticeMetricView(
                    label: "30 days",
                    value: minutesText(summary.totalMinutesLast30Days)
                )
            }

            if let topFocus = topFocusText {
                Text(topFocus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if summary.piecesNotPracticedRecently.isEmpty == false {
                Text("\(summary.piecesNotPracticedRecently.count) piece\(summary.piecesNotPracticedRecently.count == 1 ? "" : "s") not practiced in 30 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var topFocusText: String? {
        let topFocusAreas = summary.focusAreaMinutesLast30Days
            .sorted { left, right in
                if left.value != right.value {
                    return left.value > right.value
                }

                return left.key.displayName < right.key.displayName
            }
            .prefix(2)

        guard topFocusAreas.isEmpty == false else {
            return nil
        }

        return topFocusAreas
            .map { "\($0.key.displayName) \(minutesText($0.value))" }
            .joined(separator: ", ")
    }

    private func minutesText(_ minutes: Int) -> String {
        guard minutes > 0 else {
            return "0m"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0, remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }
}

private struct PracticeMetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PracticeSessionRow: View {
    let session: PracticeSession
    let pieceTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pieceTitle ?? session.focusArea.displayName)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label("\(session.durationMinutes)m", systemImage: "clock")
                Label(session.focusArea.displayName, systemImage: "target")
                if let qualityRating = session.qualityRating {
                    Label("Quality \(qualityRating)/5", systemImage: "star.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let notes = session.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PracticePieceRow: View {
    let piece: PracticePiece

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(piece.title)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(piece.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(piece.displaySubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let notes = piece.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PracticeSessionFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialSession: PracticeSession?
    let pieces: [PracticePiece]
    let onSave: (PracticeSession) -> Void

    @State private var date: Date
    @State private var durationMinutes: Int
    @State private var selectedPieceID: UUID?
    @State private var focusArea: PracticeFocusArea
    @State private var qualityRating: Int?
    @State private var notes: String

    init(
        initialSession: PracticeSession?,
        pieces: [PracticePiece],
        onSave: @escaping (PracticeSession) -> Void
    ) {
        self.initialSession = initialSession
        self.pieces = pieces
        self.onSave = onSave
        _date = State(initialValue: initialSession?.date ?? Date())
        _durationMinutes = State(initialValue: initialSession?.durationMinutes ?? 30)
        _selectedPieceID = State(initialValue: initialSession?.pieceID)
        _focusArea = State(initialValue: initialSession?.focusArea ?? .repertoire)
        _qualityRating = State(initialValue: initialSession?.qualityRating)
        _notes = State(initialValue: initialSession?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Session") {
                DatePicker("Date", selection: $date)

                Stepper(value: $durationMinutes, in: 0...600, step: 5) {
                    Text("Duration \(durationMinutes)m")
                }

                Picker("Focus", selection: $focusArea) {
                    ForEach(PracticeFocusArea.allCases, id: \.self) { focusArea in
                        Text(focusArea.displayName).tag(focusArea)
                    }
                }
            }

            Section("Piece") {
                Picker("Piece", selection: $selectedPieceID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(pieces) { piece in
                        Text(piece.title).tag(piece.id as UUID?)
                    }
                }
            }

            Section("Quality") {
                Picker("Rating", selection: $qualityRating) {
                    Text("Not Rated").tag(nil as Int?)
                    ForEach(1...5, id: \.self) { rating in
                        Text("\(rating)").tag(rating as Int?)
                    }
                }
            }

            Section("Notes") {
                TextField("What did you work on?", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(initialSession == nil ? "Log Practice" : "Edit Practice")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let now = Date()
                    onSave(
                        PracticeSession(
                            id: initialSession?.id ?? UUID(),
                            date: date,
                            durationMinutes: durationMinutes,
                            pieceID: selectedPieceID,
                            focusArea: focusArea,
                            notes: notes,
                            qualityRating: qualityRating,
                            createdAt: initialSession?.createdAt ?? now,
                            updatedAt: now
                        )
                    )
                }
                .disabled(durationMinutes <= 0)
            }
        }
    }
}

private struct PracticePieceFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialPiece: PracticePiece?
    let onSave: (PracticePiece) -> Void

    @State private var title: String
    @State private var composer: String
    @State private var catalogOrOpus: String
    @State private var instrument: String
    @State private var status: PracticePieceStatus
    @State private var notes: String

    init(
        initialPiece: PracticePiece?,
        onSave: @escaping (PracticePiece) -> Void
    ) {
        self.initialPiece = initialPiece
        self.onSave = onSave
        _title = State(initialValue: initialPiece?.title ?? "")
        _composer = State(initialValue: initialPiece?.composer ?? "")
        _catalogOrOpus = State(initialValue: initialPiece?.catalogOrOpus ?? "")
        _instrument = State(initialValue: initialPiece?.instrument ?? PracticePiece.defaultInstrument)
        _status = State(initialValue: initialPiece?.status ?? .learning)
        _notes = State(initialValue: initialPiece?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Piece") {
                TextField("Title", text: $title)
                TextField("Composer", text: $composer)
                TextField("Catalog or Opus", text: $catalogOrOpus)
                TextField("Instrument", text: $instrument)
            }

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(PracticePieceStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(initialPiece == nil ? "New Piece" : "Edit Piece")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let cleanedTitle = PracticePiece.cleanedTitle(from: title) else {
                        return
                    }

                    let now = Date()
                    onSave(
                        PracticePiece(
                            id: initialPiece?.id ?? UUID(),
                            title: cleanedTitle,
                            composer: composer,
                            catalogOrOpus: catalogOrOpus,
                            instrument: instrument,
                            status: status,
                            notes: notes,
                            createdAt: initialPiece?.createdAt ?? now,
                            updatedAt: now
                        )
                    )
                }
                .disabled(PracticePiece.cleanedTitle(from: title) == nil)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MusicPracticeView(
            musicPracticeRepository: SwiftDataMusicPracticeRepository(
                modelContainer: AppContainer.makePreview(seedTasks: []).modelContainer
            )
        )
    }
}
