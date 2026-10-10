import Foundation

public enum PadTheme: String, Codable, CaseIterable { case karst, notepad }
public enum TaskPriority: String, Codable, CaseIterable { case none, low, medium, high }
public enum TaskColor: String, Codable, CaseIterable { case red, orange, green, blue, purple }

public struct PadTask: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var text: String
    public var isComplete = false
    public var priority: TaskPriority = .none
    public var color: TaskColor?
    public init(text: String) { self.text = text }
}

public struct PadSheet: Codable, Equatable {
    public var id = UUID()
    public var day: String
    public var tasks: [PadTask] = []
    public var notes = ""
    public var closingNotes = ""
    public init(day: String) { self.day = day }
    public mutating func add(_ text: String) throws {
        guard tasks.count < 30 else { throw PadError.capacity }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PadError.emptyTask }
        tasks.append(PadTask(text: text))
    }
    public mutating func move(_ id: UUID, offset: Int) throws {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { throw PadError.missingTask }
        let destination = index + offset
        guard tasks.indices.contains(destination) else { return }
        let task = tasks.remove(at: index)
        tasks.insert(task, at: destination)
    }
}

public struct RolloverDraft: Codable, Equatable {
    public var sourceSheetID: UUID
    public var selectedTaskIDs: Set<UUID> = []
    public var carryNotes = false
    public var closingNotes = ""
}

public struct PadState: Codable, Equatable {
    public var version = 1
    public var sheet: PadSheet
    public var theme: PadTheme = .karst
    public var draft: RolloverDraft?

    public func validate() throws {
        guard version == 1, PadDay.isValid(sheet.day), sheet.tasks.count <= 30,
              Set(sheet.tasks.map(\.id)).count == sheet.tasks.count else { throw PadError.invalidData }
        if let draft {
            let eligible = Set(sheet.tasks.filter { !$0.isComplete }.map(\.id))
            guard draft.sourceSheetID == sheet.id,
                  draft.selectedTaskIDs.isSubset(of: eligible) else { throw PadError.invalidData }
        }
    }
}

public enum PadError: LocalizedError {
    case capacity, emptyTask, missingTask, invalidData, staleRollover, finishRollover
    public var errorDescription: String? {
        switch self {
        case .capacity: return "This sheet has 30 tasks. Remove one before adding another."
        case .emptyTask: return "Write something for this task first."
        case .missingTask: return "This task is no longer on the sheet."
        case .invalidData: return "The saved pad could not be read safely. Existing files have not been replaced."
        case .staleRollover: return "The date has changed. Your previous sheet is still safe; return when a new day begins."
        case .finishRollover: return "Finish the new-day decision before changing this sheet."
        }
    }
}

public enum PadDay {
    public static func local(_ date: Date = Date(), timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }
    public static func isValid(_ day: String) -> Bool {
        guard day.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else { return false }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts[0] > 0 else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components) else { return false }
        return calendar.dateComponents([.year, .month, .day], from: date) == components
    }
}

public final class PadStore {
    public private(set) var state: PadState
    public let directory: URL
    private let write: (Data, URL) throws -> Void
    private var activeFile: URL { directory.appendingPathComponent("active.json") }
    public init(directory: URL, today: String, write: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) throws {
        self.directory = directory
        self.write = write
        state = PadState(sheet: PadSheet(day: today))
        guard PadDay.isValid(today) else { throw PadError.invalidData }
        if FileManager.default.fileExists(atPath: activeFile.path) {
            do {
                state = try JSONDecoder().decode(PadState.self, from: Data(contentsOf: activeFile))
                try state.validate()
            } catch { throw PadError.invalidData }
            return
        }
        // Missing state in a nonempty data directory is not a fresh installation.
        if FileManager.default.fileExists(atPath: directory.path),
           !(try FileManager.default.contentsOfDirectory(atPath: directory.path)).isEmpty {
            throw PadError.invalidData
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try persist(state)
    }
    private func persist(_ next: PadState) throws {
        try next.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try write(encoder.encode(next), activeFile)
    }
    /// Saves a same-sheet edit. Callers may retain an unsaved candidate for retry.
    public func save(_ next: PadState) throws {
        guard next.sheet.id == state.sheet.id, next.sheet.day == state.sheet.day else { throw PadError.staleRollover }
        try persist(next)
        state = next
    }
    public func editSheet(_ edit: (inout PadSheet) throws -> Void) throws {
        guard state.draft == nil else { throw PadError.finishRollover }
        var next = state
        try edit(&next.sheet)
        try save(next)
    }
    public func setTheme(_ theme: PadTheme) throws {
        var next = state
        next.theme = theme
        try save(next)
    }
    public func beginRollover(to day: String) throws {
        guard PadDay.isValid(day) else { throw PadError.invalidData }
        guard day > state.sheet.day, state.draft == nil else { return }
        var next = state
        next.draft = RolloverDraft(sourceSheetID: state.sheet.id)
        try save(next)
    }
    public func editDraft(_ edit: (inout RolloverDraft) -> Void) throws {
        guard var draft = state.draft else { throw PadError.staleRollover }
        edit(&draft)
        var next = state
        next.draft = draft
        try save(next)
    }
    public func confirmRollover(to day: String) throws {
        guard PadDay.isValid(day), day > state.sheet.day,
              let draft = state.draft, draft.sourceSheetID == state.sheet.id else { throw PadError.staleRollover }
        try state.validate()
        var archived = state.sheet
        archived.closingNotes = draft.closingNotes
        var sheet = PadSheet(day: day)
        sheet.tasks = archived.tasks.filter { !$0.isComplete && draft.selectedTaskIDs.contains($0.id) }
        sheet.notes = draft.carryNotes ? archived.notes : ""
        var next = state
        next.sheet = sheet
        next.draft = nil
        let archives = directory.appendingPathComponent("Archives", isDirectory: true)
        try FileManager.default.createDirectory(at: archives, withIntermediateDirectories: true)
        let archiveFile = archives.appendingPathComponent("\(archived.day)-\(archived.id.uuidString).md")
        // Archive first, then atomically replace active.json. A crash leaves either
        // the old active sheet + draft, or the new sheet + complete prior archive.
        // Retrying before replacement reuses the same archive identity, never appends.
        try write(Data(Self.markdown(archived).utf8), archiveFile)
        try persist(next)
        state = next
    }

    public static func markdown(_ sheet: PadSheet) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = String(decoding: try encoder.encode(sheet), as: UTF8.self)
        let tasks = sheet.tasks.map {
            "- [\($0.isComplete ? "x" : " ")] " + $0.text.replacingOccurrences(of: "\n", with: "\n  ")
        }.joined(separator: "\n")
        return "# Taskpad · \(sheet.day)\n\n\(tasks)\n\n## Daily notes\n\n\(sheet.notes)\n\n## Closing notes\n\n\(sheet.closingNotes)\n\n## Sheet metadata\n\n```json\n\(metadata)\n```\n"
    }
}
