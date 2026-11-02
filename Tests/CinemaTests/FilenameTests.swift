import Testing
@testable import Cinema

@Test func sceneReleaseWithYearAndSubtitles() {
    let (title, year) = parseFilename("Arrival.2016.1080p.BluRay.x264.mkv")
    #expect(title == "Arrival")
    #expect(year == "2016")
}
@Test func movieWithoutYear() {
    let (title, year) = parseFilename("The_Grand_Budapest_Hotel.1080p.WEB-DL.mp4")
    #expect(title == "The Grand Budapest Hotel")
    #expect(year == nil)
}
@Test func punctuationAndAccents() {
    let (title, year) = parseFilename("O Fabuloso Destino de Amélie (2001).avi")
    #expect(title == "O Fabuloso Destino de Amélie")
    #expect(year == "2001")
}

@Test func numericTitlesAndSequelTitles() {
    #expect(parseFilename("1917 (2019).mkv").0 == "1917")
    #expect(parseFilename("2001.A.Space.Odyssey.1968.mkv").0 == "2001 A Space Odyssey")
    #expect(parseFilename("Blade Runner 2049.mkv").0 == "Blade Runner 2049")
    #expect(parseFilename("1917.mkv").0 == "1917")
}
