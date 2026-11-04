import Foundation

protocol AirportCatalog: Sendable {
    var airports: [Airport] { get }
    func airport(code: String) -> Airport?
    func search(_ query: String, limit: Int) -> [Airport]
}

extension AirportCatalog {
    func airport(code: String) -> Airport? {
        airports.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    /// Matches IATA code prefix first, then city / airport name / country substrings.
    func search(_ query: String, limit: Int = 6) -> [Airport] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }

        func matches(_ value: String) -> Bool {
            value.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }

        let codeMatches = airports.filter {
            $0.code.range(of: needle, options: [.caseInsensitive, .anchored]) != nil
        }
        let otherMatches = airports.filter { airport in
            !codeMatches.contains(airport)
                && (matches(airport.city) || matches(airport.name) || matches(airport.country))
        }
        return Array((codeMatches + otherMatches).prefix(limit))
    }
}

struct BundleAirportCatalog: AirportCatalog {
    let airports: [Airport]

    init(bundle: Bundle = .main, resource: String = "airports") {
        guard
            let url = bundle.url(forResource: resource, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let airports = try? JSONDecoder().decode([Airport].self, from: data)
        else {
            assertionFailure("Missing or invalid \(resource).json")
            self.airports = []
            return
        }
        self.airports = airports.sorted { $0.code < $1.code }
    }
}

struct StaticAirportCatalog: AirportCatalog {
    let airports: [Airport]
}
