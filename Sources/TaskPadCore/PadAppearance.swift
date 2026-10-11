import Foundation

public enum PadAppearance: String, Codable, CaseIterable {
    case system, light, dark
    public var title: String { rawValue.capitalized }
}
