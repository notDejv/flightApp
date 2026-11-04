import Foundation

struct Airport: Codable, Hashable, Identifiable, Sendable {
    let code: String
    let city: String
    let name: String
    let country: String

    var id: String { code }

    /// Short label used in form fields, e.g. "TIA – Tirana".
    var displayName: String { "\(code) – \(city)" }
}
