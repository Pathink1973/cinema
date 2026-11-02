import AppKit
import SwiftUI
import Security
import LocalAuthentication

@MainActor final class Library: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var folders: [String] = []
    @Published var excludedMovies: [Movie] = []
    @Published var collections: [MovieCollection] = []
    @Published var busy = false
    @Published var isScanning = false
    @Published var message: String?
    @Published var newMovieIDs: [String] = []
    @Published var activityNotice: String?
    private var readiness = FileReadiness()
    private var monitoring = false
    private var watcher: FolderChangeWatcher?
    private var watchedFolders: [String] = []
    private var scanDebounce: Task<Void, Never>?
    private var pendingStableFiles = false
    private var scanQueued = false
    private var manualScanQueued = false
    private var lastScan = Date.distantPast
    lazy var webCatalog = WebCatalog(library: self)
    private let tokenSession = TokenSession()
    private let enrichNewMovies: Bool
    private let directory: URL
    private var database: URL { directory.appendingPathComponent("library.json") }
    struct Saved: Codable { var movies: [Movie]; var folders: [String]; var excludedMovies: [Movie]?; var collections: [MovieCollection]? }
    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("CinemaMac"), enrichNewMovies: Bool = true) {
        self.enrichNewMovies = enrichNewMovies
        self.directory = directory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: database.path) {
                let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: database))
                collections = saved.collections ?? []
                excludedMovies = saved.excludedMovies ?? []
                let excluded = Set(excludedMovies.map { mediaPathKey($0.path) })
                movies = saved.movies.filter { !excluded.contains(mediaPathKey($0.path)) }; folders = saved.folders
            }
        } catch { message = "Não foi possível ler a biblioteca: \(error.localizedDescription)" }
    }
    func save() {
        do { try JSONEncoder().encode(Saved(movies: movies, folders: folders, excludedMovies: excludedMovies, collections: collections)).write(to: database, options: .atomic) }
        catch { message = "Não foi possível guardar: \(error.localizedDescription)" }
    }
    @discardableResult func createCollection(_ name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = collections.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) { return existing.id }
        let collection = MovieCollection(name: trimmed)
        collections.append(collection); save(); return collection.id
    }
    func setCollectionMembers(_ id: UUID, paths: Set<String>) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].moviePaths = Set(paths.map(mediaPathKey)); save()
    }
    func setMembership(_ path: String, in id: UUID, included: Bool) {
        guard let collection = collections.first(where: { $0.id == id }) else { return }
        var paths = collection.moviePaths
        if included { paths.insert(mediaPathKey(path)) } else { paths.remove(mediaPathKey(path)) }
        setCollectionMembers(id, paths: paths)
    }
    func deleteCollection(_ id: UUID) { collections.removeAll { $0.id == id }; save() }
    func update(_ movie: Movie) { if let i = movies.firstIndex(where: { $0.id == movie.id }) { movies[i] = movie; save() } }
    func exclude(_ movie: Movie) {
        guard let current = movies.first(where: { $0.id == movie.id }) else { return }
        if !excludedMovies.contains(where: { $0.id == current.id }) { excludedMovies.append(current) }
        movies.removeAll { $0.id == current.id }
        newMovieIDs.removeAll { $0 == current.id }
        save()
    }
    func restore(_ movie: Movie) {
        guard let current = excludedMovies.first(where: { $0.id == movie.id }) else { return }
        excludedMovies.removeAll { $0.id == current.id }
        if !movies.contains(where: { $0.id == current.id }) { movies.append(current) }
        movies.sort { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
        save()
    }
    func addFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            addFolders(panel.urls)
        }
    }
    @discardableResult func addFolders(_ urls: [URL]) -> Bool {
        let directories = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        guard !directories.isEmpty else { return false }
        for url in directories where !folders.contains(where: { mediaPathKey($0) == mediaPathKey(url.path) }) { folders.append(url.path) }
        save()
        activityNotice = "A verificar novos vídeos. Os ficheiros serão adicionados depois de estabilizarem."
        scan(automatic: true)
        return true
    }
    func volumesChanged() {
        watcher?.stop(); watcher = nil; watchedFolders = []
        scan(automatic: true)
    }
    private func updateWatcher() {
        guard folders != watchedFolders else { return }
        watcher?.stop(); watchedFolders = folders
        watcher = FolderChangeWatcher(paths: folders) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.scanDebounce?.cancel()
                self.scanDebounce = Task { [weak self] in
                    do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
                    self?.scan(automatic: true)
                }
            }
        }
    }
    func monitorFolders() async {
        guard !monitoring else { return }
        monitoring = true
        updateWatcher()
        if !folders.isEmpty { scan(automatic: true) }
        defer { monitoring = false; watcher?.stop(); watcher = nil; watchedFolders = []; scanDebounce?.cancel() }
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(15)) } catch { break }
            updateWatcher()
            // Events trigger scans promptly. Poll only for copying files and as a
            // fallback for remounted disks / shares that do not report FSEvents.
            if !folders.isEmpty && (pendingStableFiles || Date().timeIntervalSince(lastScan) >= 120) { scan(automatic: true) }
        }
    }
    func scan(automatic: Bool = false) {
        if isScanning { scanQueued = true; if !automatic { manualScanQueued = true }; return }
        isScanning = true
        updateWatcher()
        let roots = folders
        Task {
            let result = await Task.detached(priority: .userInitiated) { LibraryScanner.scan(roots) }.value
            let excluded = Set(excludedMovies.map { mediaPathKey($0.path) })
            var byPath = Dictionary(uniqueKeysWithValues: movies.filter { !excluded.contains(mediaPathKey($0.path)) }.map { (mediaPathKey($0.path), $0) })
            var added: [Movie] = []
            var waiting = 0
            readiness.retain(Set(result.fingerprints.keys))
            let currentRoots = folders.map { mediaPathKey($0) }
            for var movie in result.movies where !excluded.contains(mediaPathKey(movie.path)) {
                guard currentRoots.contains(where: { mediaPathKey(movie.path).hasPrefix($0 == "/" ? "/" : $0 + "/") }) else { continue }
                if let old = byPath[mediaPathKey(movie.path)] { movie.metadata = old.metadata; movie.favorite = old.favorite; movie.watched = old.watched; movie.lastPlayed = old.lastPlayed; movie.addedAt = old.addedAt }
                else {
                    guard let fingerprint = result.fingerprints[mediaPathKey(movie.path)], readiness.ready(path: mediaPathKey(movie.path), fingerprint: fingerprint) else { waiting += 1; continue }
                    movie.addedAt = Date()
                    added.append(movie)
                }
                byPath[mediaPathKey(movie.path)] = movie
            }
            let merged = byPath.values.sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
            if merged != movies { movies = merged; save() }
            for movie in added where !newMovieIDs.contains(movie.id) { newMovieIDs.append(movie.id) }
            if !added.isEmpty { activityNotice = nil }
            else if waiting > 0 {
                activityNotice = "A aguardar que \(waiting) vídeo(s) estabilizem antes de importar…"
            } else if activityNotice?.hasPrefix("A aguardar") == true || activityNotice?.hasPrefix("A verificar") == true { activityNotice = nil }
            pendingStableFiles = waiting > 0
            lastScan = Date()
            isScanning = false
            if !automatic {
                if waiting > 0 { activityNotice = "A aguardar que \(waiting) vídeo(s) estabilizem. A verificação continua automaticamente." }
                else if !result.failures.isEmpty { activityNotice = "Algumas pastas estão indisponíveis. A biblioteca foi preservada." }
                else if added.isEmpty { activityNotice = "Biblioteca atualizada. Sem novos vídeos." }
            }
            if scanQueued {
                let nextAutomatic = !manualScanQueued
                scanQueued = false; manualScanQueued = false
                scan(automatic: nextAutomatic)
            }
            if !added.isEmpty, enrichNewMovies, !busy, !token.isEmpty {
                busy = true
                for movie in added {
                    do { _ = try await repair(movie) }
                    catch { activityNotice = "Os vídeos foram adicionados. Alguns dados do TMDB não foram obtidos; podes tentar pela ficha."; break }
                }
                busy = false
            }
        }
    }
    func play(_ movie: Movie, subtitle: String?) {
        guard FileManager.default.fileExists(atPath: movie.path) else { message = "Ficheiro indisponível. Liga o disco ou a pasta de rede."; return }
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.videolan.vlc") else { message = "Instala o VLC em videolan.org para reproduzir os filmes."; return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--fullscreen"] + (subtitle.map { ["--sub-file", $0] } ?? []) + [movie.path]
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: app, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error { self.message = "Não foi possível abrir o VLC: \(error.localizedDescription)" }
                else { var updated = movie; updated.lastPlayed = Date(); self.update(updated) }
            }
        }
    }
    func search(_ query: String, year: String? = nil) async throws -> [MovieDetails] {
        var parameters = [URLQueryItem(name: "query", value: query)]
        if let year { parameters.append(URLQueryItem(name: "year", value: year)) }
        let result: SearchResult = try await request("search/movie", parameters: parameters)
        return result.results
    }
    func identify(_ movie: Movie, result: MovieDetails) async throws {
        let detail: MovieDetails = try await request("movie/\(result.id)", parameters: [.init(name: "append_to_response", value: "credits")])
        var updated = movies.first(where: { $0.id == movie.id }) ?? movie
        updated.metadata = refreshedMetadata(detail, preserving: updated.metadata); update(updated)
    }
    // nil means the known or confidently matched film was refreshed.
    // Otherwise return candidates for the person to choose, without guessing.
    func repair(_ movie: Movie) async throws -> [MovieDetails]? {
        let current = movies.first(where: { $0.id == movie.id }) ?? movie
        if let metadata = current.metadata {
            try await identify(current, result: metadata)
            return nil
        }
        let (title, year) = parseFilename(URL(fileURLWithPath: current.path).lastPathComponent)
        var candidates = try await search(title, year: year)
        var match = automaticMatch(title: title, year: year, candidates: candidates)
        if match == nil, year != nil {
            candidates += try await search(title)
            match = automaticMatch(title: title, year: year, candidates: candidates)
        }
        if let match { try await identify(current, result: match); return nil }
        var seen = Set<Int>()
        return candidates.filter { seen.insert($0.id).inserted }
    }
    func enrich() {
        guard !busy else { return }
        guard !token.isEmpty else { message = "Token indisponível. Cola o token de leitura do TMDB nas Definições e guarda-o novamente. Não introduzas a palavra-passe do Mac."; return }
        busy = true
        Task {
            var pending = 0
            var identified = 0
            for movie in movies where movie.metadata == nil {
                do {
                    // Reparse unresolved filenames with the current filename rules.
                    let (title, year) = parseFilename(URL(fileURLWithPath: movie.path).lastPathComponent)
                    var results = try await search(title, year: year)
                    var match = automaticMatch(title: title, year: year, candidates: results)
                    if match == nil, year != nil {
                        // Release years can differ by country; retain year scoring on the broader results.
                        results += try await search(title)
                        match = automaticMatch(title: title, year: year, candidates: results)
                    }
                    if let match { try await identify(movie, result: match); identified += 1 } else { pending += 1 }
                } catch { message = error.localizedDescription; busy = false; return }
            }
            busy = false; message = pending == 0 ? "Pesquisa concluída. \(identified) filmes identificados automaticamente." : "\(identified) filmes identificados automaticamente. \(pending) continuam ambíguos ou sem resultados; usa Identificar… nesses filmes."
        }
    }
    private func request<T: Decodable>(_ path: String, parameters: [URLQueryItem]) async throws -> T {
        guard !token.isEmpty else { throw NSError(domain: "Cinema", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token indisponível. Cola o token de leitura do TMDB nas Definições e guarda-o novamente. Não introduzas a palavra-passe do Mac."]) }
        var components = URLComponents(string: "https://api.themoviedb.org/3/" + path)!
        components.queryItems = parameters + [.init(name: "language", value: "pt-PT")]
        var request = URLRequest(url: components.url!); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw NSError(domain: "Cinema", code: 2, userInfo: [NSLocalizedDescriptionKey: "O TMDB recusou o pedido. Verifica o token e a ligação à internet."]) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    var token: String {
        tokenSession.value { readTokenFromKeychain() }
    }
    private func readTokenFromKeychain() -> String {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CinemaMac.TMDB", kSecAttrAccount as String: "read-token", kSecReturnData as String: true, kSecUseAuthenticationContext as String: context]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    func setToken(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { message = "Cola o token de leitura do TMDB antes de guardar."; return }
        tokenSession.store(cleaned)
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CinemaMac.TMDB", kSecAttrAccount as String: "read-token", kSecUseAuthenticationContext as String: context]
        let data = Data(cleaned.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound { var addition = query; addition[kSecValueData as String] = data; status = SecItemAdd(addition as CFDictionary, nil) }
        if status == errSecSuccess { tokenSession.store(String(data: data, encoding: .utf8) ?? "") }
        message = status == errSecSuccess ? "Token guardado no Porta-chaves." : "Token ativo nesta sessão. O Porta-chaves não permitiu guardá-lo sem autorização; ao reabrir a aplicação, pode ser necessário colar novamente o token. Não é necessária a palavra-passe do Mac."
    }
}
