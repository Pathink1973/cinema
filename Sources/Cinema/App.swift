import SwiftUI
import AppKit

@main struct CinemaApp: App {
    @StateObject private var library = Library()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(library).preferredColorScheme(.dark)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .defaultSize(width: 1320, height: 860)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Adicionar pasta…") { library.addFolder() }.keyboardShortcut("o")
                Button("Pesquisar filmes") { NotificationCenter.default.post(name: .cinemaFocusSearch, object: nil) }.keyboardShortcut("f")
                Button("Atualizar biblioteca") { library.scan() }.keyboardShortcut("r")
            }
        }
    }
}
struct ContentView: View {
    @EnvironmentObject var library: Library
    @State private var section = "Início"
    @State private var query = ""
    @State private var selection: String?
    @State private var settings = false
    @State private var webCatalog = false
    @State private var repairingMovie: Movie?
    private let sections = ["Início", "Biblioteca", "Recentes", "Favoritos", "Por ver", "Coleções"]
    var filtered: [Movie] {
        let searching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let list = library.movies.filter {
            movieMatchesQuery($0, query: query) && (searching || (
                (section != "Favoritos" || $0.favorite) && (section != "Por ver" || !$0.watched) &&
                (section != "Recentes" || $0.lastPlayed != nil)))
        }
        return section == "Recentes" && !searching ? list.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) } : list
    }
    var selected: Movie? {
        filtered.first(where: { $0.id == selection }) ?? (section == "Início" ? moviesByImportDate(filtered).first : filtered.first)
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle.fill").foregroundStyle(.orange).font(.title)
                    Text("cinema").font(.system(size: 30, weight: .bold, design: .rounded))
                }.padding(.top, 30)
                VStack(spacing: 8) {
                    ForEach(sections, id: \.self) { item in
                        Button { section = item; selection = nil } label: {
                            Label(item, systemImage: icon(item)).font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(13)
                                .background(section == item ? Color.white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                Text("A TUA SALA DE CINEMA").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                Button { library.addFolder() } label: { Label("Adicionar pasta", systemImage: "folder.badge.plus") }
                Button { webCatalog = true } label: { Label("Cinema no iPhone", systemImage: "iphone.radiowaves.left.and.right") }
                Button { settings = true } label: { Label("Definições", systemImage: "gearshape") }
                Text("\(library.movies.count) filmes na biblioteca").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(width: 220).background(Color(red: 0.055, green: 0.06, blue: 0.075))
            if section == "Coleções" {
                CollectionsView()
            } else {
            VStack(spacing: 0) {
            LibraryToolbar(section: section, query: $query)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let movie = selected {
                        HeroView(movie: movie, compact: section == "Início").id(movie.id)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: library.movies.isEmpty ? "film.stack" : "magnifyingglass").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(.orange)
                            Text(library.movies.isEmpty ? "O teu cinema começa aqui." : "Nenhum filme encontrado.").font(.system(size: 34, weight: .bold))
                            Text(library.movies.isEmpty ? "Adiciona a pasta onde guardas os filmes. Nós organizamos a sessão." : "Experimenta outra pesquisa ou outra coleção.").foregroundStyle(.secondary)
                            if library.movies.isEmpty { Button("Adicionar pasta de filmes…") { library.addFolder() }.buttonStyle(.borderedProminent).tint(.orange) }
                        }.frame(maxWidth: .infinity).frame(height: 400)
                    }
                    }
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filtered.isEmpty {
                        ContentUnavailableView("Nenhum filme encontrado", systemImage: "magnifyingglass", description: Text("Experimenta o título original, o realizador ou parte do nome do ficheiro."))
                    }
                    if section == "Início" && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HomeRows(movies: filtered, selection: $selection, repair: { repairingMovie = $0 })
                    } else {
                    HStack {
                        Text("\(filtered.count) FILMES").font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Procurar capas no TMDB") { library.enrich() }.disabled(library.busy || library.movies.isEmpty)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145, maximum: 200), spacing: 20)], spacing: 26) {
                        ForEach(filtered) { movie in
                            MovieCard(movie: movie, selected: selection == movie.id) { selection = movie.id }
                        }
                    }
                    }
                }.padding(32)
            }
            }.background(Color(red: 0.035, green: 0.04, blue: 0.055))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { CatalogPreparationFooter(service: library.webCatalog) { webCatalog = true } }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in library.volumesChanged() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in library.volumesChanged() }
        .onChange(of: query) { _, _ in selection = nil }
        .task { await library.monitorFolders() }
        .dropDestination(for: URL.self) { urls, _ in library.addFolders(urls) }
        .overlay(alignment: .bottomTrailing) {
            if !library.newMovieIDs.isEmpty || library.activityNotice != nil {
                HStack(spacing: 14) {
                    Image(systemName: library.newMovieIDs.isEmpty ? "folder.badge.questionmark" : "sparkles").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        if !library.newMovieIDs.isEmpty {
                            Text(library.newMovieIDs.count == 1 ? "Novo vídeo: \(library.movies.first(where: { $0.id == library.newMovieIDs.first })?.displayTitle ?? "adicionado")" : "\(library.newMovieIDs.count) novos vídeos adicionados").font(.headline).lineLimit(2)
                        }
                        if let notice = library.activityNotice { Text(notice).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    }
                    if let id = library.newMovieIDs.first, library.movies.contains(where: { $0.id == id }) {
                        Button("Ver ficha") { query = ""; section = "Biblioteca"; selection = id; library.newMovieIDs = []; library.activityNotice = nil }
                    }
                    Button { library.newMovieIDs = []; library.activityNotice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Fechar aviso")
                }.padding(18).frame(maxWidth: 490).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).shadow(radius: 14).padding(24)
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $webCatalog) { WebCatalogPanel(service: library.webCatalog) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in library.webCatalog.stop() }
        .sheet(item: $repairingMovie) { movie in IdentifyView(movie: movie, autoRepair: true) }
        .alert("Cinema", isPresented: Binding(get: { library.message != nil }, set: { if !$0 { library.message = nil } })) { Button("OK") { library.message = nil } } message: { Text(library.message ?? "") }
    }
    func icon(_ item: String) -> String {
        switch item { case "Coleções": "rectangle.stack"; case "Início": "house"; case "Recentes": "clock"; case "Favoritos": "heart"; case "Por ver": "bookmark"; default: "square.grid.2x2" }
    }
}
struct Artwork: View {
    let path: String?
    let wide: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.19, green: 0.22, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "film").font(.system(size: wide ? 90 : 40, weight: .ultraLight)).foregroundStyle(.white.opacity(0.15))
                if let path, let url = URL(string: "https://image.tmdb.org/t/p/\(wide ? "w1280" : "w500")\(path)") {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
}
struct HeroView: View {
    @EnvironmentObject var library: Library
    let movie: Movie
    var compact = false
    @State private var identifying = false
    @State private var choosingCollection = false
    @State private var sharingPhone = false
    @State private var repairing = false
    @State private var subtitle = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .bottomLeading) {
                Artwork(path: movie.metadata?.backdrop_path, wide: true)
                LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 13) {
                    Text("NA TUA BIBLIOTECA").font(.system(size: 10, weight: .bold)).tracking(3).foregroundStyle(.orange)
                    Text(movie.displayTitle).font(.system(size: 42, weight: .bold)).lineLimit(2)
                    HStack(spacing: 16) {
                        Text(movie.metadata?.release_date.map { String($0.prefix(4)) } ?? movie.year ?? "")
                        if let runtime = movie.metadata?.runtime { Text("\(runtime) min") }
                        if let rating = movie.metadata?.vote_average { Label(String(format: "%.1f TMDB", rating), systemImage: "star.fill").foregroundStyle(.orange) }
                        Text(URL(fileURLWithPath: movie.path).pathExtension.uppercased())
                    }.font(.subheadline).foregroundStyle(.secondary)
                    Text(movie.metadata?.overview.flatMap { $0.isEmpty ? nil : $0 } ?? "Este filme está pronto a ver. Identifica-o no TMDB para adicionar a capa, a sinopse e a ficha técnica.")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.8)).lineLimit(3).frame(maxWidth: 650, alignment: .leading)
                    HStack(spacing: 12) {
                        Button { library.play(movie, subtitle: subtitle.isEmpty ? movie.subtitles.first : subtitle == "none" ? nil : subtitle) } label: { Label("Ver no VLC", systemImage: "play.fill").padding(.horizontal, 12).padding(.vertical, 5) }.buttonStyle(.borderedProminent).tint(.orange).keyboardShortcut(.return, modifiers: [])
                        Button { var updated = movie; updated.favorite.toggle(); library.update(updated) } label: { Image(systemName: movie.favorite ? "heart.fill" : "heart") }
                        Button { var updated = movie; updated.watched.toggle(); library.update(updated) } label: { Label(movie.watched ? "Visto" : "Marcar visto", systemImage: "checkmark") }
                        Button("Identificar…") { identifying = true }
                        Menu {
                            Button { sharingPhone = true } label: { Label("Ver no iPhone…", systemImage: "iphone") }
                            Button { choosingCollection = true } label: { Label("Adicionar à coleção…", systemImage: "rectangle.stack.badge.plus") }
                            Button("Procurar dados em falta") { repairing = true }.disabled(library.busy)
                            Button { library.exclude(movie) } label: { Label("Remover da biblioteca", systemImage: "eye.slash") }
                        } label: { Image(systemName: "ellipsis") }.fixedSize().help("Mais opções")
                    }.controlSize(.large)
                }.padding(30)
            }.frame(height: compact ? 320 : 400).clipShape(RoundedRectangle(cornerRadius: 22))
            if !compact, let details = movie.metadata {
                HStack(alignment: .top, spacing: 30) {
                    detail("GÉNEROS", details.genres?.map(\.name).joined(separator: " · ") ?? "—")
                    detail("REALIZAÇÃO", details.credits?.crew.filter { $0.job == "Director" }.map(\.name).joined(separator: ", ") ?? "—")
                    detail("ELENCO", details.credits?.cast.prefix(5).map(\.name).joined(separator: ", ") ?? "—")
                }
            }
            if !compact && !movie.subtitles.isEmpty {
                Picker("Legendas externas", selection: $subtitle) {
                    Text("Automático").tag("")
                    Text("Sem ficheiro externo").tag("none")
                    ForEach(movie.subtitles, id: \.self) { path in Text(URL(fileURLWithPath: path).lastPathComponent).tag(path) }
                }.frame(maxWidth: 550)
            }
        }.sheet(isPresented: $identifying) { IdentifyView(movie: movie) }
        .sheet(isPresented: $repairing) { IdentifyView(movie: movie, autoRepair: true) }
        .sheet(isPresented: $choosingCollection) { CollectionPicker(movie: movie) }
        .sheet(isPresented: $sharingPhone) { PhoneShareView(movie: movie) }
    }
    func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(.secondary); Text(value).font(.caption).lineLimit(3) }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct IdentifyView: View {
    @EnvironmentObject var library: Library
    @Environment(\.dismiss) var dismiss
    let movie: Movie
    var autoRepair = false
    @State private var notice: String?
    @State private var query = ""
    @State private var results: [MovieDetails] = []
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(autoRepair ? "Procurar dados em falta" : "Identificar filme").font(.title.bold())
            Text(URL(fileURLWithPath: movie.path).lastPathComponent).foregroundStyle(.secondary).lineLimit(2)
            HStack { TextField("Título do filme", text: $query).onSubmit { search() }; Button("Pesquisar") { search() }.disabled(busy || query.isEmpty) }
            if busy { ProgressView("A consultar o TMDB…") }
            if let notice { Text(notice).font(.callout).foregroundStyle(.secondary) }
            if let error { Text(error).foregroundStyle(.orange) }
            List(results) { result in
                Button {
                    busy = true
                    Task {
                        do { try await library.identify(movie, result: result); dismiss() }
                        catch { self.error = error.localizedDescription }
                        busy = false
                    }
                } label: {
                    HStack(spacing: 14) {
                        Artwork(path: result.poster_path, wide: false).frame(width: 45, height: 65).clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading) { Text(result.title).font(.headline); Text(result.release_date ?? "Ano desconhecido").foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "plus.circle")
                    }
                }.buttonStyle(.plain).disabled(busy)
            }
            HStack { Text("Seleciona o resultado correto para guardar a ficha.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Fechar") { dismiss() } }
        }.padding(28).frame(width: 640, height: 540)
        .task {
            query = movie.title
            guard autoRepair else { return }
            busy = true
            do {
                if let candidates = try await library.repair(movie) {
                    results = candidates
                    notice = candidates.isEmpty ? "Sem resultados automáticos. Experimenta pesquisar pelo título original." : "Há vários resultados possíveis. Seleciona o filme correto ou altera a pesquisa."
                } else {
                    notice = "Ficha atualizada com os dados disponíveis no TMDB. Se ainda faltar a capa ou outro campo, pode não estar disponível para este filme. Usa a pesquisa para corrigir a identificação, se necessário."
                }
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    func search() {
        busy = true; error = nil; notice = nil
        Task {
            do { results = try await library.search(query); if results.isEmpty { error = "Nenhum resultado. Experimenta o título original." } }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var library: Library
    @Environment(\.dismiss) var dismiss
    @State private var token = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Definições").font(.title.bold())
            Text("Capas e fichas técnicas").font(.headline)
            Text("Introduz o API Read Access Token da tua conta TMDB. Fica ativo nesta sessão e é guardado no Porta-chaves quando o acesso está disponível, sem pedir a palavra-passe do Mac.").foregroundStyle(.secondary)
            SecureField("Token de leitura TMDB", text: $token)
            HStack { Link("Obter token no TMDB ↗", destination: URL(string: "https://www.themoviedb.org/settings/api")!); Spacer(); Button("Guardar token") { library.setToken(token) } }
            Divider()
            Text("Pastas da biblioteca").font(.headline)
            Text("Enquanto o Cinema está aberto, deteta alterações nas pastas e a ligação de discos. Durante uma cópia, verifica a estabilidade a cada 15 segundos; faz também uma verificação de segurança a cada 2 minutos. Podes arrastar pastas para a janela.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(library.folders, id: \.self) { path in
                        HStack { Text(path).font(.caption).textSelection(.enabled); Spacer(); Button("Remover") { library.folders.removeAll { $0 == path }; library.movies.removeAll { movie in !library.folders.contains { root in movie.path.hasPrefix(root + "/") } }; library.save() } }
                    }
                }
            }.frame(height: 110)
            Button("Adicionar pasta…") { library.addFolder() }
            Divider()
            DisclosureGroup("Vídeos excluídos (\(library.excludedMovies.count))") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Estes vídeos ficam fora da biblioteca, mesmo depois de atualizar as pastas. Os ficheiros e as legendas permanecem no disco.").font(.caption).foregroundStyle(.secondary)
                    if library.excludedMovies.isEmpty { Text("Nenhum vídeo excluído.").font(.caption).foregroundStyle(.secondary) }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(library.excludedMovies) { movie in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(movie.displayTitle).font(.caption.bold())
                                        Text(movie.path).font(.caption2).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                                    }
                                    Spacer()
                                    Button("Restaurar") { library.restore(movie) }
                                }
                            }
                        }
                    }.frame(height: library.excludedMovies.isEmpty ? 0 : 140)
                }.padding(.top, 8)
            }
            Divider()
            Text("Reprodução no VLC instalado no Mac. O histórico regista os filmes abertos; o ponto de reprodução é gerido pelo VLC.").font(.caption).foregroundStyle(.secondary)
            if let logo = NSImage(contentsOf: CinemaResources.url("tmdb.svg")) { Image(nsImage: logo).resizable().scaledToFit().frame(width: 90, height: 18) }
            Link("TMDB", destination: URL(string: "https://www.themoviedb.org")!).font(.headline)
            Text("This product uses the TMDB API but is not endorsed or certified by TMDB.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Concluído") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 620).onAppear { token = library.token }
    }
}
