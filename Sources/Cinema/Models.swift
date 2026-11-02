import Foundation

struct Movie: Identifiable, Codable, Hashable {
    var id: String { path }
    var path: String
    var title: String
    var year: String?
    var subtitles: [String] = []
    var metadata: MovieDetails?
    var favorite = false
    var watched = false
    var lastPlayed: Date?
    var addedAt: Date?
    var displayTitle: String { metadata?.title ?? title }
}
struct SearchResult: Decodable { let results: [MovieDetails] }
struct MovieDetails: Codable, Hashable, Identifiable {
    let id: Int
    let title: String
    var original_title: String?
    var overview: String?
    var poster_path: String?
    var backdrop_path: String?
    var release_date: String?
    var vote_average: Double?
    var runtime: Int?
    var genres: [Genre]?
    var credits: Credits?
    struct Genre: Codable, Hashable { let name: String }
    struct Credits: Codable, Hashable {
        let cast: [Person]
        let crew: [Person]
    }
    struct Person: Codable, Hashable { let name: String; var job: String? }
}
func parseFilename(_ filename: String) -> (String, String?) {
    let raw = (filename as NSString).deletingPathExtension
    let expression = try! NSRegularExpression(pattern: #"\b(?:19|20)\d{2}\b"#)
    let maxYear = Calendar.current.component(.year, from: Date()) + 1
    let yearRange = expression.matches(in: raw, range: NSRange(raw.startIndex..., in: raw)).compactMap { Range($0.range, in: raw) }.last { range in
        range.lowerBound != raw.startIndex && (Int(raw[range]) ?? 9999) <= maxYear
    }
    let year = yearRange.map { String(raw[$0]) }
    var title = yearRange.map { String(raw[..<$0.lowerBound]) } ?? raw
    title = title.replacingOccurrences(of: #"(?i)\b(2160p|1080p|720p|480p|bluray|brrip|webrip|web-dl|hdtv|x264|x265|h264|h265|dvdrip)\b.*"#, with: "", options: .regularExpression)
    title = title.replacingOccurrences(of: #"[._\[\]()]+"#, with: " ", options: .regularExpression)
    title = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    return (title.isEmpty ? raw : title, year)
}

// Rank titles independently of TMDB popularity so remakes and sequels stay distinct.
func normalizedTitle(_ value: String) -> String {
    value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .replacingOccurrences(of: "&", with: " and ")
        .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
        .split(separator: " ").joined(separator: " ")
}
func titleSimilarity(_ left: String, _ right: String) -> Double {
    let a = normalizedTitle(left), b = normalizedTitle(right)
    guard !a.isEmpty, !b.isEmpty else { return 0 }
    if a == b { return 1 }
    // Do not confuse sequels (Rocky II / III or Movie 2 / 3).
    let markers: (String) -> [String] = { title in
        title.split(separator: " ").map(String.init).filter {
            $0.allSatisfy(\.isNumber) || ["ii", "iii", "iv", "vi", "vii", "viii", "ix"].contains($0)
        }
    }
    guard markers(a) == markers(b) else { return 0 }
    let x = Array(a), y = Array(b)
    var previous = Array(0...y.count)
    for (i, character) in x.enumerated() {
        var row = [i + 1] + Array(repeating: 0, count: y.count)
        for j in y.indices { row[j + 1] = min(row[j] + 1, previous[j + 1] + 1, previous[j] + (character == y[j] ? 0 : 1)) }
        previous = row
    }
    let editScore = 1 - Double(previous[y.count]) / Double(max(x.count, y.count))
    let wordsA = Set(a.split(separator: " ")), wordsB = Set(b.split(separator: " "))
    let tokenScore = Double(wordsA.intersection(wordsB).count) / Double(wordsA.union(wordsB).count)
    return max(editScore, tokenScore)
}
func automaticMatch(title: String, year: String?, candidates: [MovieDetails]) -> MovieDetails? {
    var seen = Set<Int>()
    let ranked = candidates.filter { seen.insert($0.id).inserted }.map { candidate -> (MovieDetails, Double) in
        let similarity = max(titleSimilarity(title, candidate.title), titleSimilarity(title, candidate.original_title ?? ""))
        let candidateYear = candidate.release_date.flatMap { Int($0.prefix(4)) }
        if let expected = year.flatMap(Int.init), let actual = candidateYear {
            let distance = abs(expected - actual)
            if distance > 1 { return (candidate, 0) }
            return (candidate, similarity - (distance == 1 ? 0.04 : 0))
        }
        return (candidate, similarity)
    }.sorted { $0.1 > $1.1 }
    guard let best = ranked.first else { return nil }
    let hasYear = year != nil && best.0.release_date.flatMap { Int($0.prefix(4)) } != nil
    let threshold = hasYear ? 0.88 : 0.98
    guard best.1 >= threshold else { return nil }
    if ranked.count > 1 && best.1 - ranked[1].1 < 0.07 { return nil }
    return best.0
}

// macOS can return /private/var for a folder selected through /var (and vice versa).
func mediaPathKey(_ path: String) -> String {
    let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
    for alias in ["/var", "/tmp", "/etc"] where standardized == alias || standardized.hasPrefix(alias + "/") { return "/private" + standardized }
    return standardized
}

func refreshedMetadata(_ fresh: MovieDetails, preserving old: MovieDetails?) -> MovieDetails {
    guard let old, old.id == fresh.id else { return fresh }
    var result = fresh
    if fresh.poster_path?.isEmpty != false { result.poster_path = old.poster_path }
    if fresh.backdrop_path?.isEmpty != false { result.backdrop_path = old.backdrop_path }
    if fresh.overview?.isEmpty != false { result.overview = old.overview }
    if fresh.release_date?.isEmpty != false { result.release_date = old.release_date }
    if fresh.original_title?.isEmpty != false { result.original_title = old.original_title }
    if (fresh.runtime ?? 0) == 0 { result.runtime = old.runtime }
    if fresh.vote_average == nil { result.vote_average = old.vote_average }
    if fresh.genres?.isEmpty != false { result.genres = old.genres }
    if let credits = fresh.credits, let prior = old.credits {
        result.credits = .init(cast: credits.cast.isEmpty ? prior.cast : credits.cast, crew: credits.crew.isEmpty ? prior.crew : credits.crew)
    } else if fresh.credits == nil { result.credits = old.credits }
    return result
}

struct MovieCollection: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var moviePaths: Set<String> = []
}

func moviesByImportDate(_ movies: [Movie]) -> [Movie] {
    movies.sorted {
        if $0.addedAt != $1.addedAt { return ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
        return $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending
    }
}

func movieMatchesQuery(_ movie: Movie, query: String) -> Bool {
    let tokens = normalizedTitle(query).split(separator: " ")
    guard !tokens.isEmpty else { return true }
    let director = movie.metadata?.credits?.crew.filter { $0.job == "Director" }.map(\.name).joined(separator: " ") ?? ""
    let text = normalizedTitle([movie.displayTitle, movie.title, movie.metadata?.original_title ?? "", movie.year ?? "", movie.metadata?.genres?.map(\.name).joined(separator: " ") ?? "", director, URL(fileURLWithPath: movie.path).lastPathComponent].joined(separator: " "))
    return tokens.allSatisfy { text.contains($0) }
}
