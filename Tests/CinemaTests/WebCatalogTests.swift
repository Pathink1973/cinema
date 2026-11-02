import Foundation
import Testing
@testable import Cinema

private func dataOf(_ response: LocalResponse) throws -> Data {
    guard case let .data(bytes, _, _) = response else { throw phoneError("Expected data response") }; return bytes
}
@Test @MainActor func catalogSharesFavoritesAndCollectionsWithoutExposingPaths() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let library = Library(directory: root, enrichNewMovies: false)
    let movie = Movie(path: "/private/movies/sample.mkv", title: "Movie <test>", subtitles: ["/private/movies/sample.pt.srt"])
    library.movies = [movie]
    let service = WebCatalog(library: library, accessToken: String(repeating: "a", count: 72))
    let id = catalogMovieID(movie.path)
    let initial = try dataOf(service.route(.init(method: "GET", path: "/api/library", headers: [:], body: Data())))
    #expect(!String(decoding: initial, as: UTF8.self).contains("/private/movies"))
    #expect(String(decoding: initial, as: UTF8.self).contains("sample.pt.srt"))
    _ = service.route(.init(method: "POST", path: "/api/movies/\(id)/favorite", headers: [:], body: Data(#"{"value":true}"#.utf8)))
    #expect(library.movies[0].favorite)
    let collection = try #require(library.createCollection("Wes Anderson"))
    let request = try JSONSerialization.data(withJSONObject: ["id": collection.uuidString, "included": true])
    _ = service.route(.init(method: "POST", path: "/api/movies/\(id)/collection", headers: [:], body: request))
    #expect(library.collections[0].moviePaths.contains(mediaPathKey(movie.path)))
    #expect(Library(directory: root, enrichNewMovies: false).movies[0].favorite)
    let page = try dataOf(service.route(.init(method: "GET", path: "/", headers: [:], body: Data())))
    #expect(String(decoding: page, as: UTF8.self).contains("apple-touch-icon"))
    library.exclude(movie)
    #expect(service.snapshot().movies.isEmpty)
}
@Test func catalogTransportRequiresTokenAndExplicitMutationHeader() async throws {
    let server = try PhoneServer(token: "test-access") { request in .json(["method": request.method, "body": String(decoding: request.body, as: UTF8.self)]) }
    let port = try await server.start(); defer { server.stop() }
    let base = "http://127.0.0.1:\(port)"
    let (_, unauthorized) = try await URLSession.shared.data(from: URL(string: base + "/api/library")!)
    #expect((unauthorized as? HTTPURLResponse)?.statusCode == 404)
    var request = URLRequest(url: URL(string: base + "/test-access/api/action")!)
    request.httpMethod = "POST"; request.httpBody = Data(#"{"value":true}"#.utf8)
    let (_, blocked) = try await URLSession.shared.data(for: request)
    #expect((blocked as? HTTPURLResponse)?.statusCode == 403)
    request.setValue("1", forHTTPHeaderField: "X-Cinema-Action")
    request.setValue("https://other.example", forHTTPHeaderField: "Origin")
    let (_, crossOrigin) = try await URLSession.shared.data(for: request)
    #expect((crossOrigin as? HTTPURLResponse)?.statusCode == 403)
    request.setValue(base, forHTTPHeaderField: "Origin")
    let (data, allowed) = try await URLSession.shared.data(for: request)
    #expect((allowed as? HTTPURLResponse)?.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self).contains("value"))
}
@Test @MainActor func catalogPreparesVerifiedMovieAndServesItToVLC() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("movie.mp4"), srt = root.appendingPathComponent("movie.srt")
    _ = try MediaCommand().run(PhoneMedia.tool("ffmpeg"), ["-nostdin", "-v", "error", "-f", "lavfi", "-i", "color=c=black:s=320x180:d=2", "-c:v", "libx264", input.path])
    try "1\n00:00:00,100 --> 00:00:01,800\nLegenda do catálogo\n".write(to: srt, atomically: true, encoding: .utf8)
    let library = Library(directory: root.appendingPathComponent("data"), enrichNewMovies: false)
    let movie = Movie(path: input.path, title: "Test movie", subtitles: [srt.path]); library.movies = [movie]
    let token = String(repeating: "b", count: 72), service = WebCatalog(library: library, accessToken: token)
    await service.start(bindPort: 0); defer { service.stop() }
    let port = try #require(service.link?.port)
    let request = LocalRequest(method: "POST", path: "/api/movies/\(catalogMovieID(movie.path))/prepare", headers: [:], body: Data(#"{"subtitle":0}"#.utf8))
    var status = try JSONSerialization.jsonObject(with: dataOf(service.route(request))) as! [String: Any]
    let id = try #require(status["id"] as? String)
    for _ in 0..<100 {
        if status["state"] as? String != "preparing" { break }
        try await Task.sleep(for: .milliseconds(100))
        status = try JSONSerialization.jsonObject(with: dataOf(service.route(.init(method: "GET", path: "/api/jobs/\(id)", headers: [:], body: Data())))) as! [String: Any]
    }
    #expect(status["state"] as? String == "ready")
    #expect((status["progress"] as? [String: Any])?["percent"] as? Int == 100)
    let videoPath = try #require(status["video"] as? String)
    var stream = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/\(token)/\(videoPath)")!)
    stream.setValue("bytes=0-63", forHTTPHeaderField: "Range")
    let (data, response) = try await URLSession.shared.data(for: stream)
    #expect(data.count == 64)
    #expect((response as? HTTPURLResponse)?.statusCode == 206)
    let repeated = try JSONSerialization.jsonObject(with: dataOf(service.route(request))) as! [String: Any]
    #expect(repeated["id"] as? String == id)
    service.clearPrepared()
    let (_, missing) = try await URLSession.shared.data(for: stream)
    #expect((missing as? HTTPURLResponse)?.statusCode == 404)
    #expect(FileManager.default.fileExists(atPath: input.path))
}
