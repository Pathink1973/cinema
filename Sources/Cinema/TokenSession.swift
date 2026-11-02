// Keep credentials in memory for this app session. Keychain remains the durable store.
@MainActor final class TokenSession {
    private var cached: String?
    func value(load: () -> String) -> String {
        if let cached { return cached }
        cached = "" // Reserve before entering system APIs, which may re-enter the main run loop.
        let value = load()
        cached = value // Cache denied/missing reads too, avoiding repeated permission prompts.
        return value
    }
    func store(_ value: String) { cached = value }
}
