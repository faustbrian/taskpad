import Foundation

public enum PadTheme: String, Codable, CaseIterable { case karst, anoto, things, todoist, ticktick }
public enum CarryMode: String, Codable, CaseIterable { case automatic = "auto", ask, never }
public enum TaskColor: String, Codable, CaseIterable { case red, orange, green, blue, purple }

public struct TaskPriority: Codable, Equatable, Hashable, RawRepresentable, CaseIterable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let none = Self(rawValue: 0), low = Self(rawValue: 1), medium = Self(rawValue: 5), high = Self(rawValue: 9)
    public static var allCases: [Self] { (0...9).map(Self.init) }
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        let number = try value.decode(Int.self)
        guard (0...9).contains(number) else { throw PadError.invalidData }
        rawValue = number
    }
    public func encode(to encoder: Encoder) throws { var value = encoder.singleValueContainer(); try value.encode(rawValue) }
}

public struct ChromeSettings: Codable, Equatable {
    public var visible = true
    public var showBrand = false
    public var brand = "TaskPad"
    public var showTitle = true
    public var title = "What matters today?"
    public var showDate = true
    public var showCount = false
    public var countFormat = "{used} / {limit}"
    public init() {}
}

public struct RepeatTask: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var text: String
    /// Gregorian weekday: Sunday = 1, Monday = 2, ... Saturday = 7.
    public var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    public var hour = 7
    public var minute = 30
    public var priority: TaskPriority = .none
    public var color: TaskColor?
    public var effort: Int?
    public init(text: String) { self.text = text }
    public var time: String { String(format: "%02d:%02d", hour, minute) }
    public func isDue(on day: String) -> Bool { PadDay.weekday(day).map { weekdays.contains($0) } ?? false }
    public func validate() throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              TaskInput.accepts(text), !weekdays.isEmpty, weekdays.isSubset(of: Set(1...7)),
              (0...23).contains(hour), (0...59).contains(minute), (0...9).contains(priority.rawValue),
              EffortScale.accepts(effort) else { throw PadError.invalidSchedule }
    }
    public func occurrence() -> PadTask {
        var task = PadTask(text: text)
        task.scheduleID = id; task.scheduledTime = time; task.priority = priority; task.color = color
        task.effort = effort
        return task
    }
}

public struct PadSettings: Codable, Equatable {
    public var slotLimit = 30
    public var carryMode: CarryMode = .ask
    public var notesEnabled = false
    public var fontName = "System"
    public var fontSize: Double = 16
    public var dateFormat = ""
    public var windowTitle = "TaskPad"
    public var doubleClickAction: DoubleClickAction = .edit
    public var priorityDisplay: PriorityDisplay = .numbers
    public var effortScale: EffortScale = .fibonacci
    public var extendedEffort = false
    public var header = ChromeSettings()
    public var footer: ChromeSettings = {
        var value = ChromeSettings(); value.visible = false; value.showTitle = true
        value.title = "One sheet. Just today."; value.showDate = false; value.showCount = true
        return value
    }()
    public var schedules: [RepeatTask] = []
    public init() {}
    private enum CodingKeys: String, CodingKey { case slotLimit, carryMode, notesEnabled, fontName, fontSize, dateFormat, windowTitle, doubleClickAction, priorityDisplay, effortScale, extendedEffort, header, footer, schedules }
    public init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy: CodingKeys.self)
        slotLimit = try c.decodeIfPresent(Int.self, forKey: .slotLimit) ?? slotLimit
        carryMode = try c.decodeIfPresent(CarryMode.self, forKey: .carryMode) ?? carryMode
        notesEnabled = try c.decodeIfPresent(Bool.self, forKey: .notesEnabled) ?? notesEnabled
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? fontName
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? fontSize
        dateFormat = try c.decodeIfPresent(String.self, forKey: .dateFormat) ?? dateFormat
        windowTitle = try c.decodeIfPresent(String.self, forKey: .windowTitle) ?? windowTitle
        doubleClickAction = try c.decodeIfPresent(DoubleClickAction.self, forKey: .doubleClickAction) ?? doubleClickAction
        priorityDisplay = try c.decodeIfPresent(PriorityDisplay.self, forKey: .priorityDisplay) ?? priorityDisplay
        effortScale = try c.decodeIfPresent(EffortScale.self, forKey: .effortScale) ?? effortScale
        extendedEffort = try c.decodeIfPresent(Bool.self, forKey: .extendedEffort) ?? extendedEffort
        header = try c.decodeIfPresent(ChromeSettings.self, forKey: .header) ?? header
        footer = try c.decodeIfPresent(ChromeSettings.self, forKey: .footer) ?? footer
        schedules = try c.decodeIfPresent([RepeatTask].self, forKey: .schedules) ?? schedules
    }
    public func validate() throws {
        guard (1...100).contains(slotLimit), fontSize.isFinite, (10...32).contains(fontSize),
              Set(schedules.map(\.id)).count == schedules.count else { throw PadError.invalidSettings }
        for schedule in schedules { try schedule.validate() }
        for weekday in 1...7 {
            guard schedules.filter({ $0.weekdays.contains(weekday) }).count <= slotLimit else { throw PadError.capacity }
        }
    }
    public func due(on day: String) -> [RepeatTask] { schedules.filter { $0.isDue(on: day) } }
}

