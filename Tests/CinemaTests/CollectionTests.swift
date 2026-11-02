import Foundation
import Testing
@testable import Cinema
@Test @MainActor func collectionsPersistAndNeverDeleteMovies() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let library = Library(directory: root, enrichNewMovies: false)
    let movie = Movie(path: "/movies/test.mkv", title: "Test")
    library.movies = [movie]
    let first = try #require(library.createCollection(" Wes Anderson "))
    #expect(library.createCollection("wes anderson") == first)
    #expect(library.createCollection("   ") == nil)
    let second = try #require(library.createCollection("Favoritos de animação"))
    library.setMembership(movie.path, in: first, included: true)
    library.setMembership(movie.path, in: second, included: true)
    let reopened = Library(directory: root, enrichNewMovies: false)
    #expect(reopened.collections.count == 2)
    #expect(reopened.collections.allSatisfy { $0.moviePaths.contains(mediaPathKey(movie.path)) })
    reopened.setMembership(movie.path, in: first, included: false)
    #expect(reopened.movies.count == 1)
    #expect(reopened.collections.first(where: { $0.id == second })?.moviePaths.count == 1)
    reopened.deleteCollection(first)
    #expect(reopened.movies.count == 1)
    #expect(Library(directory: root, enrichNewMovies: false).collections.count == 1)
    reopened.exclude(movie)
    reopened.restore(movie)
    #expect(reopened.collections.first?.moviePaths.contains(mediaPathKey(movie.path)) == true)
}
