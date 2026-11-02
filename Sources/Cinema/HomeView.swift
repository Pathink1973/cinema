import SwiftUI

struct HomeRows: View {
    let movies: [Movie]
    @Binding var selection: String?
    let repair: (Movie) -> Void
    private var illustrated: [Movie] { movies.filter { $0.metadata?.poster_path?.isEmpty == false } }
    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            if illustrated.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prepara a tua próxima sessão").font(.title2.bold())
                    Text("Procura as capas no TMDB para preencher o Início com os teus filmes.").foregroundStyle(.secondary)
                    Button("Procurar capas no TMDB") { library.enrich() }.disabled(library.busy || movies.isEmpty)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
            } else {
                CoverFlowRow(title: movies.contains(where: { $0.addedAt != nil }) ? "Adicionados recentemente" : "Da tua coleção", subtitle: "O teu cinema, à distância de um clique", movies: moviesByImportDate(illustrated), selection: $selection, repair: repair)
                let favorites = illustrated.filter(\.favorite)
                if !favorites.isEmpty { CoverFlowRow(title: "Favoritos", subtitle: "Os filmes a que vale a pena voltar", movies: favorites, selection: $selection, repair: repair) }
                let unseen = illustrated.filter { !$0.watched }
                if !unseen.isEmpty { CoverFlowRow(title: "Por ver", subtitle: "À espera da próxima sessão", movies: unseen, selection: $selection, repair: repair) }
            }
        }
    }
    @EnvironmentObject private var library: Library
}

struct CoverFlowRow: View {
    @EnvironmentObject private var library: Library
    let title: String
    let subtitle: String
    let movies: [Movie]
    @Binding var selection: String?
    let repair: (Movie) -> Void
    @State private var position: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 24, weight: .bold))
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 24, height: 24) }.help("Filme anterior").disabled(index == 0)
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 24, height: 24) }.help("Filme seguinte").disabled(index >= movies.count - 1)
            }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 20) {
                    ForEach(movies) { movie in
                        MovieCard(movie: movie, posterHeight: 315, selected: selection == movie.id) {
                            withAnimation(.easeInOut(duration: 0.22)) { selection = movie.id; position = movie.id }
                        }
                        .frame(width: 210).scaleEffect(selection == movie.id ? 1 : 0.95, anchor: .top)
                        .padding(.vertical, 6).id(movie.id)
                    }
                }.scrollTargetLayout().padding(.horizontal, 5)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .leading)
            .focusable().focusEffectDisabled()
            .onMoveCommand { direction in
                if direction == .left { move(-1) }
                if direction == .right { move(1) }
            }
        }
    }
    private var index: Int { movies.firstIndex(where: { $0.id == position }) ?? movies.firstIndex(where: { $0.id == selection }) ?? 0 }
    private func move(_ offset: Int) {
        guard !movies.isEmpty else { return }
        let target = movies[min(max(index + offset, 0), movies.count - 1)]
        withAnimation(.easeInOut(duration: 0.25)) { position = target.id; selection = target.id }
    }
}
