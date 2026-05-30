import SwiftUI

struct PeopleMemoryView: View {
    @StateObject private var viewModel: PeopleMemoryViewModel
    @State private var sheetDestination: SheetDestination?
    private let onChanged: () -> Void

    private enum SheetDestination: Identifiable {
        case addPerson
        case editPerson(PersonMemory)
        case study

        var id: String {
            switch self {
            case .addPerson:
                return "addPerson"
            case .editPerson(let person):
                return "editPerson-\(person.id.uuidString)"
            case .study:
                return "study"
            }
        }
    }

    init(
        peopleMemoryRepository: any PeopleMemoryRepository,
        onChanged: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(
            wrappedValue: PeopleMemoryViewModel(peopleMemoryRepository: peopleMemoryRepository)
        )
        self.onChanged = onChanged
    }

    var body: some View {
        List {
            summarySection

            Section("People") {
                if viewModel.filteredPeople.isEmpty {
                    ContentUnavailableView(
                        viewModel.searchText.isEmpty ? "No People Yet" : "No Matches",
                        systemImage: "person.2",
                        description: Text("Save a name with a few cues to make it study-ready.")
                    )
                } else {
                    ForEach(viewModel.filteredPeople) { person in
                        Button {
                            sheetDestination = .editPerson(person)
                        } label: {
                            PersonMemoryRow(
                                person: person,
                                tags: viewModel.tags(for: person),
                                isDue: person.isDue(at: Date())
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("People")
        .searchable(text: $viewModel.searchText, prompt: "Search names, cues, tags")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sheetDestination = .addPerson
                } label: {
                    Label("Add Person", systemImage: "plus")
                }
            }
        }
        .sheet(item: $sheetDestination) { destination in
            NavigationStack {
                switch destination {
                case .addPerson:
                    PersonMemoryFormView(
                        availableTags: viewModel.mostUsedTags,
                        starterTags: viewModel.starterTags,
                        onSave: { person, tagNames in
                            viewModel.savePerson(person, selectedTagNames: tagNames)
                            onChanged()
                            sheetDestination = nil
                        }
                    )
                case .editPerson(let person):
                    PersonMemoryDetailView(
                        person: person,
                        tags: viewModel.tags(for: person),
                        availableTags: viewModel.mostUsedTags,
                        starterTags: viewModel.starterTags,
                        onSave: { updatedPerson, tagNames in
                            viewModel.savePerson(
                                updatedPerson,
                                replacingPersonWithID: person.id,
                                selectedTagNames: tagNames
                            )
                            onChanged()
                            sheetDestination = nil
                        },
                        onDelete: {
                            viewModel.deletePerson(withID: person.id)
                            onChanged()
                            sheetDestination = nil
                        }
                    )
                case .study:
                    PeopleStudyView(viewModel: viewModel)
                }
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("People Memory", systemImage: "person.2.fill")
                        .font(.headline)

                    Spacer()

                    Text(viewModel.summary.detail)
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.startStudy()
                    sheetDestination = .study
                } label: {
                    Label("Study 5 Names", systemImage: "rectangle.stack.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(PeopleStudyQueue.cards(from: viewModel.people, tags: viewModel.tags, now: Date()).isEmpty)
            }
        }
    }
}

private struct PersonMemoryRow: View {
    let person: PersonMemory
    let tags: [PersonTag]
    let isDue: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(person.name)
                    .font(.headline)

                Spacer()

                if person.needsEnrichment {
                    Text("Needs cues")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if isDue {
                    Text("Due")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let cues = person.recognitionCues {
                Text(cues)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if tags.isEmpty == false {
                HStack {
                    ForEach(tags.prefix(3)) { tag in
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String? {
        let metAtText = person.metAt?.formatted(date: .abbreviated, time: .omitted)
        let placeText = [person.whereMet, metAtText].compactMap { $0 }.joined(separator: " · ")
        return PersonMemory.cleanedName(from: placeText) ?? person.context
    }
}

private struct PersonMemoryDetailView: View {
    let person: PersonMemory
    let tags: [PersonTag]
    let availableTags: [PersonTag]
    let starterTags: [PersonTag]
    let onSave: (PersonMemory, [String]) -> Void
    let onDelete: () -> Void

    var body: some View {
        PersonMemoryFormView(
            person: person,
            selectedTagNames: tags.map(\.name),
            availableTags: availableTags,
            starterTags: starterTags,
            onSave: onSave,
            onDelete: onDelete
        )
    }
}

private struct PersonMemoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var pronunciationNote: String
    @State private var whereMet: String
    @State private var metAt: Date
    @State private var hasMetAt: Bool
    @State private var context: String
    @State private var recognitionCues: String
    @State private var conversationHooks: String
    @State private var notes: String
    @State private var selectedTagNames: [String]
    @State private var newTagText = ""

    private let person: PersonMemory?
    private let availableTags: [PersonTag]
    private let starterTags: [PersonTag]
    private let onSave: (PersonMemory, [String]) -> Void
    private let onDelete: (() -> Void)?

    init(
        person: PersonMemory? = nil,
        selectedTagNames: [String] = [],
        availableTags: [PersonTag],
        starterTags: [PersonTag],
        onSave: @escaping (PersonMemory, [String]) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.person = person
        self.availableTags = availableTags
        self.starterTags = starterTags
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: person?.name ?? "")
        _pronunciationNote = State(initialValue: person?.pronunciationNote ?? "")
        _whereMet = State(initialValue: person?.whereMet ?? "")
        _metAt = State(initialValue: person?.metAt ?? Date())
        _hasMetAt = State(initialValue: person?.metAt != nil)
        _context = State(initialValue: person?.context ?? "")
        _recognitionCues = State(initialValue: person?.recognitionCues ?? "")
        _conversationHooks = State(initialValue: person?.conversationHooks ?? "")
        _notes = State(initialValue: person?.notes ?? "")
        _selectedTagNames = State(initialValue: selectedTagNames)
    }

    var body: some View {
        Form {
            Section("Person") {
                TextField("Name", text: $name)
                TextField("Pronunciation note", text: $pronunciationNote)
                TextField("Where met", text: $whereMet)
                Toggle("Set when met", isOn: $hasMetAt)
                if hasMetAt {
                    DatePicker("When met", selection: $metAt, displayedComponents: .date)
                }
                TextField("Context", text: $context, axis: .vertical)
                TextField("Recognition cues", text: $recognitionCues, axis: .vertical)
                TextField("Conversation hooks", text: $conversationHooks, axis: .vertical)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Tags") {
                tagChips(tags: availableTags + starterTags)

                HStack {
                    TextField("New tag", text: $newTagText)
                    Button("Add") {
                        addTagName(newTagText)
                        newTagText = ""
                    }
                    .disabled(PersonTag.cleanedName(from: newTagText) == nil)
                }
            }

            if let onDelete {
                Section {
                    Button("Delete Person", role: .destructive) {
                        onDelete()
                    }
                }
            }
        }
        .navigationTitle(person == nil ? "Add Person" : "Edit Person")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(PersonMemory.cleanedName(from: name) == nil)
            }
        }
    }

    private func tagChips(tags: [PersonTag]) -> some View {
        let uniqueTags = tags.reduce(into: [String: PersonTag]()) { result, tag in
            result[tag.normalizedKey] = result[tag.normalizedKey] ?? tag
        }
        let sortedTags = Array(uniqueTags.values).sortedForPersonTags()

        return FlowLayout(alignment: .leading, spacing: 8) {
            ForEach(sortedTags) { tag in
                Button {
                    toggleTagName(tag.name)
                } label: {
                    Text(tag.name)
                        .font(.caption)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(isSelected(tag.name) ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        let now = Date()
        let savedPerson = PersonMemory(
            id: person?.id ?? UUID(),
            name: name,
            pronunciationNote: pronunciationNote,
            whereMet: whereMet,
            metAt: hasMetAt ? metAt : nil,
            context: context,
            recognitionCues: recognitionCues,
            conversationHooks: conversationHooks,
            notes: notes,
            tagIDs: person?.tagIDs ?? [],
            studyStage: person?.studyStage ?? 0,
            reviewCount: person?.reviewCount ?? 0,
            lastReviewedAt: person?.lastReviewedAt,
            nextReviewAt: person?.nextReviewAt,
            lastStudyRating: person?.lastStudyRating,
            createdAt: person?.createdAt ?? now,
            updatedAt: now
        )
        onSave(savedPerson, selectedTagNames)
    }

    private func toggleTagName(_ tagName: String) {
        if isSelected(tagName) {
            let key = PersonTag.normalizedKey(for: tagName)
            selectedTagNames.removeAll { PersonTag.normalizedKey(for: $0) == key }
        } else {
            addTagName(tagName)
        }
    }

    private func addTagName(_ tagName: String) {
        guard let cleanedName = PersonTag.cleanedName(from: tagName),
              isSelected(cleanedName) == false
        else {
            return
        }

        selectedTagNames.append(cleanedName)
    }

    private func isSelected(_ tagName: String) -> Bool {
        let key = PersonTag.normalizedKey(for: tagName)
        return selectedTagNames.contains { PersonTag.normalizedKey(for: $0) == key }
    }
}

private struct PeopleStudyView: View {
    @ObservedObject var viewModel: PeopleMemoryViewModel
    @State private var revealedPersonIDs: Set<UUID> = []

    var body: some View {
        List {
            if viewModel.studyCards.isEmpty {
                ContentUnavailableView(
                    "Study Complete",
                    systemImage: "checkmark.circle",
                    description: Text("Cards reviewed in this session will not repeat immediately.")
                )
            } else {
                ForEach(viewModel.studyCards) { card in
                    studyCard(card)
                }
            }
        }
        .navigationTitle("Study Names")
    }

    private func studyCard(_ card: PeopleStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            cueText(for: card)

            if revealedPersonIDs.contains(card.id) {
                Text(card.person.name)
                    .font(.title3.weight(.semibold))

                HStack {
                    ForEach(PeopleStudyRating.allCases, id: \.self) { rating in
                        Button(rating.displayName) {
                            viewModel.applyStudyRating(rating, to: card.id)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Button("Reveal Name") {
                    revealedPersonIDs.insert(card.id)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
    }

    private func cueText(for card: PeopleStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let whereMet = card.person.whereMet {
                Label(whereMet, systemImage: "mappin.and.ellipse")
            }

            if let context = card.person.context {
                Label(context, systemImage: "text.bubble")
            }

            if let recognitionCues = card.person.recognitionCues {
                Label(recognitionCues, systemImage: "eye")
            }

            if let conversationHooks = card.person.conversationHooks {
                Label(conversationHooks, systemImage: "bubble.left.and.bubble.right")
            }

            if card.tags.isEmpty == false {
                Text(card.tags.map(\.name).joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}

private struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8

    init(
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat = 8
    ) {
        self.alignment = alignment
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = rows(in: proposal.width ?? 320, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows: [FlowRow] = []
        var current = FlowRow()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if current.items.isEmpty == false,
               current.width + spacing + size.width > width {
                rows.append(current)
                current = FlowRow()
            }

            current.append(FlowItem(subview: subview, size: size), spacing: spacing)
        }

        if current.items.isEmpty == false {
            rows.append(current)
        }

        return rows
    }

    private struct FlowItem {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct FlowRow {
        var items: [FlowItem] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(_ item: FlowItem, spacing: CGFloat) {
            width += (items.isEmpty ? 0 : spacing) + item.size.width
            height = max(height, item.size.height)
            items.append(item)
        }
    }
}
