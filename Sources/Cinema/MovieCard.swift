import SwiftUI

struct MovieCard: View {
    @EnvironmentObject private var library: Library
    let movie: Movie
    var posterHeight: CGFloat = 240
    var selected = false
    var onSelect: () -> Void = {}
    @State private var details = false
    @State private var repairing = false
    @State private var choosingCollection = false
    @State private var sharingPhone = false
    @State private var hovering = false
    private var current: Movie { library.movies.first(where: { $0.id == movie.id }) ?? movie }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                Button { onSelect(); details = true } label: {
                    Artwork(path: current.metadata?.poster_path, wide: false)
                        .frame(height: posterHeight)
                        .overlay(alignment: .bottom) {
                            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom).frame(height: 95)
                        }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Abrir ficha: \(current.displayTitle)")
                HStack(spacing: 10) {
                    Button { library.play(current, subtitle: current.subtitles.first) } label: {
                        Label("Ver", systemImage: "play.fill").font(.system(size: 12, weight: .bold)).padding(.horizontal, 12).frame(height: 34)
                            .background(Color.orange, in: Capsule()).foregroundStyle(.black)
                    }.buttonStyle(.plain).help("Ver no VLC").accessibilityLabel("Ver filme: \(current.displayTitle)")
                    Spacer(minLength: 0)
                    Button { toggleFavorite() } label: {
                        Image(systemName: current.favorite ? "heart.fill" : "heart").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(current.favorite ? Color.orange : .white)
                            .frame(width: 34, height: 34).background(.ultraThinMaterial, in: Circle())
                    }.buttonStyle(.plain).help(current.favorite ? "Remover dos favoritos" : "Adicionar aos favoritos")
                        .accessibilityLabel(current.favorite ? "Remover dos favoritos: \(current.displayTitle)" : "Adicionar aos favoritos: \(current.displayTitle)")
                }.padding(10)
                if current.watched {
                    VStack { HStack { Spacer(); Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).shadow(radius: 4) }; Spacer() }.padding(12).allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected || hovering ? Color.orange.opacity(0.9) : .white.opacity(0.08), lineWidth: selected ? 3 : 1))
            .shadow(color: .black.opacity(0.25), radius: hovering ? 12 : 5, y: 5)
            Button { onSelect(); details = true } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(current.displayTitle).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text(current.metadata?.release_date.map { String($0.prefix(4)) } ?? current.year ?? "Filme local").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button { details = true } label: { Label("Ver ficha", systemImage: "info.circle") }
            Button { library.play(current, subtitle: current.subtitles.first) } label: { Label("Ver filme", systemImage: "play.fill") }
            Button { toggleFavorite() } label: { Label(current.favorite ? "Remover dos favoritos" : "Adicionar aos favoritos", systemImage: current.favorite ? "heart.slash" : "heart") }
            Button { choosingCollection = true } label: { Label("Adicionar à coleção…", systemImage: "rectangle.stack.badge.plus") }
            Button { sharingPhone = true } label: { Label("Ver no iPhone…", systemImage: "iphone") }
            Divider()
            Button { repairing = true } label: { Label("Procurar dados em falta", systemImage: "arrow.triangle.2.circlepath") }.disabled(library.busy)
            Button { library.exclude(current) } label: { Label("Remover da biblioteca", systemImage: "eye.slash") }
        }
        .sheet(isPresented: $details) { MovieDetailModal(movieID: movie.id) }
        .sheet(isPresented: $repairing) { IdentifyView(movie: current, autoRepair: true) }
        .sheet(isPresented: $choosingCollection) { CollectionPicker(movie: current) }
        .sheet(isPresented: $sharingPhone) { PhoneShareView(movie: current) }
    }
    private func toggleFavorite() {
        var updated = current
        updated.favorite.toggle()
        library.update(updated)
    }
}

struct MovieDetailModal: View {
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    let movieID: String
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("A tua sessão", systemImage: "film").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).frame(width: 30, height: 30).background(.white.opacity(0.08), in: Circle()) }
                    .buttonStyle(.plain).help("Fechar ficha").keyboardShortcut(.cancelAction)
            }.padding(.horizontal, 24).padding(.vertical, 14)
            ScrollView {
                if let movie = library.movies.first(where: { $0.id == movieID }) {
                    VStack(alignment: .leading, spacing: 22) {
                        HeroView(movie: movie)
                        if let overview = movie.metadata?.overview, !overview.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SINOPSE").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.orange)
                                Text(overview).font(.system(size: 14)).foregroundStyle(.white.opacity(0.85)).textSelection(.enabled)
                            }.padding(.horizontal, 6)
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 28)
                }
            }
        }.frame(width: 860, height: 690)
            .background(Color(red: 0.045, green: 0.05, blue: 0.065))
            .preferredColorScheme(.dark)
            .onChange(of: library.movies.contains(where: { $0.id == movieID })) { _, exists in if !exists { dismiss() } }
    }
}
