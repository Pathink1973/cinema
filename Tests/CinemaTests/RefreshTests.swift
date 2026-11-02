import Testing
@testable import Cinema
@Test func refreshPreservesExistingFieldsAndAddsMissingOnes() {
    let old = MovieDetails(id: 1, title: "Arrival", overview: "Sinopse", backdrop_path: "/back.jpg", runtime: 116)
    let fresh = MovieDetails(id: 1, title: "Arrival", overview: "", poster_path: "/poster.jpg", genres: [.init(name: "Ficção científica")])
    let result = refreshedMetadata(fresh, preserving: old)
    #expect(result.overview == "Sinopse")
    #expect(result.poster_path == "/poster.jpg")
    #expect(result.backdrop_path == "/back.jpg")
    #expect(result.runtime == 116)
    #expect(result.genres?.first?.name == "Ficção científica")
}
@Test func correctingIdentityDoesNotCarryDataFromWrongMovie() {
    let old = MovieDetails(id: 1, title: "Wrong film", poster_path: "/wrong.jpg")
    let fresh = MovieDetails(id: 2, title: "Correct film")
    #expect(refreshedMetadata(fresh, preserving: old).poster_path == nil)
}
