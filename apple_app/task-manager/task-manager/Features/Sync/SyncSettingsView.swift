import SwiftUI

struct SyncSettingsView: View {
    @StateObject private var viewModel: SyncViewModel

    init(syncService: any SyncServicing) {
        _viewModel = StateObject(wrappedValue: SyncViewModel(syncService: syncService))
    }

    var body: some View {
        Form {
            Section("Folder Sync") {
                SyncStatusView(status: viewModel.status)

                Button {
                    Task {
                        await viewModel.syncNow()
                    }
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(true)
            }
        }
        .navigationTitle("Sync")
    }
}

#Preview {
    NavigationStack {
        SyncSettingsView(syncService: SyncService())
    }
}