public enum TaskInput {
    public static let maxCharacters = 500
    public static let maxLines = 5
    public static func accepts(_ text: String) -> Bool {
        text.count <= maxCharacters && text.components(separatedBy: "\n").count <= maxLines
    }
    public static func allowsChange(from original: String, to candidate: String) -> Bool {
        if accepts(candidate) { return true }
        // Permit repairing already oversized saved text, never introducing a violation.
        return !accepts(original) && candidate.count < original.count &&
            candidate.components(separatedBy: "\n").count <= max(maxLines, original.components(separatedBy: "\n").count)
    }
}

public struct PadTask: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var text: String
    public var isComplete = false
    public var priority: TaskPriority = .none
    public var color: TaskColor?
    public var effort: Int?
    public var scheduleID: UUID?
    public var scheduledTime: String?
    public init(text: String = "") { self.text = text }
    public var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var canCarry: Bool { !isBlank && !isComplete && scheduleID == nil }
    public mutating func clear() { let oldID = id; self = PadTask(); id = oldID }
}

public struct PadSheet: Codable, Equatable {
    public var id = UUID()
    public var day: String
    public var tasks: [PadTask]
    public var notes = ""
    public var closingNotes = ""
    public init(day: String, limit: Int = 30) { self.day = day; tasks = (0..<max(0, limit)).map { _ in PadTask() } }
    public var used: Int { tasks.filter { !$0.isBlank }.count }
    public mutating func move(_ id: UUID, offset: Int) throws {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { throw PadError.missingTask }
        let destination = index + offset
        guard tasks.indices.contains(destination) else { return }
        let task = tasks.remove(at: index); tasks.insert(task, at: destination)
    }
    public mutating func move(_ id: UUID, to destinationID: UUID) throws {
        guard let from = tasks.firstIndex(where: { $0.id == id }), let to = tasks.firstIndex(where: { $0.id == destinationID }) else { throw PadError.missingTask }
        guard from != to else { return }; tasks.insert(tasks.remove(at: from), at: to)
    }
    public mutating func resize(to limit: Int) throws {
        guard used <= limit else { throw PadError.capacity }
        if tasks.count > limit {
            var remove = tasks.count - limit
            tasks = tasks.reversed().filter { task in
                if task.isBlank && task.scheduleID == nil && remove > 0 { remove -= 1; return false }; return true
            }.reversed()
            guard tasks.count == limit else { throw PadError.capacity }
        }
        while tasks.count < limit { tasks.append(PadTask()) }
    }
}

public struct RolloverDraft: Codable, Equatable {
    public var sourceSheetID: UUID
    public var selectedTaskIDs: Set<UUID> = []
    public var carryNotes = false
    public var closingNotes = ""
}

public struct PadState: Codable, Equatable {
    public var version = 2
    public var sheet: PadSheet
    public var theme: PadTheme = .karst
    public var settings = PadSettings()
    public var draft: RolloverDraft?
    public init(sheet: PadSheet) { self.sheet = sheet }
    private enum CodingKeys: String, CodingKey { case version, sheet, theme, settings, draft }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        sheet = try c.decode(PadSheet.self, forKey: .sheet)
        theme = try c.decode(PadTheme.self, forKey: .theme)
        settings = try c.decodeIfPresent(PadSettings.self, forKey: .settings) ?? PadSettings()
        draft = try c.decodeIfPresent(RolloverDraft.self, forKey: .draft)
    }
    public func validate() throws {
        guard version == 2, PadDay.isValid(sheet.day),
              Set(sheet.tasks.map(\.id)).count == sheet.tasks.count,
              sheet.tasks.allSatisfy({ (0...9).contains($0.priority.rawValue) && EffortScale.accepts($0.effort) }),
              Set(sheet.tasks.compactMap(\.scheduleID)).count == sheet.tasks.compactMap(\.scheduleID).count else { throw PadError.invalidData }
        try settings.validate()
        guard sheet.tasks.count == settings.slotLimit else { throw PadError.invalidData }
        if let draft {
            let eligible = Set(sheet.tasks.filter { $0.canCarry }.map(\.id))
            guard draft.sourceSheetID == sheet.id, draft.selectedTaskIDs.isSubset(of: eligible) else { throw PadError.invalidData }
        }
    }

}

