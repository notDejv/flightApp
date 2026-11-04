import Foundation
import SwiftData

@MainActor
protocol FavoritesRepository {
    /// Most recently saved first.
    func favorites() throws -> [Flight]
    func add(_ flight: Flight) throws
    func remove(flightID: String) throws
}

/// Favorites of a single user (`ownerID`).
@MainActor
final class SwiftDataFavoritesRepository: FavoritesRepository {
    private let context: ModelContext
    private let ownerID: String
    private let now: () -> Date

    init(context: ModelContext, ownerID: String, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.ownerID = ownerID
        self.now = now
    }

    func favorites() throws -> [Flight] {
        let ownerID = ownerID
        let entities = try context.fetch(FetchDescriptor<FavoriteFlightEntity>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        ))
        return entities.compactMap { try? JSONDecoder().decode(Flight.self, from: $0.payload) }
    }

    func add(_ flight: Flight) throws {
        guard try entity(for: flight.id) == nil else { return }
        let payload = try JSONEncoder().encode(flight)
        context.insert(FavoriteFlightEntity(ownerID: ownerID, flightID: flight.id, savedAt: now(), payload: payload))
        try context.save()
    }

    func remove(flightID: String) throws {
        guard let entity = try entity(for: flightID) else { return }
        context.delete(entity)
        try context.save()
    }

    private func entity(for flightID: String) throws -> FavoriteFlightEntity? {
        let ownerID = ownerID
        var descriptor = FetchDescriptor<FavoriteFlightEntity>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.flightID == flightID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
