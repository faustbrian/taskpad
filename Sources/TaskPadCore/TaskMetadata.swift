import Foundation

public enum DoubleClickAction: String, Codable, CaseIterable {
    case edit, toggle
    public var title: String { self == .edit ? "Edit task" : "Toggle done / pending" }
}

public enum PriorityDisplay: String, Codable, CaseIterable {
    case numbers, marks
    public var title: String { self == .numbers ? "Numbers" : "Exclamation marks" }
    public func label(_ priority: TaskPriority) -> String {
        guard priority.rawValue > 0 else { return "" }
        return self == .numbers ? String(priority.rawValue) : String(repeating: "!", count: min(9, priority.rawValue))
    }
}

/// An estimate stores its relative size (1...7), not the selected scale's label.
public enum EffortScale: String, Codable, CaseIterable {
    case exponential, fibonacci, linear, tshirt
    public var title: String {
        switch self {
        case .exponential: return "Exponential"
        case .fibonacci: return "Fibonacci"
        case .linear: return "Linear"
        case .tshirt: return "T-Shirt"
        }
    }
    public func numericValue(_ size: Int) -> Int? {
        guard (1...7).contains(size) else { return nil }
        let values: [Int]
        switch self {
        case .exponential: values = [1, 2, 4, 8, 16, 32, 64]
        case .fibonacci, .tshirt: values = [1, 2, 3, 5, 8, 13, 21]
        case .linear: values = [1, 2, 3, 4, 5, 6, 7]
        }
        return values[size - 1]
    }
    public func label(_ size: Int) -> String? {
        guard let value = numericValue(size) else { return nil }
        return self == .tshirt ? ["XS", "S", "M", "L", "XL", "XXL", "XXXL"][size - 1] : String(value)
    }
    public static func accepts(_ size: Int?) -> Bool { size.map { (1...7).contains($0) } ?? true }
}

extension PadSettings {
    /// Existing extended estimates stay editable when new extended choices are off.
    public func effortChoices(retaining existing: Int? = nil) -> [Int] {
        var choices = Array(1...(extendedEffort ? 7 : 5))
        if let existing, EffortScale.accepts(existing), !choices.contains(existing) { choices.append(existing) }
        return choices
    }
}
