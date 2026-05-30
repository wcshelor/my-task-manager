import Foundation
import SwiftData

@MainActor
final class SwiftDataPeopleMemoryRepository: PeopleMemoryRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchPeople() throws -> [PersonMemory] {
        try fetchAllPersonRecords()
            .map(\.person)
            .sortedForPeopleMemory()
    }

    func person(withID id: UUID) throws -> PersonMemory? {
        try fetchPersonRecord(withID: id)?.person
    }

    func savePerson(_ person: PersonMemory, replacingPersonWithID originalID: UUID?) throws {
        let record =
            try fetchPersonRecord(withID: originalID ?? person.id)
            ?? fetchPersonRecord(withID: person.id)

        if let record {
            record.update(from: person)
        } else {
            modelContext.insert(PersonMemoryRecord(person: person))
        }

        try modelContext.save()
    }

    func deletePerson(withID id: UUID) throws {
        guard let record = try fetchPersonRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchTags() throws -> [PersonTag] {
        try fetchAllTagRecords()
            .map(\.tag)
            .sortedForPersonTags()
    }

    func tag(withID id: UUID) throws -> PersonTag? {
        try fetchTagRecord(withID: id)?.tag
    }

    func tag(withNormalizedKey normalizedKey: String) throws -> PersonTag? {
        let key = PersonTag.normalizedKey(for: normalizedKey)
        return try fetchAllTagRecords().first { $0.normalizedKey == key }?.tag
    }

    func saveTag(_ tag: PersonTag, replacingTagWithID originalID: UUID?) throws {
        let key = PersonTag.normalizedKey(for: tag.name)
        let record =
            try fetchTagRecord(withID: originalID ?? tag.id)
            ?? fetchTagRecord(withID: tag.id)
            ?? fetchTagRecord(withNormalizedKey: key)

        if let record {
            let updatedTag = PersonTag(
                id: record.id,
                name: tag.name,
                createdAt: record.createdAt,
                updatedAt: tag.updatedAt
            )
            record.update(from: updatedTag)
        } else {
            modelContext.insert(PersonTagRecord(tag: tag))
        }

        try modelContext.save()
    }

    func deleteTag(withID id: UUID) throws {
        guard let record = try fetchTagRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllPersonRecords() throws -> [PersonMemoryRecord] {
        try modelContext.fetch(FetchDescriptor<PersonMemoryRecord>())
    }

    private func fetchPersonRecord(withID id: UUID) throws -> PersonMemoryRecord? {
        try fetchAllPersonRecords().first { $0.id == id }
    }

    private func fetchAllTagRecords() throws -> [PersonTagRecord] {
        try modelContext.fetch(FetchDescriptor<PersonTagRecord>())
    }

    private func fetchTagRecord(withID id: UUID) throws -> PersonTagRecord? {
        try fetchAllTagRecords().first { $0.id == id }
    }

    private func fetchTagRecord(withNormalizedKey normalizedKey: String) throws -> PersonTagRecord? {
        try fetchAllTagRecords().first { $0.normalizedKey == normalizedKey }
    }
}

extension Array where Element == PersonMemory {
    func sortedForPeopleMemory() -> [PersonMemory] {
        sorted { leftPerson, rightPerson in
            let comparison = leftPerson.name.localizedCaseInsensitiveCompare(rightPerson.name)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            return leftPerson.createdAt < rightPerson.createdAt
        }
    }
}

extension Array where Element == PersonTag {
    func sortedForPersonTags() -> [PersonTag] {
        sorted { leftTag, rightTag in
            let comparison = leftTag.name.localizedCaseInsensitiveCompare(rightTag.name)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            return leftTag.id.uuidString < rightTag.id.uuidString
        }
    }
}
