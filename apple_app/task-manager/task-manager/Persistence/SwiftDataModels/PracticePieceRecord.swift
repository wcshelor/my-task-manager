import Foundation
import SwiftData

@Model
final class PracticePieceRecord {
    var id: UUID = UUID()
    var title: String = ""
    var composer: String?
    var catalogOrOpus: String?
    var instrument: String = PracticePiece.defaultInstrument
    var statusRawValue: String = PracticePieceStatus.learning.rawValue
    var notes: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(piece: PracticePiece) {
        update(from: piece)
    }

    var piece: PracticePiece {
        PracticePiece(
            id: id,
            title: title,
            composer: composer,
            catalogOrOpus: catalogOrOpus,
            instrument: instrument,
            status: PracticePieceStatus(rawValue: statusRawValue) ?? .learning,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from piece: PracticePiece) {
        id = piece.id
        title = piece.title
        composer = piece.composer
        catalogOrOpus = piece.catalogOrOpus
        instrument = piece.instrument
        statusRawValue = piece.status.rawValue
        notes = piece.notes
        createdAt = piece.createdAt
        updatedAt = piece.updatedAt
    }
}
