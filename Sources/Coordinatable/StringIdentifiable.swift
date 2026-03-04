import Foundation

/// Redundant protocol — `Coordinatable` already conforms to `Identifiable` and provides
/// a default `id: String` implementation. Use `Identifiable` directly instead.
@available(*, deprecated, message: "StringIdentifiable is redundant. Coordinatable conforms to Identifiable with a default id implementation.")
public protocol StringIdentifiable {
    /// The ID for the coordinator. Will not be unique across instances of the coordinator.
    var id: String { get }
}
