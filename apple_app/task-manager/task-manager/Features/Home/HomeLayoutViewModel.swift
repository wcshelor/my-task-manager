import Combine
import Foundation
import SwiftUI

@MainActor
final class HomeLayoutViewModel: ObservableObject {
    enum WidgetDropPlacement {
        case before
        case after
    }

    @Published private(set) var layout: HomeLayout
    @Published private(set) var settings: AppSettings
    @Published private(set) var errorMessage: String?

    let registry: HomeWidgetRegistry
    private let homeLayoutRepository: any HomeLayoutRepository
    private let settingsRepository: (any SettingsRepository)?

    init(
        homeLayoutRepository: any HomeLayoutRepository,
        settingsRepository: (any SettingsRepository)? = nil,
        registry: HomeWidgetRegistry = .standard
    ) {
        self.homeLayoutRepository = homeLayoutRepository
        self.settingsRepository = settingsRepository
        self.registry = registry
        self.layout = HomeLayout.defaultLayout.normalized(using: registry)
        self.settings = .mvpDefault
    }

    var widgets: [HomeWidgetInstance] {
        layout.orderedWidgets
    }

    func load() {
        do {
            layout = try homeLayoutRepository.loadLayout()
                .normalized(using: registry)
            if let settingsRepository {
                settings = try settingsRepository.loadSettings()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load Home layout: \(error.localizedDescription)"
        }
    }

    func addWidget(
        from descriptor: HomeWidgetDescriptor,
        size: HomeWidgetSize? = nil,
        configuration: HomeWidgetConfiguration = .empty
    ) {
        guard registry.canAdd(
            descriptor: descriptor,
            configuration: configuration,
            to: layout
        ) else {
            errorMessage = descriptor.isAvailable
                ? "\(descriptor.displayName) is already on Home."
                : "\(descriptor.displayName) is not available yet."
            return
        }

        let resolvedSize = resolvedSize(
            size ?? descriptor.defaultSize,
            for: descriptor
        )
        var widgets = layout.orderedWidgets
        var removedWidgets = layout.removedWidgets
        let restoredWidget = removedWidgets.first {
            $0.kind == descriptor.kind && $0.configuration == configuration
        }
        removedWidgets.removeAll {
            $0.kind == descriptor.kind && $0.configuration == configuration
        }
        if var restoredWidget {
            restoredWidget.size = resolvedSize
            restoredWidget.sortOrder = widgets.count
            widgets.append(restoredWidget)
            save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: removedWidgets))
            return
        }

