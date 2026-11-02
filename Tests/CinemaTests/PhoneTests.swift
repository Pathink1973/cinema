import Foundation
import Testing
@testable import Cinema
@Test func httpRangesSupportSeekingAndRejectBadInput() {
    #expect(HTTPByteRange.parse("bytes=10-19", size: 100) == .init(start: 10, end: 19))
    #expect(HTTPByteRange.parse("bytes=90-", size: 100) == .init(start: 90, end: 99))
    #expect(HTTPByteRange.parse("bytes=-10", size: 100) == .init(start: 90, end: 99))
    #expect(HTTPByteRange.parse("bytes=100-", size: 100) == nil)
    #expect(HTTPByteRange.parse("bytes=0-1,3-4", size: 100) == nil)
    #expect(!PhoneServer.isPrivate("8.8.8.8"))
    #expect(PhoneServer.isPrivate("192.168.1.10"))
}
@Test func serverRequiresTokenAndServesByteRanges() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let contents = Data((0..<255).map(UInt8.init))
    try contents.write(to: file); defer { try? FileManager.default.removeItem(at: file) }
    let server = try PhoneServer(file: file, title: "A < B")
    let port = try await server.start(); defer { server.stop() }
    let base = "http://127.0.0.1:\(port)"
    var request = URLRequest(url: URL(string: base + "/" + server.token + "/film.mkv")!)
    request.setValue("bytes=10-19", forHTTPHeaderField: "Range")
    let (bytes, response) = try await URLSession.shared.data(for: request)
    #expect((response as? HTTPURLResponse)?.statusCode == 206)
    #expect(bytes == contents.subdata(in: 10..<20))
    #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Range") == "bytes 10-19/255")
    let (_, rejected) = try await URLSession.shared.data(from: URL(string: base + "/wrong/film.mkv")!)
    #expect((rejected as? HTTPURLResponse)?.statusCode == 404)
    let (page, _) = try await URLSession.shared.data(from: URL(string: base + "/" + server.token + "/")!)
    #expect(String(decoding: page, as: UTF8.self).contains("A &lt; B"))
    request.httpMethod = "HEAD"
    let (empty, head) = try await URLSession.shared.data(for: request)
    #expect(empty.isEmpty)
    #expect((head as? HTTPURLResponse)?.statusCode == 206)
}
@Test func preparedMovieContainsRealDefaultSubtitleAndPreservesOriginal() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let input = directory.appendingPathComponent("source.mp4"), srt = directory.appendingPathComponent("source.pt.srt"), output = directory.appendingPathComponent("phone.mkv")
    let runner = MediaCommand()
    _ = try runner.run(PhoneMedia.tool("ffmpeg"), ["-nostdin", "-v", "error", "-f", "lavfi", "-i", "color=c=black:s=320x180:d=2", "-c:v", "libx264", input.path])
    try "1\n00:00:00,100 --> 00:00:01,900\nOlá, iPhone!\n".write(to: srt, atomically: true, encoding: .utf8)
    let original = try Data(contentsOf: input)
    try PhoneMedia.prepare(movie: Movie(path: input.path, title: "Teste"), subtitle: srt.path, output: output, runner: runner)
    let extracted = try runner.run(PhoneMedia.tool("ffmpeg"), ["-v", "error", "-i", output.path, "-map", "0:s:0", "-f", "srt", "-"])
    #expect(String(decoding: extracted, as: UTF8.self).contains("Olá, iPhone!"))
    #expect(try Data(contentsOf: input) == original)
    try PhoneMedia.prepare(movie: Movie(path: output.path, title: "Faixa interna"), subtitle: nil, output: directory.appendingPathComponent("internal.mkv"), runner: runner)
    let empty = directory.appendingPathComponent("empty.srt")
    try Data().write(to: empty)
    #expect(throws: (any Error).self) { try PhoneMedia.prepare(movie: Movie(path: input.path, title: "Vazio"), subtitle: empty.path, output: directory.appendingPathComponent("empty.mkv"), runner: runner) }
    #expect(throws: (any Error).self) { try PhoneMedia.prepare(movie: Movie(path: input.path, title: "Sem legendas"), subtitle: nil, output: directory.appendingPathComponent("rejected.mkv"), runner: runner) }
}

@Test func legacyPortugueseSRTIsDecodedBeforeValidation() throws {
    let text = "1\r\n00:00:01,011 --> 00:00:04,074\r\nAssim que se pôs em pé.\r\n"
    let legacy = try #require(text.data(using: .windowsCP1252))
    #expect(try normalizedSRT(legacy).contains("pôs em pé"))
    #expect(try normalizedSRT(Data(text.utf8)).contains("pôs em pé"))
    #expect(try normalizedSRT(try #require(text.data(using: .utf16))).contains("pôs em pé"))
    #expect(throws: (any Error).self) { try normalizedSRT(Data("not a subtitle".utf8)) }
}
