import Foundation
import SwiftData

@MainActor
final class SwiftDataHomeLayoutRepository: HomeLayoutRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let registry: HomeWidgetRegistry

    init(
        modelContainer: ModelContainer,
        registry: HomeWidgetRegistry = .standard
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
        self.registry = registry
    }

    func loadLayout() throws -> HomeLayout {
        if let record = try fetchRecord() {
            guard let layout = record.decodedLayout(using: registry),
                  layout.widgets.isEmpty == false else {
                let defaultLayout = HomeLayout.defaultLayout.normalized(using: registry)
                record.update(from: defaultLayout)
                try modelContext.save()
                return defaultLayout
            }

            let normalizedLayout = layout.normalized(using: registry)
            if normalizedLayout != layout {
                record.update(from: normalizedLayout)
                try modelContext.save()
            }
            return normalizedLayout
        }

        let defaultLayout = HomeLayout.defaultLayout.normalized(using: registry)
        modelContext.insert(HomeLayoutRecord(layout: defaultLayout))
        try modelContext.save()
        return defaultLayout
    }

    func saveLayout(_ layout: HomeLayout) throws {
        let normalizedLayout = layout.normalized(using: registry)
        if let record = try fetchRecord() {
            record.update(from: normalizedLayout)
        } else {
            modelContext.insert(HomeLayoutRecord(layout: normalizedLayout))
        }

        try modelContext.save()
    }

    private func fetchRecord() throws -> HomeLayoutRecord? {
        try modelContext.fetch(FetchDescriptor<HomeLayoutRecord>()).first {
            $0.id == HomeLayoutRecord.singletonID
        }
    }
}
