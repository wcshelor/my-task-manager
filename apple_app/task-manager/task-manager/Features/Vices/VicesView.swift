import SwiftUI

struct VicesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VicesViewModel
    @State private var draftName = ""
    @State private var draftUnitLabel = ""
    @State private var isShowingAddSheet = false
    @State private var editingVice: Vice?

    private let onChange: () -> Void

    init(
        viceRepository: any ViceRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: VicesViewModel(viceRepository: viceRepository)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.activeVices.isEmpty {
                    ContentUnavailableView(
                        "No Vices Yet",
                        systemImage: "flame",
                        description: Text("Add a vice to start logging each occurrence with one tap.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.summaries) { summary in
                                ViceCard(
                                    summary: summary,
                                    onTap: {
                                        viewModel.logViceHit(viceID: summary.vice.id)
                                        onChange()
                                    },
                                    onEdit: {
                                        editingVice = summary.vice
                                        draftName = summary.vice.name
                                        draftUnitLabel = summary.vice.unitLabel
                                    },
                                    onArchive: {
                                        viewModel.archiveVice(withID: summary.vice.id)
                                        onChange()
                                    }
                                )
                            }
                        }
                    }
                }

                if let viceName = viewModel.pendingUndoViceName {
                    HStack(spacing: 12) {
                        Text("Logged \(viceName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Button("Undo") {
                            viewModel.undoLastLog()
                            onChange()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("Vices")
            .task {
                viewModel.loadIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingVice = nil
                        draftName = ""
                        draftUnitLabel = ""
                        isShowingAddSheet = true
                    } label: {
                        Label("Add Vice", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                NavigationStack {
                    viceForm(title: "New Vice") {
                        if viewModel.saveVice(name: draftName, unitLabel: draftUnitLabel) {
                            isShowingAddSheet = false
                            onChange()
                        }
                    }
                }
            }
            .sheet(item: $editingVice) { vice in
                NavigationStack {
                    viceForm(title: "Edit Vice") {
                        if viewModel.saveVice(
                            name: draftName,
                            unitLabel: draftUnitLabel,
                            replacingViceWithID: vice.id
                        ) {
                            editingVice = nil
                            onChange()
                        }
                    }
                }
            }
        }
    }

    private func viceForm(
        title: String,
        onSave: @escaping () -> Void
    ) -> some View {
        Form {
            Section("Vice") {
                TextField("Name", text: $draftName)
                    .textInputAutocapitalization(.words)

                TextField("Unit label", text: $draftUnitLabel)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: onSave)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isShowingAddSheet = false
                    editingVice = nil
                }
            }
        }
    }
}

private struct ViceCard: View {
    let summary: ViceCardSummary
    let onTap: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(summary.vice.name)
                        .font(.headline)
                    Spacer()
                    Menu {
                        Button("Edit", action: onEdit)
                        Button("Archive", role: .destructive, action: onArchive)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(summary.todayCount)")
                        .font(.title2.weight(.semibold))
                    Text(summary.vice.unitLabel.lowercased())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(lastLogLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var lastLogLabel: String {
        guard let lastLogAt = summary.lastLogAt else {
            return "No logs yet"
        }

        return "Last log \(lastLogAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
