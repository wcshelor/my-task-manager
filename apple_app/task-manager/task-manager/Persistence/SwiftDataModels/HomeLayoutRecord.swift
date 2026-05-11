import Foundation
import SwiftData

@Model
final class HomeLayoutRecord {
    static let singletonID = "home-layout"

    var id: String = HomeLayoutRecord.singletonID
    var version: Int = HomeLayout.currentVersion
    var widgetsJSON: String = ""

    init(
        id: String = HomeLayoutRecord.singletonID,
        layout: HomeLayout
    ) {
        self.id = id
        self.update(from: layout)
    }

    func decodedLayout(
        using registry: HomeWidgetRegistry = .standard
    ) -> HomeLayout? {
        guard let data = widgetsJSON.data(using: .utf8),
              let storedWidgets = try? JSONDecoder().decode([StoredHomeWidget].self, from: data) else {
            return nil
        }

        let widgets = storedWidgets.compactMap { storedWidget -> HomeWidgetInstance? in
            guard let id = UUID(uuidString: storedWidget.id),
                  let kind = HomeWidgetKind(rawValue: storedWidget.kind),
                  registry.descriptor(for: kind) != nil else {
                return nil
            }

            let descriptor = registry.descriptor(for: kind)
            let size = HomeWidgetSize(rawValue: storedWidget.size)
                .flatMap { descriptor?.supportedSizes.contains($0) == true ? $0 : nil }
                ?? descriptor?.defaultSize
                ?? .large

            return HomeWidgetInstance(
                id: id,
                kind: kind,
                size: size,
                sortOrder: storedWidget.sortOrder,
                configuration: storedWidget.configuration
            )
        }

        return HomeLayout(version: version, widgets: widgets)
            .normalized(using: registry)
    }

    func update(from layout: HomeLayout) {
        let normalizedLayout = layout.normalized()
        version = normalizedLayout.version
        let storedWidgets = normalizedLayout.orderedWidgets.map(StoredHomeWidget.init)
        if let data = try? JSONEncoder().encode(storedWidgets),
           let json = String(data: data, encoding: .utf8) {
            widgetsJSON = json
        } else {
            widgetsJSON = "[]"
        }
    }
}

nonisolated private struct StoredHomeWidget: Codable {
    var id: String
    var kind: String
    var size: String
    var sortOrder: Int
    var configuration: HomeWidgetConfiguration

    init(
        id: String,
        kind: String,
        size: String,
        sortOrder: Int,
        configuration: HomeWidgetConfiguration
    ) {
        self.id = id
        self.kind = kind
        self.size = size
        self.sortOrder = sortOrder
        self.configuration = configuration
    }

    init(widget: HomeWidgetInstance) {
        self.id = widget.id.uuidString
        self.kind = widget.kind.rawValue
        self.size = widget.size.rawValue
        self.sortOrder = widget.sortOrder
        self.configuration = widget.configuration
    }
}
