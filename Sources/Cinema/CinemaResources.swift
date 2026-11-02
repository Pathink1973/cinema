import Foundation

enum CinemaResources {
    static func url(_ path: String) -> URL {
        // SwiftPM's generated accessor can fall back to an absolute build path.
        // Prefer the resource bundle inside the installed .app so it is standalone.
        if let appResources = Bundle.main.resourceURL {
            let packaged = appResources.appendingPathComponent("Cinema_Cinema.bundle/Resources")
            if FileManager.default.fileExists(atPath: packaged.path) { return packaged.appendingPathComponent(path) }
        }
        return Bundle.module.bundleURL.appendingPathComponent("Resources").appendingPathComponent(path)
    }
}
