import Foundation

final class MediaCommand: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; let active = process; lock.unlock(); if let active, active.isRunning { active.terminate() } }
    func run(_ executable: String, _ args: [String], onLine: (@Sendable (String) -> Void)? = nil) throws -> Data {
        let process = Process(), output = Pipe()
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaCommand-" + UUID().uuidString)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let errors = try FileHandle(forWritingTo: log)
        defer { try? errors.close(); try? FileManager.default.removeItem(at: log) }
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = args
        process.standardOutput = output; process.standardError = errors
        lock.lock()
        if cancelled { lock.unlock(); throw CancellationError() }
        self.process = process
        do { try process.run() } catch { lock.unlock(); throw error }
        lock.unlock()
        var data = Data()
        if let onLine {
            var pending = Data()
            while let chunk = try output.fileHandleForReading.read(upToCount: 4096), !chunk.isEmpty {
                data.append(chunk); pending.append(chunk)
                while let newline = pending.firstIndex(of: 10) {
                    onLine(String(decoding: pending[..<newline], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
                    pending.removeSubrange(...newline)
                }
            }
            if !pending.isEmpty { onLine(String(decoding: pending, as: UTF8.self)) }
        } else { data = output.fileHandleForReading.readDataToEndOfFile() }
        process.waitUntilExit()
        let errorData = (try? Data(contentsOf: log)) ?? Data()
        guard process.terminationStatus == 0 else {
            throw phoneError("Não foi possível preparar o vídeo. \(String(data: errorData.suffix(1500), encoding: .utf8) ?? "Verifica o ficheiro e as legendas.")")
        }
        return data
    }
}
func phoneError(_ text: String) -> NSError { NSError(domain: "CinemaPhone", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
struct PhoneProbe: Decodable {
    var streams: [Stream]
    var format: Format?
    struct Format: Decodable { var duration: String? }
    struct Stream: Decodable { var codec_type: String?; var codec_name: String?; var disposition: [String: Int]?; var nb_read_packets: String? }
}
enum PhoneMedia {
    static func tool(_ name: String) throws -> String {
        for root in ["/opt/homebrew/bin", "/usr/local/bin"] {
            let path = root + "/" + name
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        throw phoneError("É necessário instalar FFmpeg (ffmpeg e ffprobe) neste Mac para preparar vídeo com legendas.")
    }
    static func prepare(movie: Movie, subtitle: String?, output: URL, runner: MediaCommand, progress: @escaping @Sendable (PreparationProgress) -> Void = { _ in }) throws {
        let reporter = PreparationReporter(callback: progress)
        reporter.emit(1, stage: "A analisar o vídeo…")
        let ffmpeg = try tool("ffmpeg"), ffprobe = try tool("ffprobe")
        guard FileManager.default.fileExists(atPath: movie.path) else { throw phoneError("O vídeo está indisponível. Liga o disco dos filmes.") }
        let inputSize = ((try? FileManager.default.attributesOfItem(atPath: movie.path)[.size]) as? NSNumber)?.int64Value ?? 0
        if let free = try? output.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage, free < inputSize + 64 * 1024 * 1024 { throw phoneError("Não há espaço livre suficiente para criar a cópia temporária com legendas.") }
        let input = try JSONDecoder().decode(PhoneProbe.self, from: runner.run(ffprobe, ["-v", "error", "-show_streams", "-show_format", "-of", "json", movie.path]))
        let duration = input.format?.duration.flatMap(Double.init)
        reporter.emit(2, stage: "A incluir as legendas…")
        var args = ["-progress", "pipe:1", "-nostats", "-stats_period", "0.25", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", movie.path]
        if let subtitle {
            guard FileManager.default.fileExists(atPath: subtitle) else { throw phoneError("A legenda selecionada não está disponível.") }
            let raw = try Data(contentsOf: URL(fileURLWithPath: subtitle))
            let text = try normalizedSRT(raw)
            let normalized = output.deletingLastPathComponent().appendingPathComponent("legendas.srt")
            try text.write(to: normalized, atomically: true, encoding: .utf8)
            args += ["-i", normalized.path, "-map", "0:v:0", "-map", "0:a?", "-map", "1:s:0", "-c:v", "copy", "-c:a", "copy", "-c:s", "srt"]
        } else {
            guard input.streams.contains(where: { $0.codec_type == "subtitle" }) else { throw phoneError("Não há legendas neste vídeo. Adiciona um SRT ou escolhe uma faixa interna antes de partilhar.") }
            args += ["-map", "0:v:0", "-map", "0:a?", "-map", "0:s:0", "-c", "copy"]
        }
        args += ["-disposition:s:0", "default+forced", "-metadata:s:s:0", "title=Legendas Cinema", "-f", "matroska", output.path]
        _ = try runner.run(ffmpeg, args) { line in
            if let percent = remuxProgress(line, duration: duration) { reporter.emit(percent, stage: "A incluir as legendas…") }
        }
        reporter.emit(85, stage: "A verificar as faixas…")
        let verified = try JSONDecoder().decode(PhoneProbe.self, from: runner.run(ffprobe, ["-v", "error", "-show_streams", "-of", "json", output.path]))
        guard verified.streams.contains(where: { $0.codec_type == "video" }), verified.streams.contains(where: { $0.codec_type == "subtitle" && $0.disposition?["default"] == 1 }) else {
            throw phoneError("A verificação das legendas falhou. A ligação não foi disponibilizada.")
        }
        reporter.emit(86, stage: "A verificar os eventos de legenda…")
        let packets = try runner.run(ffprobe, ["-v", "error", "-select_streams", "s", "-show_packets", "-show_entries", "packet=pts_time", "-of", "csv=p=0", output.path]) { line in
            if let timestamp = Double(line), timestamp.isFinite, let duration, duration > 0 {
                reporter.emit(86 + min(1, max(0, timestamp / duration)) * 13, stage: "A verificar os eventos de legenda…")
            }
        }
        guard String(decoding: packets, as: UTF8.self).split(whereSeparator: \.isNewline).contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { throw phoneError("Não foram encontrados eventos de legenda na cópia. A partilha foi bloqueada.") }
        reporter.emit(100, stage: "Legendas verificadas. Pronto para reproduzir.")

    }
}

func normalizedSRT(_ data: Data) throws -> String {
    let pattern = #"(?m)^\s*\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}\s*-->\s*\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}"#
    // A legacy single-byte file can decode as meaningless UTF-16 without returning nil.
    // Validate every candidate before accepting it, and only try UTF-16 for BOM/NUL data.
    var encodings: [String.Encoding] = [.utf8]
    if data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff]) || data.contains(0) {
        encodings += [.utf16, .utf16LittleEndian, .utf16BigEndian]
    }
    encodings += [.windowsCP1252, .isoLatin1]
    for encoding in encodings {
        guard let decoded = String(data: data, encoding: encoding) else { continue }
        let text = decoded.replacingOccurrences(of: "\u{feff}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if text.range(of: pattern, options: .regularExpression) != nil { return text }
    }
    throw phoneError("Não foi possível interpretar esta legenda SRT. O ficheiro pode estar vazio ou usar outro formato.")
}
