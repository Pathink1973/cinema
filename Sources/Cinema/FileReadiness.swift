import Foundation

struct MediaFingerprint: Equatable, Sendable {
    var size: Int64
    var modified: Date
    var subtitles: String = ""
}
struct FileReadiness {
    private var observations: [String: (MediaFingerprint, Date)] = [:]
    mutating func ready(path: String, fingerprint: MediaFingerprint, now: Date = Date()) -> Bool {
        guard fingerprint.size > 0 else { observations.removeValue(forKey: path); return false }
        guard let prior = observations[path], prior.0 == fingerprint else {
            observations[path] = (fingerprint, now)
            return false
        }
        return now.timeIntervalSince(prior.1) >= 10
    }
    mutating func retain(_ paths: Set<String>) { observations = observations.filter { paths.contains($0.key) } }
}
