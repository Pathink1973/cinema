import SwiftUI

struct CollectionPicker: View {
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    let movie: Movie
    @State private var name = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Adicionar à coleção", systemImage: "rectangle.stack.badge.plus").font(.title2.bold())
            Text(movie.displayTitle).foregroundStyle(.secondary)
            List(library.collections) { collection in
                Toggle(collection.name, isOn: Binding(get: {
                    library.collections.first(where: { $0.id == collection.id })?.moviePaths.contains(mediaPathKey(movie.path)) == true
                }, set: { library.setMembership(movie.path, in: collection.id, included: $0) }))
            }.frame(height: 220)
            HStack {
                TextField("Nova coleção, por exemplo Wes Anderson", text: $name).onSubmit { create() }
                Button("Criar e adicionar", action: create).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("Um filme pode pertencer a várias coleções. As alterações são guardadas automaticamente.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Concluído") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(28).frame(width: 550)
    }
    private func create() {
        if let id = library.createCollection(name) { library.setMembership(movie.path, in: id, included: true); name = "" }
    }
}

struct CollectionsView: View {
    @EnvironmentObject private var library: Library
    @State private var selectedID: UUID?
    @State private var newName = ""
    @State private var managing = false
    @State private var deleting = false
    @State private var query = ""
    private var selected: MovieCollection? { library.collections.first(where: { $0.id == selectedID }) ?? library.collections.first }
    private var members: [Movie] {
        guard let selected else { return [] }
        return library.movies.filter { selected.moviePaths.contains(mediaPathKey($0.path)) && (query.isEmpty || $0.displayTitle.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Label("Coleções", systemImage: "rectangle.stack").font(.largeTitle.bold()); Spacer() }
            HStack {
                TextField("Nome da nova coleção", text: $newName).textFieldStyle(.roundedBorder).onSubmit { create() }
                Button("Criar coleção", action: create).disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let selected {
                HStack(alignment: .top, spacing: 24) {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(library.collections) { collection in
                                Button { selectedID = collection.id; query = "" } label: {
                                    HStack { Image(systemName: "rectangle.stack.fill"); Text(collection.name).lineLimit(2); Spacer() }
                                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(collection.id == selected.id ? .orange.opacity(0.18) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                            }
                        }
                    }.frame(width: 180)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) { Text(selected.name).font(.title.bold()); Text("\(members.count) filmes").foregroundStyle(.secondary) }
                                Spacer()
                                Button { managing = true } label: { Label("Selecionar filmes", systemImage: "plus.circle") }
                                Button { deleting = true } label: { Image(systemName: "trash") }.help("Apagar coleção")
                            }
                            TextField("Pesquisar nesta coleção", text: $query).textFieldStyle(.roundedBorder)
                            if members.isEmpty {
                                ContentUnavailableView("Ainda não há filmes aqui", systemImage: "film.stack", description: Text("Usa Selecionar filmes ou o menu de uma capa para adicionar filmes a esta coleção."))
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 18)], spacing: 24) {
                                ForEach(members) { movie in
                                    VStack(spacing: 10) {
                                        MovieCard(movie: movie)
                                        Button("Retirar da coleção") { library.setMembership(movie.path, in: selected.id, included: false) }.font(.caption).buttonStyle(.borderless).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("As tuas coleções", systemImage: "rectangle.stack", description: Text("Cria uma coleção por realizador, género ou tema. Por exemplo: Wes Anderson."))
            }
            Spacer(minLength: 0)
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(red: 0.035, green: 0.04, blue: 0.055))
            .sheet(isPresented: $managing) { if let selected { CollectionMembersEditor(collection: selected) } }
            .alert("Apagar esta coleção?", isPresented: $deleting) {
                Button("Cancelar", role: .cancel) {}
                Button("Apagar coleção", role: .destructive) { if let selected { library.deleteCollection(selected.id); selectedID = nil } }
            } message: { Text("Os filmes e os ficheiros permanecem na biblioteca. Apenas a coleção é apagada.") }
    }
    private func create() { if let id = library.createCollection(newName) { selectedID = id; newName = "" } }
}

struct CollectionMembersEditor: View {
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    let collection: MovieCollection
    @State private var paths: Set<String> = []
    @State private var query = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filmes de \(collection.name)").font(.title2.bold())
            TextField("Pesquisar título ou realizador", text: $query).textFieldStyle(.roundedBorder)
            List(library.movies.filter { movie in
                query.isEmpty || movie.displayTitle.localizedCaseInsensitiveContains(query) || movie.metadata?.credits?.crew.contains(where: { $0.job == "Director" && $0.name.localizedCaseInsensitiveContains(query) }) == true
            }) { movie in
                Toggle(isOn: Binding(get: { paths.contains(mediaPathKey(movie.path)) }, set: { included in
                    if included { paths.insert(mediaPathKey(movie.path)) } else { paths.remove(mediaPathKey(movie.path)) }
                })) {
                    HStack(spacing: 12) {
                        Artwork(path: movie.metadata?.poster_path, wide: false).frame(width: 34, height: 50).clipShape(RoundedRectangle(cornerRadius: 5))
                        VStack(alignment: .leading) { Text(movie.displayTitle); Text(movie.metadata?.credits?.crew.filter { $0.job == "Director" }.map(\.name).joined(separator: ", ") ?? "").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            HStack { Text("\(paths.count) selecionados").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Cancelar") { dismiss() }; Button("Guardar") { library.setCollectionMembers(collection.id, paths: paths); dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(26).frame(width: 620, height: 580).onAppear { paths = collection.moviePaths }
    }
}
