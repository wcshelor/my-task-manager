import Foundation
import SwiftData

@Model
final class PersonMemoryRecord {
    var id: UUID = UUID()
    var name: String = ""
    var pronunciationNote: String?
    var whereMet: String?
    var metAt: Date?
    var context: String?
    var recognitionCues: String?
    var conversationHooks: String?
    var notes: String?
    var tagIDsData: Data = Data()
    var studyStage: Int = 0
    var reviewCount: Int = 0
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    var lastStudyRatingRawValue: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(person: PersonMemory) {
        update(from: person)
    }

    var person: PersonMemory {
        PersonMemory(
            id: id,
            name: name,
            pronunciationNote: pronunciationNote,
            whereMet: whereMet,
            metAt: metAt,
            context: context,
            recognitionCues: recognitionCues,
            conversationHooks: conversationHooks,
            notes: notes,
            tagIDs: decodedTagIDs,
            studyStage: studyStage,
            reviewCount: reviewCount,
            lastReviewedAt: lastReviewedAt,
            nextReviewAt: nextReviewAt,
            lastStudyRating: lastStudyRatingRawValue.flatMap(PeopleStudyRating.init(rawValue:)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from person: PersonMemory) {
        id = person.id
        name = person.name
        pronunciationNote = person.pronunciationNote
        whereMet = person.whereMet
        metAt = person.metAt
        context = person.context
        recognitionCues = person.recognitionCues
        conversationHooks = person.conversationHooks
        notes = person.notes
        tagIDsData = (try? JSONEncoder().encode(person.tagIDs)) ?? Data()
        studyStage = person.studyStage
        reviewCount = person.reviewCount
        lastReviewedAt = person.lastReviewedAt
        nextReviewAt = person.nextReviewAt
        lastStudyRatingRawValue = person.lastStudyRating?.rawValue
        createdAt = person.createdAt
        updatedAt = person.updatedAt
    }

    private var decodedTagIDs: [UUID] {
        (try? JSONDecoder().decode([UUID].self, from: tagIDsData)) ?? []
    }
}