public enum PadError: LocalizedError {
    case capacity, missingTask, invalidData, staleRollover, finishRollover, invalidSettings, invalidSchedule, taskTooLong
    public var errorDescription: String? {
        switch self {
        case .capacity: return "These items do not fit the configured slots. Clear a filled slot, reduce carried tasks, or increase the slot limit in Settings."
        case .missingTask: return "This slot is no longer on the sheet."
        case .invalidData: return "The saved pad could not be read safely. Existing files have not been replaced."
        case .staleRollover: return "The date has changed. Your previous sheet is still safe; return when a new day begins."
        case .finishRollover: return "Finish the new-day decision before changing this sheet."
        case .invalidSettings: return "Use 1–100 slots and a font size of 10–32 points."
        case .invalidSchedule: return "A repeating task needs focused text, at least one weekday, and a valid time."
        case .taskTooLong: return "Keep a task to five lines and 500 characters or fewer."
        }
    }
}

public enum PadDay {
    public static func local(_ date: Date = Date(), timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    public static func date(_ day: String) -> Date? {
        guard day.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else { return nil }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts[0] > 0 else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: c), calendar.dateComponents([.year, .month, .day], from: date) == c else { return nil }
        return date
    }
    public static func isValid(_ day: String) -> Bool { date(day) != nil }
    public static func weekday(_ day: String) -> Int? {
        guard let date = date(day) else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.component(.weekday, from: date)
    }
    public static func display(_ day: String, format: String = "", locale: Locale = .current) -> String {
        guard let date = date(day) else { return day }
        let formatter = DateFormatter(); formatter.locale = locale; formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if format.isEmpty { formatter.dateStyle = .full } else { formatter.dateFormat = format }
        return formatter.string(from: date)
    }
}

public enum PadText {
    public static func format(_ pattern: String, state: PadState) -> String {
        let values = ["used": String(state.sheet.used), "limit": String(state.settings.slotLimit),
                      "completed": String(state.sheet.tasks.filter { !$0.isBlank && $0.isComplete }.count),
                      "remaining": String(state.settings.slotLimit - state.sheet.used),
                      "date": PadDay.display(state.sheet.day, format: state.settings.dateFormat)]
        return values.reduce(pattern) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }
}

