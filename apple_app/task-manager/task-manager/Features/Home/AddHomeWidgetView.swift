import SwiftUI

struct AddHomeWidgetView: View {
    @ObservedObject var viewModel: HomeLayoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expandedModules: Set<HomeWidgetModule> = Set(HomeWidgetModule.allCases)
    @State private var configuringDescriptor: HomeWidgetDescriptor?

    let projects: [Project]
    let routines: [Routine]
    let onDone: () -> Void

    var body: some View {
        List {
            ForEach(viewModel.registry.modules, id: \.self) { module in
                Section {
                    moduleHeader(for: module)

                    if expandedModules.contains(module) {
                        if let moduleWidget = viewModel.registry.moduleWidget(for: module) {
                            descriptorRow(moduleWidget)
                        }

                        ForEach(viewModel.registry.featureWidgets(for: module)) { descriptor in
                            descriptorRow(descriptor)
                        }
                    }
                } header: {
                    Text(module.displayName)
                }
            }
        }
        .navigationTitle("Add Widget")
        .sheet(item: $configuringDescriptor) { descriptor in
            NavigationStack {
                HomeWidgetConfigurationView(
                    descriptor: descriptor,
                    projects: projects,
                    routines: routines
                ) { configuration, size in
                    viewModel.addWidget(
                        from: descriptor,
                        size: size,
                        configuration: configuration
                    )
                    configuringDescriptor = nil
                    onDone()
                    dismiss()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    onDone()
                    dismiss()
                }
            }
        }
    }

    private func moduleHeader(for module: HomeWidgetModule) -> some View {
        Button {
            toggle(module)
        } label: {
            HomeWidgetCardSurface {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.displayName)
                            .font(.headline)
                        Text(moduleSubtitle(for: module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: expandedModules.contains(module) ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func descriptorRow(_ descriptor: HomeWidgetDescriptor) -> some View {
        HStack(spacing: 12) {
            Image(systemName: descriptor.iconSystemName)
                .foregroundStyle(descriptor.isAvailable ? Color.blue : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.displayName)
                    .foregroundStyle(descriptor.isAvailable ? Color.primary : Color.secondary)

                Text(rowSubtitle(for: descriptor))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if descriptor.isAvailable == false {
                Text("Planned")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if viewModel.supportsVisibilityToggle(descriptor) && viewModel.isHiddenBySettings(descriptor) {
                Text("Hidden")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if descriptor.requiresConfiguration {
                Button("Configure") {
                    configuringDescriptor = descriptor
                }
                .buttonStyle(.borderedProminent)
            } else {
                addMenu(for: descriptor)
            }
        }
    }

    private func addMenu(for descriptor: HomeWidgetDescriptor) -> some View {
        Menu {
            ForEach(descriptor.supportedSizes, id: \.self) { size in
                Button(size == .large ? "Add Large" : "Add Small") {
                    viewModel.addWidget(from: descriptor, size: size)
                    onDone()
                    dismiss()
                }
                .disabled(viewModel.canAdd(descriptor: descriptor) == false)
            }
        } label: {
            Label(viewModel.canAdd(descriptor: descriptor) ? "Add" : "Added", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.canAdd(descriptor: descriptor) == false)
    }

    private func toggle(_ module: HomeWidgetModule) {
        if expandedModules.contains(module) {
            expandedModules.remove(module)
        } else {
            expandedModules.insert(module)
        }
    }

    private func moduleSubtitle(for module: HomeWidgetModule) -> String {
        let descriptors = viewModel.registry.featureWidgets(for: module)
            + viewModel.registry.descriptors.filter { $0.module == module && $0.isModuleWidget }
        let availableCount = descriptors.filter(\.isAvailable).count
        let plannedCount = descriptors.count - availableCount

        if plannedCount == 0 {
            return "\(availableCount) available widget\(availableCount == 1 ? "" : "s")"
        }

        return "\(availableCount) available, \(plannedCount) planned"
    }

    private func rowSubtitle(for descriptor: HomeWidgetDescriptor) -> String {
        if let message = descriptor.availability.message {
            return message
        }

        var parts = [
            descriptor.supportedSizes
                .map { $0 == .large ? "large" : "small" }
                .joined(separator: " / "),
        ]

        if descriptor.requiresConfiguration {
            parts.append("configuration required")
        } else if viewModel.isHiddenBySettings(descriptor) {
            parts.append("hidden in Home customization")
        } else if viewModel.canAdd(descriptor: descriptor) == false {
            parts.append("already on Home")
        }

        return parts.joined(separator: " · ")
    }
}

private struct HomeWidgetConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let descriptor: HomeWidgetDescriptor
    let projects: [Project]
    let routines: [Routine]
    let onSave: (HomeWidgetConfiguration, HomeWidgetSize) -> Void

    @State private var configuration = HomeWidgetConfiguration.empty
    @State private var size: HomeWidgetSize

    init(
        descriptor: HomeWidgetDescriptor,
        projects: [Project],
        routines: [Routine],
        onSave: @escaping (HomeWidgetConfiguration, HomeWidgetSize) -> Void
    ) {
        self.descriptor = descriptor
        self.projects = projects
        self.routines = routines
        self.onSave = onSave
        _size = State(initialValue: descriptor.defaultSize)
    }

    var body: some View {
        Form {
            Section("Widget") {
                Picker("Size", selection: $size) {
                    ForEach(descriptor.supportedSizes, id: \.self) { size in
                        Text(size == .large ? "Large" : "Small").tag(size)
                    }
                }
            }

            ForEach(descriptor.configurationFields, id: \.key) { field in
                Section(field.displayName) {
                    switch field.kind {
                    case .project:
                        Picker("Project", selection: projectBinding(for: field.key)) {
                            Text("Choose Project").tag(nil as UUID?)
                            ForEach(projects) { project in
                                Text(project.name).tag(project.id as UUID?)
                            }
                        }
                    case .routine:
                        Picker("Routine", selection: routineBinding(for: field.key)) {
                            Text("Choose Routine").tag(nil as UUID?)
                            ForEach(routines) { routine in
                                Text(routine.name).tag(routine.id as UUID?)
                            }
                        }
                    case .tag:
                        Text("Tag widgets are planned.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(descriptor.displayName)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onSave(configuration, size)
                }
                .disabled(isComplete == false)
            }
        }
    }

    private var isComplete: Bool {
        descriptor.configurationFields.allSatisfy { field in
            configuration.values[field.key]?.isEmpty == false
        }
    }

    private func projectBinding(for key: String) -> Binding<UUID?> {
        Binding(
            get: {
                configuration.values[key].flatMap(UUID.init(uuidString:))
            },
            set: { value in
                configuration.values[key] = value?.uuidString
            }
        )
    }

    private func routineBinding(for key: String) -> Binding<UUID?> {
        Binding(
            get: {
                configuration.values[key].flatMap(UUID.init(uuidString:))
            },
            set: { value in
                configuration.values[key] = value?.uuidString
            }
        )
    }
}
