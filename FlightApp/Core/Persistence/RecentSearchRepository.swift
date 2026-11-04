import Foundation
import SwiftData

@MainActor
protocol RecentSearchRepository {
    /// Newest first.
    func recentSearches() throws -> [SearchCriteria]
    func save(_ criteria: SearchCriteria) throws
}

/// Recent searches of a single user (`ownerID`).
@MainActor
final class SwiftDataRecentSearchRepository: RecentSearchRepository {
    static let defaultLimit = 10

    private let context: ModelContext
    private let ownerID: String
    private let limit: Int
    private let now: () -> Date

    init(
        context: ModelContext,
        ownerID: String,
        limit: Int = defaultLimit,
        now: @escaping () -> Date = { .now }
    ) {
        self.context = context
        self.ownerID = ownerID
        self.limit = limit
        self.now = now
    }

    func recentSearches() throws -> [SearchCriteria] {
        try fetchAll().compactMap { try? JSONDecoder().decode(SearchCriteria.self, from: $0.payload) }
    }

    /// Inserts the search at the top. Repeating an existing search moves it to the top
    /// instead of duplicating it. Entries beyond `limit` are dropped.
    func save(_ criteria: SearchCriteria) throws {
        let ownerID = ownerID
        let key = criteria.key
        let payload = try JSONEncoder().encode(criteria)
        let existing = try context.fetch(FetchDescriptor<RecentSearchEntity>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.key == key }
        ))

        if let entity = existing.first {
            entity.createdAt = now()
            entity.payload = payload
        } else {
            context.insert(RecentSearchEntity(ownerID: ownerID, key: key, createdAt: now(), payload: payload))
        }

        for stale in try fetchAll().dropFirst(limit) {
            context.delete(stale)
        }
        try context.save()
    }

    private func fetchAll() throws -> [RecentSearchEntity] {
        let ownerID = ownerID
        return try context.fetch(FetchDescriptor<RecentSearchEntity>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
    }
}
