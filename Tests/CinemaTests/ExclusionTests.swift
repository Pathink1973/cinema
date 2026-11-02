import Foundation
import Testing
@testable import Cinema

@Test @MainActor func exclusionsSurviveScanAndRestartAndCanBeRestored() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let media = root.appendingPathComponent("media")
    let storage = root.appendingPathComponent("storage")
    try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    let video = media.appendingPathComponent("Arrival (2016).mkv")
    let caption = media.appendingPathComponent("Arrival (2016).pt.srt")
    try Data("test-video".utf8).write(to: video)
    try Data("test-caption".utf8).write(to: caption)
    let library = Library(directory: storage)
    library.folders = [media.path]
    var movie = Movie(path: video.path, title: "Arrival", year: "2016", subtitles: [caption.path])
    movie.favorite = true
    library.movies = [movie]
    library.exclude(movie)
    library.exclude(movie)
    #expect(library.movies.isEmpty)
    #expect(library.excludedMovies.count == 1)
    let reopened = Library(directory: storage)
    #expect(reopened.movies.isEmpty)
    #expect(reopened.excludedMovies.count == 1)
    reopened.scan()
    while reopened.isScanning || reopened.busy { try await Task.sleep(for: .milliseconds(10)) }
    #expect(reopened.movies.isEmpty)
    #expect(try Data(contentsOf: video) == Data("test-video".utf8))
    #expect(try Data(contentsOf: caption) == Data("test-caption".utf8))
    reopened.restore(movie)
    #expect(reopened.movies.first?.favorite == true)
    #expect(reopened.movies.first?.subtitles == [caption.path])
    #expect(reopened.excludedMovies.isEmpty)
    #expect(Library(directory: storage).movies.count == 1)
}
@Test @MainActor func oldLibraryLoadsWithoutExclusions() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data(#"{"movies":[],"folders":[]}"#.utf8).write(to: root.appendingPathComponent("library.json"))
    let library = Library(directory: root)
    #expect(library.message == nil)
    #expect(library.excludedMovies.isEmpty)
}
