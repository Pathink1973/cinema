import Foundation
import SwiftUI
import CryptoKit

func catalogMovieID(_ path: String) -> String { SHA256.hash(data: Data(mediaPathKey(path).utf8)).map { String(format: "%02x", $0) }.joined() }

struct CatalogMovie: Encodable {
    var id: String; var title: String; var year: String?; var synopsis: String?
    var poster: String?; var backdrop: String?; var rating: Double?; var runtime: Int?
    var genres: [String]; var director: String; var cast: [String]
    var favorite: Bool; var watched: Bool; var addedAt: Double?
    var subtitles: [Subtitle]
    struct Subtitle: Encodable { var id: Int; var name: String }
    init(_ movie: Movie) {
        id = catalogMovieID(movie.path); title = movie.displayTitle; year = movie.metadata?.release_date.map { String($0.prefix(4)) } ?? movie.year
        synopsis = movie.metadata?.overview; poster = movie.metadata?.poster_path; backdrop = movie.metadata?.backdrop_path
        rating = movie.metadata?.vote_average; runtime = movie.metadata?.runtime
        genres = movie.metadata?.genres?.map(\.name) ?? []
        director = movie.metadata?.credits?.crew.filter { $0.job == "Director" }.map(\.name).joined(separator: ", ") ?? ""
        cast = movie.metadata?.credits?.cast.prefix(8).map(\.name) ?? []
        favorite = movie.favorite; watched = movie.watched; addedAt = movie.addedAt?.timeIntervalSince1970
        subtitles = movie.subtitles.enumerated().map { .init(id: $0.offset, name: URL(fileURLWithPath: $0.element).lastPathComponent) }
    }
}
struct CatalogCollection: Encodable { var id: UUID; var name: String; var movies: [String] }
struct CatalogSnapshot: Encodable { var movies: [CatalogMovie]; var collections: [CatalogCollection] }
struct CatalogJobStatus: Encodable { var id: String; var state: String; var message: String; var video: String?; var progress: PreparationProgress }

