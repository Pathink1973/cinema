import Foundation
import Testing
@testable import Cinema

private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [PreparationProgress] = []
    func add(_ value: PreparationProgress) { lock.lock(); values.append(value); lock.unlock() }
    var updates: [PreparationProgress] { lock.lock(); defer { lock.unlock() }; return values }
}
@Test func mediaProgressUsesMicrosecondsAndHandlesUnknownDuration() throws {
    #expect(remuxProgress("out_time_us=5000000", duration: 10) == 43.5)
    #expect(remuxProgress("out_time_us=999000000", duration: 10) == 85)
    #expect(remuxProgress("out_time_us=N/A", duration: 10) == nil)
    #expect(remuxProgress("out_time_us=1000", duration: nil) == nil)
    #expect(remuxProgress("out_time_us=1000", duration: 0) == nil)
}
@Test func actualPreparationReportsMonotonicProgressAndValidatedCompletion() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("test.mp4"), srt = root.appendingPathComponent("test.srt"), output = root.appendingPathComponent("prepared.mkv")
    _ = try MediaCommand().run(PhoneMedia.tool("ffmpeg"), ["-nostdin", "-v", "error", "-f", "lavfi", "-i", "color=c=black:s=320x180:d=3", "-c:v", "libx264", input.path])
    try "1\n00:00:00,100 --> 00:00:02,900\nLegenda verificada\n".write(to: srt, atomically: true, encoding: .utf8)
    let log = ProgressLog()
    try PhoneMedia.prepare(movie: Movie(path: input.path, title: "Progresso"), subtitle: srt.path, output: output, runner: MediaCommand()) { log.add($0) }
    let updates = log.updates
    #expect(updates.first?.percent == 1)
    #expect(updates.last?.percent == 100)
    #expect(updates.contains { (3...85).contains($0.percent) })
    #expect(updates.contains { (86...99).contains($0.percent) })
    #expect(zip(updates, updates.dropFirst()).allSatisfy { $0.percent <= $1.percent })
    #expect(updates.dropLast().allSatisfy { $0.percent < 100 })
    #expect(updates.allSatisfy { $0.elapsedSeconds >= 0 })
    let failedLog = ProgressLog()
    #expect(throws: (any Error).self) {
        try PhoneMedia.prepare(movie: Movie(path: input.path, title: "Sem legendas"), subtitle: nil, output: root.appendingPathComponent("rejected.mkv"), runner: MediaCommand()) { failedLog.add($0) }
    }
    #expect(failedLog.updates.allSatisfy { $0.percent < 100 })
}
