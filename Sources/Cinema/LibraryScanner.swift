import Foundation

struct LibraryScan: Sendable {
    var movies: [Movie] = []
    var failures: [String] = []
    var fingerprints: [String: MediaFingerprint] = [:]
}
enum LibraryScanner {
    static func scan(_ roots: [String]) -> LibraryScan {
        let manager = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let extensions: Set<String> = ["mkv", "mp4", "avi", "mov", "m4v", "webm"]
        var result = LibraryScan()
        var seen = Set<String>()
        for root in roots {
            guard manager.fileExists(atPath: root) else { result.failures.append(root); continue }
            guard let iterator = manager.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { result.failures.append(root); continue }
            var videos: [(URL, URLResourceValues)] = []
            var captions: [String: [(URL, URLResourceValues)]] = [:]
            while let url = iterator.nextObject() as? URL {
                let ext = url.pathExtension.lowercased()
                guard extensions.contains(ext) || ext == "srt", let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
                if ext == "srt" { captions[mediaPathKey(url.deletingLastPathComponent().path), default: []].append((url, values)) }
                else { videos.append((url, values)) }
            }
            for (url, values) in videos {
                let key = mediaPathKey(url.path)
                guard seen.insert(key).inserted else { continue }
                let (title, year) = parseFilename(url.lastPathComponent)
                let stem = url.deletingPathExtension().lastPathComponent.lowercased()
                let matches = (captions[mediaPathKey(url.deletingLastPathComponent().path)] ?? []).filter {
                    let base = $0.0.deletingPathExtension().lastPathComponent.lowercased()
                    return base == stem || base.hasPrefix(stem + ".")
                }.sorted { $0.0.path < $1.0.path }
                if let size = values.fileSize, let modified = values.contentModificationDate {
                    let signature = matches.map { "\($0.0.path)|\($0.1.fileSize ?? 0)|\($0.1.contentModificationDate?.timeIntervalSince1970 ?? 0)" }.joined(separator: "\n")
                    result.fingerprints[key] = .init(size: Int64(size), modified: modified, subtitles: signature)
                }
                result.movies.append(Movie(path: url.path, title: title, year: year, subtitles: matches.map { $0.0.path }))
            }
        }
        return result
    }
}