@MainActor final class WebCatalog: ObservableObject {
    @Published var active = false
    @Published var link: URL?
    @Published var error: String?
    @Published var starting = false
    @Published var addresses: [String] = []
    @Published var selectedAddress = ""
    @Published var preparation = ""
    @Published var preparationProgress: PreparationProgress?
    private unowned let library: Library
    private var server: PhoneServer?
    private var port: UInt16?
    private var generation = UUID()
    private var directory: URL?
    private var jobs: [String: Job] = [:]
    private let accessToken: String
    struct Job {
        var id: String; var key: String; var status: String; var message: String
        var file: URL; var runner: MediaCommand; var progress = PreparationProgress.initial; var startedAt = Date(); var task: Task<Void, Never>?
    }
    init(library: Library, accessToken: String? = nil) {
        self.library = library
        if let accessToken { self.accessToken = accessToken }
        else if let saved = UserDefaults.standard.string(forKey: "Cinema.WebCatalog.AccessToken"), saved.count >= 64 { self.accessToken = saved }
        else {
            let token = UUID().uuidString + UUID().uuidString
            UserDefaults.standard.set(token, forKey: "Cinema.WebCatalog.AccessToken"); self.accessToken = token
        }
    }
    func start(bindPort: UInt16? = nil) async {
        guard !active, !starting else { return }; starting = true; error = nil
        let run = generation
        do {
            addresses = PhoneServer.addresses()
            guard let address = addresses.first else { throw phoneError("Liga o Mac ao Wi-Fi ou Ethernet para abrir o catálogo no iPhone.") }
            selectedAddress = address
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaWeb-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); directory = folder
            let remembered = UInt16(exactly: UserDefaults.standard.integer(forKey: "Cinema.WebCatalog.Port")) ?? 0
            let candidates: [UInt16] = bindPort.map { [$0] } ?? [remembered == 0 ? 8787 : remembered, 8788, 8789, 0]
            var lastError: Error?
            for candidate in candidates {
                guard run == generation else { throw CancellationError() }
                let listener = try PhoneServer(token: accessToken, port: candidate) { [weak self] request in
                    guard let self else { return .error("A sessão terminou.", status: "503 Service Unavailable") }
                    return await self.route(request)
                }
                server = listener
                do {
                    port = try await listener.start()
                    guard run == generation else { listener.stop(); return }
                    if bindPort == nil, let port { UserDefaults.standard.set(Int(port), forKey: "Cinema.WebCatalog.Port") }
                    break
                } catch { listener.stop(); server = nil; lastError = error }
            }
            guard port != nil else { throw lastError ?? phoneError("Não há uma porta de rede disponível.") }
            active = true; refreshLink()
        } catch {
            if run == generation { self.error = "Não foi possível iniciar: \(error.localizedDescription). Confirma que a rede local está disponível."; stop() }
        }
        starting = false
    }
    func refreshLink() { if let port { link = URL(string: "http://\(selectedAddress):\(port)/\(accessToken)/") } }
    func stop() {
        generation = UUID(); server?.stop(); server = nil
        clearPrepared(); if let directory { try? FileManager.default.removeItem(at: directory) }; directory = nil
        active = false; starting = false; link = nil; port = nil
    }
    func clearPrepared() {
        for job in jobs.values { job.task?.cancel(); job.runner.cancel(); try? FileManager.default.removeItem(at: job.file.deletingLastPathComponent()) }
        jobs.removeAll(); preparation = ""; preparationProgress = nil
    }
    func snapshot() -> CatalogSnapshot {
        CatalogSnapshot(movies: library.movies.map(CatalogMovie.init), collections: library.collections.map { collection in
            .init(id: collection.id, name: collection.name, movies: library.movies.filter { collection.moviePaths.contains(mediaPathKey($0.path)) }.map { catalogMovieID($0.path) })
        })
    }
    func route(_ request: LocalRequest) -> LocalResponse {
        let path = request.path
        if request.method == "GET" || request.method == "HEAD" {
            if path == "/api/library" { return .json(snapshot()) }
            if path == "/manifest.webmanifest" {
                let manifest = "{\"name\":\"Cinema\",\"short_name\":\"Cinema\",\"start_url\":\"./\",\"scope\":\"./\",\"display\":\"standalone\",\"background_color\":\"#090c11\",\"theme_color\":\"#090c11\",\"icons\":[{\"src\":\"icon-192.png\",\"sizes\":\"192x192\",\"type\":\"image/png\"},{\"src\":\"icon-512.png\",\"sizes\":\"512x512\",\"type\":\"image/png\"}]}"
                return .data(Data(manifest.utf8), mime: "application/manifest+json")
            }
            let assets = ["": ("index.html", "text/html; charset=utf-8"), "/": ("index.html", "text/html; charset=utf-8"), "/app.js": ("app.js", "text/javascript; charset=utf-8"), "/style.css": ("style.css", "text/css; charset=utf-8"), "/icon-192.png": ("icon-192.png", "image/png"), "/icon-512.png": ("icon-512.png", "image/png"), "/apple-touch-icon.png": ("apple-touch-icon.png", "image/png")]
            if let asset = assets[path], let data = try? Data(contentsOf: CinemaResources.url("Web/" + asset.0)) { return .data(data, mime: asset.1) }
            let fields = path.split(separator: "/").map(String.init)
            if fields.count >= 3, fields[0] == "api", fields[1] == "jobs", let job = jobs[fields[2]] {
                if fields.count == 3 { return .json(status(job)) }
                if fields.count == 4, fields[3] == "film.mkv", job.status == "ready", FileManager.default.fileExists(atPath: job.file.path) { return .file(job.file) }
            }
            return .error("Não encontrado.", status: "404 Not Found")
        }
        guard request.method == "POST" else { return .error("Método não permitido.", status: "405 Method Not Allowed") }
        let fields = path.split(separator: "/").map(String.init)
        if path == "/api/collections" {
            struct NewCollection: Decodable { var name: String }
            guard let body = try? JSONDecoder().decode(NewCollection.self, from: request.body), body.name.count <= 100, let id = library.createCollection(body.name) else { return .error("Indica um nome com até 100 caracteres.") }
            return .json(["id": id.uuidString])
        }
        if fields.count == 4, fields[0] == "api", fields[1] == "jobs", fields[3] == "remove", let job = jobs.removeValue(forKey: fields[2]) {
            job.task?.cancel(); job.runner.cancel(); try? FileManager.default.removeItem(at: job.file.deletingLastPathComponent()); return .json(["ok": true])
        }
        guard fields.count == 4, fields[0] == "api", fields[1] == "movies", let movie = library.movies.first(where: { catalogMovieID($0.path) == fields[2] }) else { return .error("Este filme já não está na biblioteca.", status: "404 Not Found") }
        switch fields[3] {
        case "favorite":
            struct Favorite: Decodable { var value: Bool }
            guard let body = try? JSONDecoder().decode(Favorite.self, from: request.body) else { return .error("Pedido inválido.") }
            var updated = movie; updated.favorite = body.value; library.update(updated); return .json(["ok": true])
        case "collection":
            struct Member: Decodable { var id: UUID; var included: Bool }
            guard let body = try? JSONDecoder().decode(Member.self, from: request.body), library.collections.contains(where: { $0.id == body.id }) else { return .error("Coleção inválida.") }
            library.setMembership(movie.path, in: body.id, included: body.included); return .json(["ok": true])
        case "prepare":
            struct Prepare: Decodable { var subtitle: Int? }
            guard let body = try? JSONDecoder().decode(Prepare.self, from: request.body) else { return .error("Pedido inválido.") }
            if let index = body.subtitle, !movie.subtitles.indices.contains(index) { return .error("Legenda inválida.") }
            return prepare(movie, subtitle: body.subtitle)
        default: return .error("Ação desconhecida.", status: "404 Not Found")
        }
    }
    private func status(_ job: Job) -> CatalogJobStatus {
        var progress = job.progress
        if job.status == "preparing" { progress.percent = min(99, progress.percent); progress.elapsedSeconds = max(progress.elapsedSeconds, Int(Date().timeIntervalSince(job.startedAt))) }
        return .init(id: job.id, state: job.status, message: job.message, video: job.status == "ready" ? "api/jobs/\(job.id)/film.mkv" : nil, progress: progress)
    }
    private func prepare(_ movie: Movie, subtitle index: Int?) -> LocalResponse {
        guard let directory else { return .error("Ativa o catálogo na aplicação do Mac.", status: "503 Service Unavailable") }
        let subtitle = index.map { movie.subtitles[$0] }
        let attrs = try? FileManager.default.attributesOfItem(atPath: movie.path)
        let subAttrs = subtitle.flatMap { try? FileManager.default.attributesOfItem(atPath: $0) }
        let key = "\(catalogMovieID(movie.path))|\(index ?? -1)|\(attrs?[.size] ?? 0)|\(attrs?[.modificationDate] ?? Date.distantPast)|\(subAttrs?[.size] ?? 0)|\(subAttrs?[.modificationDate] ?? Date.distantPast)"
        if let existing = jobs.values.first(where: { $0.key == key && $0.status != "error" }) { return .json(status(existing)) }
        guard !jobs.values.contains(where: { $0.status == "preparing" }) else { return .error("O Mac já está a preparar outro filme. Aguarda a conclusão e tenta novamente.", status: "409 Conflict") }
        guard jobs.values.filter({ $0.status == "ready" }).count < 2 else { return .error("Há duas cópias preparadas. Usa “Libertar cópia” num filme anterior ou limpa as cópias na app do Mac.", status: "409 Conflict") }
        let id = UUID().uuidString, folder = directory.appendingPathComponent(UUID().uuidString)
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) } catch { return .error("Não foi possível criar a cópia temporária.") }
        let file = folder.appendingPathComponent("film.mkv"), runner = MediaCommand(), run = generation
        jobs[id] = Job(id: id, key: key, status: "preparing", message: "A incluir e verificar as legendas no Mac…", file: file, runner: runner)
        preparation = movie.displayTitle; preparationProgress = .initial
        let task = Task {
            do {
                try await withTaskCancellationHandler {
                    try await Task.detached(priority: .userInitiated) { try PhoneMedia.prepare(movie: movie, subtitle: subtitle, output: file, runner: runner) { update in
                        Task { @MainActor [weak self] in
                            guard let self, self.generation == run, self.jobs[id]?.status == "preparing" else { return }
                            self.jobs[id]?.progress = update
                            self.preparationProgress = update
                        }
                    } }.value
                } onCancel: { runner.cancel() }
                try Task.checkCancellation()
                guard generation == run, jobs[id] != nil else { try? FileManager.default.removeItem(at: folder); return }
                jobs[id]?.status = "ready"; jobs[id]?.message = "Legendas incluídas e verificadas. Pronto para abrir no VLC."
                let complete = PreparationProgress(percent: 100, stage: "Legendas verificadas. Pronto para reproduzir.", elapsedSeconds: Int(Date().timeIntervalSince(jobs[id]?.startedAt ?? Date())))
                jobs[id]?.progress = complete; preparationProgress = complete
            } catch {
                try? FileManager.default.removeItem(at: folder)
                guard generation == run, jobs[id] != nil else { return }
                jobs[id]?.status = "error"
                if var progress = preparationProgress { progress.percent = min(99, progress.percent); progress.stage = "Preparação interrompida. Verifica o vídeo e as legendas."; preparationProgress = progress }
                jobs[id]?.message = "Não foi possível preparar o filme. Confirma na app do Mac que o vídeo e a legenda são válidos, estão disponíveis e há espaço livre suficiente."
            }
        }
        jobs[id]?.task = task
        return .json(status(jobs[id]!))
    }
}
