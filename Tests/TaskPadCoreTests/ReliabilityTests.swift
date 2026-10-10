import XCTest
@testable import TaskPadCore

final class ReliabilityTests: XCTestCase {
    private func isolated(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-reliability-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    // TPR-04: a failed save cannot change the last good disk snapshot.
    func testFailedEditKeepsLastDurableStateAndCanRetryCandidate() throws {
        try isolated { directory in
            var fail = false
            let store = try PadStore(directory: directory, today: "2026-10-10", write: { data, file in
                if fail { throw CocoaError(.fileWriteNoPermission) }
                try data.write(to: file, options: .atomic)
            })
            try store.editSheet { $0.tasks[0].text = "Good" }
            let previous = store.state
            var candidate = previous
            candidate.sheet.tasks[0].text = "Recoverable edit"
            fail = true
            XCTAssertThrowsError(try store.save(candidate))
            XCTAssertEqual(store.state, previous)
            XCTAssertEqual(try PadStore(directory: directory, today: "2026-10-10").state, previous)
            fail = false
            try store.save(candidate)
            XCTAssertEqual(try PadStore(directory: directory, today: "2026-10-10").state.sheet.tasks[0].text, "Recoverable edit")
        }
    }

    // TPR-08: actual filesystem writes, faults at each selected durable boundary.
    func testRolloverInterruptionNeverLosesPreviousAndRetryIsIdempotent() throws {
        for failingBoundary in ["archive", "replacement", "none"] {
            try isolated { directory in
                var fault: String?
                let store = try PadStore(directory: directory, today: "2026-10-10", write: { data, file in
                    if (fault == "archive" && file.pathExtension == "md") || (fault == "replacement" && file.lastPathComponent == "active.json") {
                        throw CocoaError(.fileWriteNoPermission)
                    }
                    try data.write(to: file, options: .atomic)
                })
                try store.editSheet {
                     $0.tasks[0].text = "**Carry**\nwith line"
                    $0.tasks[1].text = "Completed"
                    $0.tasks[0].priority = .low
                    $0.tasks[0].color = .purple
                    $0.tasks[1].isComplete = true
                    $0.notes = "WORK"
                }
                let previous = store.state.sheet
                try store.beginRollover(to: "2026-10-14")
                try store.editDraft {
                    $0.selectedTaskIDs = [previous.tasks[0].id]
                    $0.carryNotes = true
                    $0.closingNotes = "CLOSE"
                }
                let pending = store.state
                fault = failingBoundary == "none" ? nil : failingBoundary
                if fault != nil {
                    XCTAssertThrowsError(try store.confirmRollover(to: "2026-10-14"))
                    XCTAssertEqual(store.state, pending)
                    let recovered = try PadStore(directory: directory, today: "2026-10-14")
                    XCTAssertEqual(recovered.state, pending)
                    try recovered.confirmRollover(to: "2026-10-14")
                } else { try store.confirmRollover(to: "2026-10-14") }
                let recovered = try PadStore(directory: directory, today: "2026-10-14")
                XCTAssertEqual(recovered.state.sheet.tasks[0], previous.tasks[0])
                XCTAssertEqual(recovered.state.sheet.used, 1)
                XCTAssertEqual(recovered.state.sheet.tasks.count, 30)
                XCTAssertEqual(recovered.state.sheet.notes, "WORK")
                XCTAssertEqual(recovered.state.sheet.closingNotes, "")
                try recovered.beginRollover(to: "2026-10-14")
                XCTAssertNil(recovered.state.draft)
                let archives = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("Archives"), includingPropertiesForKeys: nil)
                XCTAssertEqual(archives.count, 1)
                let archivedText = try String(contentsOf: archives[0])
                XCTAssertTrue(archivedText.contains("CLOSE"))
                XCTAssertTrue(archivedText.contains("Completed"))
                XCTAssertTrue(archivedText.contains("purple"))
                XCTAssertTrue(archivedText.contains(previous.id.uuidString))
                let json = try XCTUnwrap(archivedText.components(separatedBy: "```json\n").last?.components(separatedBy: "\n```").first)
                var expectedArchive = previous
                expectedArchive.closingNotes = "CLOSE"
                XCTAssertEqual(try JSONDecoder().decode(PadSheet.self, from: Data(json.utf8)), expectedArchive)
            }
        }
    }