        widgets.append(
            HomeWidgetInstance(
                kind: descriptor.kind,
                size: resolvedSize,
                sortOrder: widgets.count,
                configuration: configuration
            )
        )
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: removedWidgets))
    }

    func removeWidget(withID id: UUID) {
        var widgets = layout.orderedWidgets
        var removedWidgets = layout.removedWidgets
        guard let removedWidget = widgets.first(where: { $0.id == id }) else {
            return
        }

        widgets.removeAll { $0.id == id }
        removedWidgets.removeAll {
            $0.kind == removedWidget.kind && $0.configuration == removedWidget.configuration
        }
        removedWidgets.append(removedWidget)
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: removedWidgets))
    }

    func moveWidgets(
        from source: IndexSet,
        to destination: Int
    ) {
        var widgets = layout.orderedWidgets
        widgets.move(fromOffsets: source, toOffset: destination)
        widgets = widgets.enumerated().map { index, widget in
            var updatedWidget = widget
            updatedWidget.sortOrder = index
            return updatedWidget
        }
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: layout.removedWidgets))
    }

    func moveWidget(
        withID movingID: UUID,
        relativeTo targetID: UUID,
        placement: WidgetDropPlacement
    ) {
        let reorderedWidgets = reorderedWidgets(
            movingID: movingID,
            relativeTo: targetID,
            placement: placement
        )
        guard reorderedWidgets.map(\.id) != layout.orderedWidgets.map(\.id) else {
            return
        }
        save(HomeLayout(version: layout.version, widgets: reorderedWidgets, removedWidgets: layout.removedWidgets))
    }

    func reorderedWidgets(
        movingID: UUID,
        relativeTo targetID: UUID,
        placement: WidgetDropPlacement
    ) -> [HomeWidgetInstance] {
        guard movingID != targetID else {
            return layout.orderedWidgets
        }

        var widgets = layout.orderedWidgets
        guard let sourceIndex = widgets.firstIndex(where: { $0.id == movingID }),
              let targetIndex = widgets.firstIndex(where: { $0.id == targetID }) else {
            return layout.orderedWidgets
        }

        let currentIndexOffset = sourceIndex < targetIndex ? 1 : 0
        let targetInsertionIndex = switch placement {
        case .before:
            targetIndex
        case .after:
            targetIndex + 1
        }
        if sourceIndex + currentIndexOffset == targetInsertionIndex {
            return layout.orderedWidgets
        }

        let widget = widgets.remove(at: sourceIndex)
        let adjustedTargetIndex = widgets.firstIndex(where: { $0.id == targetID }) ?? targetIndex
        let insertionIndex = switch placement {
        case .before:
            adjustedTargetIndex
        case .after:
            adjustedTargetIndex + 1
        }
        widgets.insert(widget, at: min(insertionIndex, widgets.count))
        return widgets.enumerated().map { index, widget in
            var updatedWidget = widget
            updatedWidget.sortOrder = index
            return updatedWidget
        }
    }

    func resizeWidget(
        withID id: UUID,
        to size: HomeWidgetSize
    ) {
        var widgets = layout.orderedWidgets
        guard let index = widgets.firstIndex(where: { $0.id == id }),
              let descriptor = registry.descriptor(for: widgets[index].kind),
              descriptor.supportedSizes.contains(size) else {
            return
        }

        widgets[index].size = size
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: layout.removedWidgets))
    }

    func canAdd(
        descriptor: HomeWidgetDescriptor,
        configuration: HomeWidgetConfiguration = .empty
    ) -> Bool {
        registry.canAdd(descriptor: descriptor, configuration: configuration, to: layout)
    }

    func resetToDefaultLayout() {
        save(HomeLayout.defaultLayout)
    }

    func alternateSize(for widget: HomeWidgetInstance) -> HomeWidgetSize? {
        guard let descriptor = registry.descriptor(for: widget.kind),
              descriptor.supportedSizes.count > 1 else {
            return nil
        }

        return descriptor.supportedSizes.first { $0 != widget.size }
    }

    func descriptor(for widget: HomeWidgetInstance) -> HomeWidgetDescriptor? {
        registry.descriptor(for: widget.kind)
    }

    func isHiddenBySettings(_ descriptor: HomeWidgetDescriptor) -> Bool {
        settings.hiddenHomeWidgetKinds.contains(descriptor.kind.rawValue)
    }

    func isVisible(_ descriptor: HomeWidgetDescriptor) -> Bool {
        widgets.contains { $0.kind == descriptor.kind && $0.configuration.isEmpty }
    }

    func supportsVisibilityToggle(_ descriptor: HomeWidgetDescriptor) -> Bool {
        registry.supportsVisibilityToggle(for: descriptor)
    }

    func visibilityState(for descriptor: HomeWidgetDescriptor) -> HomeWidgetVisibilityState {
        guard descriptor.isAvailable else {
            return .planned
        }

        guard supportsVisibilityToggle(descriptor) else {
            return isVisible(descriptor) ? .added : .available
        }

        if isVisible(descriptor) {
            return .visible
        }

        return isHiddenBySettings(descriptor) ? .hidden : .available
    }

    func setVisibility(
        _ isVisible: Bool,
        for descriptor: HomeWidgetDescriptor
    ) {
        guard supportsVisibilityToggle(descriptor) else {
            return
        }

        if isVisible {
            showWidget(for: descriptor)
        } else {
            hideWidget(for: descriptor)
        }
    }

    private func resolvedSize(
        _ size: HomeWidgetSize,
        for descriptor: HomeWidgetDescriptor
    ) -> HomeWidgetSize {
        descriptor.supportedSizes.contains(size) ? size : descriptor.defaultSize
    }

    private func save(_ newLayout: HomeLayout) {
        do {
            let normalizedLayout = newLayout.normalized(using: registry)
            try homeLayoutRepository.saveLayout(normalizedLayout)
            layout = normalizedLayout
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save Home layout: \(error.localizedDescription)"
        }
    }

    private func showWidget(for descriptor: HomeWidgetDescriptor) {
        updateHiddenState(for: descriptor, isHidden: false)
        addWidget(from: descriptor)
    }

    private func hideWidget(for descriptor: HomeWidgetDescriptor) {
        let visibleWidgetIDs = widgets
            .filter { $0.kind == descriptor.kind && $0.configuration.isEmpty }
            .map(\.id)
        visibleWidgetIDs.forEach(removeWidget(withID:))
        updateHiddenState(for: descriptor, isHidden: true)
    }

    private func updateHiddenState(
        for descriptor: HomeWidgetDescriptor,
        isHidden: Bool
    ) {
        guard let settingsRepository else {
            return
        }

        do {
            var updatedSettings = try settingsRepository.loadSettings()
            var hiddenKinds = Set(updatedSettings.hiddenHomeWidgetKinds)
            if isHidden {
                hiddenKinds.insert(descriptor.kind.rawValue)
            } else {
                hiddenKinds.remove(descriptor.kind.rawValue)
            }
            updatedSettings.hiddenHomeWidgetKinds = Array(hiddenKinds).sorted()
            try settingsRepository.saveSettings(updatedSettings)
            settings = updatedSettings
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save Home customization: \(error.localizedDescription)"
        }
    }
}

enum HomeWidgetVisibilityState {
    case visible
    case hidden
    case added
    case available
    case planned
}
