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

    /// Matches IATA code prefix first, then words in the city / airport name / country
    /// that start with the query ("ti" finds Tirana, not every "Interna-ti-onal").
    func search(_ query: String, limit: Int = 6) -> [Airport] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }

        func matches(_ value: String) -> Bool {
            var searchRange = value.startIndex..<value.endIndex
            while let found = value.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
                if found.lowerBound == value.startIndex || !value[value.index(before: found.lowerBound)].isLetter {
                    return true
                }
                searchRange = found.upperBound..<value.endIndex
            }
            return false
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
