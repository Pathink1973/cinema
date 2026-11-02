import Testing
@testable import Cinema
@Test @MainActor func tokenIsReadOnlyOnceForManyRequests() {
    let session = TokenSession()
    var reads = 0
    for _ in 0..<1000 {
        #expect(session.value { reads += 1; return "test-token" } == "test-token")
    }
    #expect(reads == 1)
    session.store("updated-token")
    #expect(session.value { reads += 1; return "old-token" } == "updated-token")
    #expect(reads == 1)
}
@Test @MainActor func deniedAccessDoesNotPromptOnEveryRequest() {
    let session = TokenSession()
    var reads = 0
    for _ in 0..<10 { #expect(session.value { reads += 1; return "" }.isEmpty) }
    #expect(reads == 1)
    session.store("new-token")
    #expect(session.value { "" } == "new-token")
}

@Test @MainActor func reentrantReadDoesNotLoadKeychainAgain() {
    let session = TokenSession()
    var reads = 0
    let result = session.value {
        reads += 1
        #expect(session.value { reads += 1; return "nested" }.isEmpty)
        return "outer"
    }
    #expect(reads == 1)
    #expect(result == "outer")
}
