import Foundation
import Testing
@testable import Cinema

@Test func growingFilesWaitForStableObservations() {
    var readiness = FileReadiness()
    let start = Date()
    var fingerprint = MediaFingerprint(size: 100, modified: start)
    let observation1 = !readiness.ready(path: "film", fingerprint: fingerprint, now: start)
    #expect(observation1)
    let observation2 = !readiness.ready(path: "film", fingerprint: fingerprint, now: start.addingTimeInterval(9))
    #expect(observation2)
    fingerprint.size = 200
    let observation3 = !readiness.ready(path: "film", fingerprint: fingerprint, now: start.addingTimeInterval(15))
    #expect(observation3)
    fingerprint.subtitles = "new caption"
    let observation4 = !readiness.ready(path: "film", fingerprint: fingerprint, now: start.addingTimeInterval(30))
    #expect(observation4)
    let observation5 = readiness.ready(path: "film", fingerprint: fingerprint, now: start.addingTimeInterval(45))
    #expect(observation5)
    let observation6 = !readiness.ready(path: "empty", fingerprint: .init(size: 0, modified: start), now: start)
    #expect(observation6)
}
@Test @MainActor func newMovieImportsOnceAndLateSubtitlesAreAssociated() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let media = root.appendingPathComponent("media")
    try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    let video = media.appendingPathComponent("New Movie (2026).mkv")
    try Data("video".utf8).write(to: video)
    let library = Library(directory: root.appendingPathComponent("store"), enrichNewMovies: false)
    #expect(library.addFolders([media]))
    while library.isScanning || library.busy { try await Task.sleep(for: .milliseconds(10)) }
    #expect(library.movies.isEmpty)
    #expect(library.message == nil)
    try await Task.sleep(for: .seconds(10.1))
    library.scan(automatic: true)
    while library.isScanning || library.busy { try await Task.sleep(for: .milliseconds(10)) }
    #expect(library.movies.count == 1)
    #expect(library.movies.first?.addedAt != nil)
    #expect(library.newMovieIDs.count == 1)
    let caption = media.appendingPathComponent("New Movie (2026).pt.srt")
    try Data("captions".utf8).write(to: caption)
    library.scan(automatic: true)
    while library.isScanning || library.busy { try await Task.sleep(for: .milliseconds(10)) }
    #expect(library.movies.count == 1)
    #expect(library.movies.first?.subtitles.count == 1)
    #expect(library.newMovieIDs.count == 1)
    #expect(library.message == nil)
    #expect(Library(directory: root.appendingPathComponent("store"), enrichNewMovies: false).movies.count == 1)
}
