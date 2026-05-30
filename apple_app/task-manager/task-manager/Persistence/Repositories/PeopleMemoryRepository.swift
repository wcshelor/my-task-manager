import Foundation

@MainActor
protocol PeopleMemoryRepository {
    func fetchPeople() throws -> [PersonMemory]
    func person(withID id: UUID) throws -> PersonMemory?
    func savePerson(_ person: PersonMemory, replacingPersonWithID originalID: UUID?) throws
    func deletePerson(withID id: UUID) throws

    func fetchTags() throws -> [PersonTag]
    func tag(withID id: UUID) throws -> PersonTag?
    func tag(withNormalizedKey normalizedKey: String) throws -> PersonTag?
    func saveTag(_ tag: PersonTag, replacingTagWithID originalID: UUID?) throws
    func deleteTag(withID id: UUID) throws
}
