import SwiftUI

struct SyncSettingsView: View {
    var body: some View {
        Form {
            Section("Sync / Devices") {
                Text("Cross-device sync is not active yet. Device sync, Settings sync, and manual folder sync are placeholders for a future pass.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Sync")
    }
}

#Preview {
    NavigationStack {
        SyncSettingsView()
    }
}
