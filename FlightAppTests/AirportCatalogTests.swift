import Testing
@testable import FlightApp

struct AirportCatalogTests {
    let catalog = Fixtures.catalog

    @Test func emptyQueryReturnsNothing() {
        #expect(catalog.search("  ").isEmpty)
    }

    @Test func matchesCodePrefixCaseInsensitively() {
        #expect(catalog.search("ti").first == Fixtures.tirana)
    }

    @Test func matchesCityAndCountry() {
        #expect(catalog.search("rome") == [Fixtures.rome])
        #expect(Set(catalog.search("italy")) == [Fixtures.rome, Fixtures.milan])
    }

    @Test func codeMatchesRankBeforeNameMatches() {
        // "VIE" is Vienna's code; "Vienna International" also contains "vie" but must not duplicate.
        #expect(catalog.search("vie") == [Fixtures.vienna])
    }

    @Test func respectsLimit() {
        #expect(catalog.search("a", limit: 2).count == 2)
    }

    @Test func bundledCatalogLoads() {
        let bundled = BundleAirportCatalog()
        #expect(bundled.airports.count > 20)
        #expect(bundled.airport(code: "tia")?.city == "Tirana")
    }
}
