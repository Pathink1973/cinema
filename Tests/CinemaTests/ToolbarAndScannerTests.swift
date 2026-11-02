import Foundation
import Testing
@testable import Cinema

@Test func searchFindsOriginalLocalizedAndDirectorNames() {
    var movie = Movie(path: "/movies/Amelie.2001.1080p.mkv", title: "Amelie", year: "2001")
    movie.metadata = MovieDetails(id: 1, title: "O Fabuloso Destino de Amélie", original_title: "Le Fabuleux Destin d'Amélie Poulain", genres: [.init(name: "Comédia")], credits: .init(cast: [], crew: [.init(name: "Jean-Pierre Jeunet", job: "Director")]))
    #expect(movieMatchesQuery(movie, query: "amelie"))
    #expect(movieMatchesQuery(movie, query: "  Jeunet 2001 "))
    #expect(movieMatchesQuery(movie, query: "poulain"))
    #expect(movieMatchesQuery(movie, query: "1080p"))
    #expect(movieMatchesQuery(movie, query: "comedia"))
    #expect(!movieMatchesQuery(movie, query: "Wes Anderson"))
    #expect(movieMatchesQuery(movie, query: "   "))
}
@Test func scannerGroupsSubtitlesAndDeduplicatesOverlappingRoots() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = root.appendingPathComponent("first"), second = root.appendingPathComponent("second")
    for folder in [first, second] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    try Data("video".utf8).write(to: first.appendingPathComponent("Movie (2020).MKV"))
    try Data("captions".utf8).write(to: first.appendingPathComponent("Movie (2020).pt.SRT"))
    try Data("different folder".utf8).write(to: second.appendingPathComponent("Movie (2020).en.srt"))
    let result = LibraryScanner.scan([root.path, first.path])
    #expect(result.movies.count == 1)
    #expect(result.movies[0].subtitles.count == 1)
    #expect(result.movies[0].subtitles[0].hasSuffix(".pt.SRT"))
    #expect(result.fingerprints.count == 1)
}
private final class ChangeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var changed = false
    func set() { lock.lock(); changed = true; lock.unlock() }
    var value: Bool { lock.lock(); defer { lock.unlock() }; return changed }
}
@Test func fileWatcherDetectsChangesInSubfolders() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let nested = root.appendingPathComponent("nested")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let flag = ChangeFlag()
    let watcher = FolderChangeWatcher(paths: [root.path]) { flag.set() }
    defer { watcher.stop() }
    try Data("video".utf8).write(to: nested.appendingPathComponent("New Movie.mkv"))
    for _ in 0..<60 { if flag.value { break }; try await Task.sleep(for: .milliseconds(100)) }
    #expect(flag.value)
}
