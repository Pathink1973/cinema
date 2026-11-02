import Testing
import Foundation
@testable import Cinema

private func result(_ id: Int, _ title: String, _ year: String, original: String? = nil) -> MovieDetails {
    MovieDetails(id: id, title: title, original_title: original, release_date: year + "-01-01")
}
@Test func originalTitleMatchesLocalizedResult() {
    let candidate = result(1, "A Origem", "2010", original: "Inception")
    #expect(automaticMatch(title: "Inception", year: "2010", candidates: [candidate])?.id == 1)
}
@Test func punctuationAndSmallTypos() {
    #expect(automaticMatch(title: "Spider Man No Way Home", year: "2021", candidates: [result(1, "Spider-Man: No Way Home", "2021")])?.id == 1)
    #expect(automaticMatch(title: "Interstelar", year: "2014", candidates: [result(1, "Interstellar", "2014")])?.id == 1)
}
@Test func remakesNeedYearOrManualReview() {
    let candidates = [result(1, "Dune", "1984"), result(2, "Dune", "2021")]
    #expect(automaticMatch(title: "Dune", year: "2021", candidates: candidates)?.id == 2)
    #expect(automaticMatch(title: "Dune", year: nil, candidates: candidates) == nil)
}
@Test func rejectsWrongFilmAndSequel() {
    #expect(automaticMatch(title: "Movie 2", year: "2020", candidates: [result(1, "Movie 3", "2020")]) == nil)
    #expect(automaticMatch(title: "Rocky II", year: "1979", candidates: [result(1, "Rocky III", "1979")]) == nil)
    #expect(automaticMatch(title: "Arrival", year: "2016", candidates: [result(1, "The Arrival", "1996")]) == nil)
    #expect(automaticMatch(title: "Arrival", year: "2016", candidates: [result(1, "Avengers", "2016")]) == nil)
}
@Test func toleratesRegionalReleaseAndDeduplicates() {
    let candidate = result(1, "Example Film", "2020")
    #expect(automaticMatch(title: "Example Film", year: "2021", candidates: [candidate, candidate])?.id == 1)
}
@Test func legacySavedMetadataRemainsReadable() throws {
    let candidate = try JSONDecoder().decode(MovieDetails.self, from: Data(#"{"id":1,"title":"Arrival"}"#.utf8))
    #expect(candidate.original_title == nil)
}
