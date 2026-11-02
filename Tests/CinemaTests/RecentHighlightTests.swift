import Foundation
import Testing
@testable import Cinema
@Test func highlightPrioritizesImportDateOverTitleAndArtwork() {
    let old = Movie(path: "/007.mkv", title: "007 Skyfall")
    var earlier = Movie(path: "/a.mkv", title: "A movie")
    earlier.addedAt = Date(timeIntervalSince1970: 100)
    var newest = Movie(path: "/z.mkv", title: "Z movie without artwork")
    newest.addedAt = Date(timeIntervalSince1970: 200)
    #expect(moviesByImportDate([old, newest, earlier]).map(\.id) == [newest.id, earlier.id, old.id])
    #expect(moviesByImportDate([]).isEmpty)
}
