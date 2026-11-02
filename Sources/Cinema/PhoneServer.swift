import Foundation
@preconcurrency import Network
import Darwin

struct HTTPByteRange: Equatable {
    var start: Int64; var end: Int64
    static func parse(_ value: String, size: Int64) -> HTTPByteRange? {
        guard size > 0, value.hasPrefix("bytes="), !value.contains(",") else { return nil }
        let parts = value.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        if parts[0].isEmpty {
            guard let suffix = Int64(parts[1]), suffix > 0 else { return nil }
            return .init(start: max(0, size - suffix), end: size - 1)
        }
        guard let start = Int64(parts[0]), start >= 0, start < size else { return nil }
        let end: Int64
        if parts[1].isEmpty { end = size - 1 } else { guard let parsed = Int64(parts[1]), parsed >= start else { return nil }; end = min(parsed, size - 1) }
        return .init(start: start, end: end)
    }
}
final class PhoneServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Cinema.PhoneServer")
    private let listener: NWListener
    private let file: URL
    private let title: String
    private let router: (@Sendable (LocalRequest) async -> LocalResponse)?
    private let expiresAfter: Double?
    let token: String
    private var connections: [UUID: NWConnection] = [:]
    private var stopped = false
    private var resolved = false
    private var awaitingHeaders = Set<UUID>()
    init(file: URL, title: String) throws {
        self.file = file; self.title = title; router = nil; expiresAfter = 7200
        token = UUID().uuidString + UUID().uuidString
        listener = try NWListener(using: .tcp, on: .any)
    }
    init(token: String, port: UInt16 = 0, router: @escaping @Sendable (LocalRequest) async -> LocalResponse) throws {
        file = URL(fileURLWithPath: "/dev/null"); title = "Cinema"; self.token = token; self.router = router; expiresAfter = nil
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port) ?? .any)
    }
    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !self.resolved else { return }; self.resolved = true
                    if let port = self.listener.port { continuation.resume(returning: port.rawValue) } else { continuation.resume(throwing: phoneError("Não foi possível abrir uma porta de rede.")) }
                case .failed(let error):
                    guard !self.resolved else { return }; self.resolved = true; continuation.resume(throwing: error)
                case .cancelled:
                    self.listener.newConnectionHandler = nil
                    self.listener.stateUpdateHandler = nil
                    guard !self.resolved else { return }; self.resolved = true; continuation.resume(throwing: CancellationError())
                default: break
                }
            }
            listener.newConnectionHandler = { connection in self.accept(connection) }
            listener.start(queue: queue)
            if let expiresAfter { queue.asyncAfter(deadline: .now() + expiresAfter) { self.stopOnQueue() } }
        }
    }
    func stop() { queue.async { self.stopOnQueue() } }
    private func stopOnQueue() {
        stopped = true; listener.cancel()
        for connection in connections.values { connection.cancel() }; connections.removeAll()
    }
    private func accept(_ connection: NWConnection) {
        guard !stopped, connections.count < 24 else { connection.cancel(); return }
        if case let .hostPort(host, _) = connection.endpoint {
            guard Self.isPrivate(String(describing: host)) else { connection.cancel(); return }
        } else { connection.cancel(); return }
        let id = UUID(); connections[id] = connection; awaitingHeaders.insert(id)
        connection.stateUpdateHandler = { state in
            if case .cancelled = state { self.connections.removeValue(forKey: id); self.awaitingHeaders.remove(id) }
            if case .failed = state { self.connections.removeValue(forKey: id); self.awaitingHeaders.remove(id); connection.cancel() }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 30) { if self.awaitingHeaders.contains(id) { connection.cancel() } }
        receive(connection, buffer: Data())
    }
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, complete, error in
            var bytes = buffer; if let data { bytes.append(data) }
            guard bytes.count <= 196608, error == nil else { connection.cancel(); return }
            if let end = bytes.range(of: Data("\r\n\r\n".utf8)) {
                guard end.lowerBound <= 16384 else { connection.cancel(); return }
                let header = String(decoding: bytes[..<end.lowerBound], as: UTF8.self)
                let lengths = header.components(separatedBy: "\r\n").dropFirst().filter { $0.lowercased().hasPrefix("content-length:") }
                guard lengths.count <= 1, !header.lowercased().contains("transfer-encoding:") else { connection.cancel(); return }
                let length = lengths.first.flatMap { Int($0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "") } ?? 0
                guard length >= 0, length <= 131072 else { connection.cancel(); return }
                if bytes.count < end.upperBound + length {
                    if complete { connection.cancel() } else { self.receive(connection, buffer: bytes) }; return
                }
                if let id = self.connections.first(where: { $0.value === connection })?.key { self.awaitingHeaders.remove(id) }
                self.respond(connection, header: header, body: bytes.subdata(in: end.upperBound..<(end.upperBound + length)))
            } else if complete { connection.cancel() } else { self.receive(connection, buffer: bytes) }
        }
    }
    private func respond(_ connection: NWConnection, header: String, body: Data) {
        let lines = header.components(separatedBy: "\r\n")
        let first = (lines.first ?? "").split(separator: " ")
        guard first.count == 3, ["GET", "HEAD", "POST"].contains(String(first[0])) else { simple(connection, status: "405 Method Not Allowed", body: ""); return }
        let path = String(first[1]), head = first[0] == "HEAD"
        let base = "/" + token
        if let router {
            guard path == base || path.hasPrefix(base + "/") else { simple(connection, status: "404 Not Found", body: ""); return }
            let headers = Dictionary(headerLines: Array(lines.dropFirst()))
            if first[0] == "POST" {
                guard headers["x-cinema-action"] == "1" else { simple(connection, status: "403 Forbidden", body: ""); return }
                if let origin = headers["origin"], let host = headers["host"], origin != "http://" + host { simple(connection, status: "403 Forbidden", body: ""); return }
            }
            let request = LocalRequest(method: String(first[0]), path: String(path.dropFirst(base.count)).components(separatedBy: "?")[0], headers: headers, body: body)
            Task {
                let response = await router(request)
                self.queue.async {
                    guard !self.stopped else { connection.cancel(); return }
                    switch response {
                    case let .data(bytes, mime, status): self.respondData(connection, bytes: bytes, mime: mime, status: status, head: head)
                    case let .file(url, mime): self.serveFile(connection, url: url, mime: mime, head: head, lines: lines)
                    }
                }
            }
            return
        }
        guard first[0] != "POST" else { simple(connection, status: "405 Method Not Allowed", body: ""); return }
        guard path == base || path == base + "/" || path == base + "/film.mkv" else { simple(connection, status: "404 Not Found", body: ""); return }
        if path != base + "/film.mkv" {
            let escaped = title.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            let body = """
            <!doctype html><html lang="pt"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Cinema</title>
            <style>body{background:#101217;color:#fff;font:17px -apple-system,sans-serif;max-width:540px;margin:70px auto;padding:24px}h1{font-size:36px}a{display:block;background:#ffb348;color:#17120b;padding:18px;border-radius:16px;text-decoration:none;margin:18px 0;font-weight:700}.secondary{background:#282d36;color:white}p{line-height:1.6;color:#bfc3cd}</style>
            <h1>\(escaped)</h1><p>Legendas incluídas no vídeo e marcadas como predefinidas.</p><a id="play">▶ Abrir no VLC</a><a id="download" class="secondary">↓ Guardar no VLC para ver offline</a><a class="secondary" href="\(base)/film.mkv">Descarregar ficheiro MKV</a><p>Instala o VLC no iPhone. Mantém o Mac ligado e esta partilha aberta. Se o VLC tiver desativado as legendas nas preferências, seleciona a faixa “Legendas Cinema”.</p>
            <script>const u=location.origin+'\(base)/film.mkv';document.getElementById('play').href='vlc-x-callback://x-callback-url/stream?url='+encodeURIComponent(u);document.getElementById('download').href='vlc-x-callback://x-callback-url/download?url='+encodeURIComponent(u)+'&filename=Cinema.mkv';</script></html>
            """
            simple(connection, status: "200 OK", body: body, head: head); return
        }
        serveFile(connection, url: file, mime: "video/x-matroska", head: head, lines: lines)
    }
    private func serveFile(_ connection: NWConnection, url: URL, mime: String, head: Bool, lines: [String]) {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            let size = try handle.seekToEnd()
            guard size > 0, size <= UInt64(Int64.max) else { try? handle.close(); throw phoneError("Ficheiro vazio") }
            let rangeValue = lines.dropFirst().first(where: { $0.lowercased().hasPrefix("range:") }).map { String($0.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)[1]).trimmingCharacters(in: .whitespaces) }
            let range: HTTPByteRange
            if let rangeValue {
                guard let valid = HTTPByteRange.parse(rangeValue, size: Int64(size)) else {
                    try? handle.close()
                    send(connection, data: Data("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */\(size)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)); return
                }; range = valid
            } else { range = .init(start: 0, end: Int64(size) - 1) }
            try handle.seek(toOffset: UInt64(range.start))
            let count = range.end - range.start + 1
            var response = "HTTP/1.1 \(rangeValue == nil ? "200 OK" : "206 Partial Content")\r\nContent-Type: \(mime)\r\nAccept-Ranges: bytes\r\nContent-Length: \(count)\r\nCache-Control: no-store\r\nConnection: close\r\n"
            if rangeValue != nil { response += "Content-Range: bytes \(range.start)-\(range.end)/\(size)\r\n" }; response += "\r\n"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { error in
                if error != nil || head { try? handle.close(); connection.cancel() } else { self.stream(connection, handle: handle, remaining: count) }
            })
        } catch { simple(connection, status: "500 Internal Server Error", body: "Vídeo indisponível") }
    }
    private func stream(_ connection: NWConnection, handle: FileHandle, remaining: Int64) {
        guard remaining > 0 else { try? handle.close(); connection.cancel(); return }
        do {
            guard let data = try handle.read(upToCount: Int(min(remaining, 262144))), !data.isEmpty else { try? handle.close(); connection.cancel(); return }
            connection.send(content: data, completion: .contentProcessed { error in
                if error != nil { try? handle.close(); connection.cancel() } else { self.stream(connection, handle: handle, remaining: remaining - Int64(data.count)) }
            })
        } catch { try? handle.close(); connection.cancel() }
    }
    private func respondData(_ connection: NWConnection, bytes: Data, mime: String, status: String, head: Bool) {
        var data = Data("HTTP/1.1 \(status)\r\nContent-Type: \(mime)\r\nContent-Length: \(bytes.count)\r\nCache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n".utf8)
        if !head { data.append(bytes) }; send(connection, data: data)
    }
    private func simple(_ connection: NWConnection, status: String, body: String, head: Bool = false) {
        let bytes = Data(body.utf8)
        var data = Data("HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(bytes.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".utf8)
        if !head { data.append(bytes) }; send(connection, data: data)
    }
    private func send(_ connection: NWConnection, data: Data) { connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() }) }
    static func isPrivate(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 { return parts[0] == 10 || parts[0] == 127 || (parts[0] == 192 && parts[1] == 168) || (parts[0] == 172 && (16...31).contains(parts[1])) }
        return host == "::1" || host.hasPrefix("fe80:") || host.hasPrefix("fd") || host.hasPrefix("fc")
    }
    static func addresses() -> [String] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0 else { return [] }; defer { freeifaddrs(pointer) }
        var result: [(String, String)] = []; var cursor = pointer
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            guard let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET), (entry.pointee.ifa_flags & UInt32(IFF_UP)) != 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self), name = String(cString: entry.pointee.ifa_name)
                if isPrivate(ip), !ip.hasPrefix("127.") { result.append((name, ip)) }
            }
        }
        return result.sorted { ($0.0.hasPrefix("en") ? 0 : 1, $0.0) < ($1.0.hasPrefix("en") ? 0 : 1, $1.0) }.map(\.1)
    }
}

private extension Dictionary where Key == String, Value == String {
    init(headerLines: [String]) {
        self.init()
        for line in headerLines {
            let fields = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if fields.count == 2 { self[String(fields[0]).lowercased()] = String(fields[1]).trimmingCharacters(in: .whitespaces) }
        }
    }
}
