import Foundation

struct SyncFolderAccess: Sendable {
    // Planned: own the user-selected cloud folder bookmark.
    //
    // iOS should use a document picker / security-scoped URL flow.
    // macOS should use the platform-appropriate file/folder importer flow.
    // The sync engine should receive resolved folder URLs from this type, not
    // reach directly into platform APIs.

    func resolveFolderURL() throws -> URL? {
        nil
    }
}

enum SyncFolderAccessError: Error, Equatable {
    case bookmarkMissing
    case bookmarkStale
    case accessDenied
}