    // TPR-02: stable identity survives edit, toggle twice, reorder and delete.
    func testMixedTaskMutationDoesNotSortOrAffectOtherRows() throws {
        try isolated { directory in
            let store = try PadStore(directory: directory, today: "2026-10-10")
            try store.editSheet { sheet in
                for (index, text) in ["A", "B", "C", "D"].enumerated() { sheet.tasks[index].text = text }
            }
            let original = store.state.sheet.tasks
            try store.editSheet { sheet in
                sheet.tasks[1].text = "Edited B"
                sheet.tasks[1].isComplete.toggle()
                sheet.tasks[1].isComplete.toggle()
                sheet.tasks[1].priority = .medium
                sheet.tasks[1].color = .red
                try sheet.move(original[3].id, offset: -3)
                let clearIndex = sheet.tasks.firstIndex { $0.id == original[2].id }!
                sheet.tasks[clearIndex].clear()
            }
            let reopened = try PadStore(directory: directory, today: "2026-10-10")
            XCTAssertEqual(Array(reopened.state.sheet.tasks.prefix(4)).map(\.text), ["D", "A", "Edited B", ""])
            XCTAssertEqual(reopened.state.sheet.tasks.count, 30)
            XCTAssertEqual(reopened.state.sheet.tasks[1], original[0])
            XCTAssertFalse(reopened.state.sheet.tasks[2].isComplete)
            XCTAssertEqual(reopened.state.sheet.tasks[2].color, .red)
        }
    }

    // TPR-06/07: decisions are independent and retained; completed selection rejected.
    func testAllNoneNotesOnlyAndRetainedDecision() throws {
        try isolated { directory in
            let store = try PadStore(directory: directory, today: "2026-10-10")
            try store.editSheet {
                $0.tasks[0].text = "One"
                $0.tasks[1].text = "Done"
                $0.tasks[1].isComplete = true
                $0.notes = "WORK"
            }
            try store.beginRollover(to: "2026-10-11")
            let eligible = store.state.sheet.tasks[0].id
            let completed = store.state.sheet.tasks[1].id
            XCTAssertThrowsError(try store.editDraft { $0.selectedTaskIDs = [completed] })
            try store.editDraft {
                $0.selectedTaskIDs = [eligible]
                $0.carryNotes = true
                $0.closingNotes = "CLOSE"
            }
            let reopened = try PadStore(directory: directory, today: "2026-10-11")
            XCTAssertEqual(reopened.state.draft, store.state.draft)
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Archives").path))
            try reopened.editDraft { $0.selectedTaskIDs = [] }
            try reopened.confirmRollover(to: "2026-10-12")
            XCTAssertEqual(reopened.state.sheet.used, 0)
            XCTAssertEqual(reopened.state.sheet.notes, "WORK")
        }
    }

    // TPR-09/10: civil dates, not elapsed 24-hour periods or UTC dates.
    func testLocalDateTimezoneAndDSTBoundaries() throws {
        let formatter = ISO8601DateFormatter()
        let midnight = formatter.date(from: "2026-10-10T22:30:00Z")!
        XCTAssertEqual(PadDay.local(midnight, timeZone: TimeZone(identifier: "Europe/Helsinki")!), "2026-10-11")
        XCTAssertEqual(PadDay.local(midnight, timeZone: TimeZone(identifier: "America/Los_Angeles")!), "2026-10-10")
        let beforeDST = formatter.date(from: "2026-03-28T22:30:00Z")!
        let afterDST = formatter.date(from: "2026-03-29T21:30:00Z")!
        XCTAssertEqual(PadDay.local(beforeDST, timeZone: TimeZone(identifier: "Europe/Helsinki")!), "2026-03-29")
        XCTAssertEqual(PadDay.local(afterDST, timeZone: TimeZone(identifier: "Europe/Helsinki")!), "2026-03-30")
        try isolated { directory in
            let store = try PadStore(directory: directory, today: "2026-10-10")
            XCTAssertNil(store.state.draft)
            try store.beginRollover(to: "2026-10-10")
            XCTAssertNil(store.state.draft)
            try store.beginRollover(to: "2026-10-09")
            XCTAssertNil(store.state.draft)
            try store.beginRollover(to: "2026-10-14")
            let draft = store.state.draft
            try store.beginRollover(to: "2026-10-14")
            XCTAssertEqual(store.state.draft, draft)
            try store.confirmRollover(to: "2026-10-15")
            XCTAssertEqual(store.state.sheet.day, "2026-10-15")
        }
    }

    func testInvalidStoredDataAndMissingStateAreNotSilentlyReset() throws {
        try isolated { directory in
            let store = try PadStore(directory: directory, today: "2026-10-10")
            var invalid = store.state
            invalid.sheet.day = "2026-02-30"
            let file = directory.appendingPathComponent("active.json")
            let bytes = try JSONEncoder().encode(invalid)
            try bytes.write(to: file)
            XCTAssertThrowsError(try PadStore(directory: directory, today: "2026-10-11"))
            XCTAssertEqual(try Data(contentsOf: file), bytes)
            try FileManager.default.removeItem(at: file)
            try Data("Preserve".utf8).write(to: directory.appendingPathComponent("existing.md"))
            XCTAssertThrowsError(try PadStore(directory: directory, today: "2026-10-11"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        }
    }
}