public final class PadStore {
    public private(set) var state: PadState
    public let directory: URL
    private let write: (Data, URL) throws -> Void
    private var activeFile: URL { directory.appendingPathComponent("active.json") }
    public init(directory: URL, today: String, write: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) throws {
        self.directory = directory; self.write = write; state = PadState(sheet: PadSheet(day: today))
        guard PadDay.isValid(today) else { throw PadError.invalidData }
        if FileManager.default.fileExists(atPath: activeFile.path) {
            let loaded: PadState
            do { loaded = try JSONDecoder().decode(PadState.self, from: Data(contentsOf: activeFile)); try loaded.validate() }
            catch { throw PadError.invalidData }
            state = loaded
            return
        }
        if FileManager.default.fileExists(atPath: directory.path), !(try FileManager.default.contentsOfDirectory(atPath: directory.path)).isEmpty { throw PadError.invalidData }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); try persist(state)
    }
    private func persist(_ next: PadState) throws {
        try next.validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try write(encoder.encode(next), activeFile)
    }
    public func save(_ next: PadState) throws {
        guard next.sheet.id == state.sheet.id, next.sheet.day == state.sheet.day else { throw PadError.staleRollover }
        try persist(next); state = next
    }
    public func editSheet(_ edit: (inout PadSheet) throws -> Void) throws {
        guard state.draft == nil else { throw PadError.finishRollover }; var next = state; try edit(&next.sheet); try save(next)
    }
    public func setTheme(_ theme: PadTheme) throws { var next = state; next.theme = theme; try save(next) }
    public func settingsCandidate(_ settings: PadSettings) throws -> PadState {
        guard state.draft == nil else { throw PadError.finishRollover }
        try settings.validate(); var next = state; next.settings = settings
        let oldRules = Dictionary(uniqueKeysWithValues: state.settings.schedules.map { ($0.id, $0) })
        let rules = Dictionary(uniqueKeysWithValues: settings.schedules.map { ($0.id, $0) })
        for index in next.sheet.tasks.indices {
            if let id = next.sheet.tasks[index].scheduleID {
                if let rule = rules[id], rule.isDue(on: next.sheet.day) {
                    if oldRules[id] == rule { continue }
                    next.sheet.tasks[index].text = rule.text; next.sheet.tasks[index].scheduledTime = rule.time
                    next.sheet.tasks[index].priority = rule.priority; next.sheet.tasks[index].color = rule.color
                    next.sheet.tasks[index].effort = rule.effort
                } else { next.sheet.tasks[index].scheduleID = nil; next.sheet.tasks[index].scheduledTime = nil }
            }
        }
        try next.sheet.resize(to: settings.slotLimit)
        for rule in settings.due(on: next.sheet.day) where !next.sheet.tasks.contains(where: { $0.scheduleID == rule.id }) {
            guard let blank = next.sheet.tasks.firstIndex(where: { $0.isBlank && $0.scheduleID == nil }) else { throw PadError.capacity }
            next.sheet.tasks[blank] = rule.occurrence()
        }
        try next.validate(); return next
    }
    public func applySettings(_ settings: PadSettings) throws { try save(settingsCandidate(settings)) }
    public func beginRollover(to day: String) throws {
        guard PadDay.isValid(day) else { throw PadError.invalidData }
        guard day > state.sheet.day, state.draft == nil else { return }
        var next = state; next.draft = RolloverDraft(sourceSheetID: state.sheet.id)
        if state.settings.carryMode == .automatic {
            next.draft!.selectedTaskIDs = Set(state.sheet.tasks.filter(\.canCarry).map(\.id))
            next.draft!.carryNotes = state.settings.notesEnabled
        }
        try save(next)
        if state.settings.carryMode != .ask { try confirmRollover(to: day) }
    }
    public func editDraft(_ edit: (inout RolloverDraft) -> Void) throws {
        guard var draft = state.draft else { throw PadError.staleRollover }; edit(&draft)
        var next = state; next.draft = draft; try save(next)
    }
    public func confirmRollover(to day: String) throws {
        guard PadDay.isValid(day), day > state.sheet.day, let draft = state.draft, draft.sourceSheetID == state.sheet.id else { throw PadError.staleRollover }
        try state.validate(); var archived = state.sheet; archived.closingNotes = draft.closingNotes
        let scheduled = state.settings.due(on: day).map { $0.occurrence() }
        let carried = archived.tasks.filter { $0.canCarry && draft.selectedTaskIDs.contains($0.id) }
        guard scheduled.count + carried.count <= state.settings.slotLimit else { throw PadError.capacity }
        var sheet = PadSheet(day: day, limit: 0); sheet.tasks = scheduled + carried
        try sheet.resize(to: state.settings.slotLimit); sheet.notes = draft.carryNotes ? archived.notes : ""
        var next = state; next.sheet = sheet; next.draft = nil
        let archives = directory.appendingPathComponent("Archives", isDirectory: true)
        try FileManager.default.createDirectory(at: archives, withIntermediateDirectories: true)
        let archiveFile = archives.appendingPathComponent("\(archived.day)-\(archived.id.uuidString).md")
        try write(Data(Self.markdown(archived).utf8), archiveFile)
        try persist(next); state = next
    }
    public static func markdown(_ sheet: PadSheet) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = String(decoding: try encoder.encode(sheet), as: UTF8.self)
        let tasks = sheet.tasks.filter { !$0.isBlank }.map { "- [\($0.isComplete ? "x" : " ")] " + $0.text.replacingOccurrences(of: "\n", with: "\n  ") }.joined(separator: "\n")
        return "# TaskPad · \(sheet.day)\n\n\(tasks)\n\n## Daily notes\n\n\(sheet.notes)\n\n## Closing notes\n\n\(sheet.closingNotes)\n\n## Sheet metadata\n\n```json\n\(metadata)\n```\n"
    }
}
