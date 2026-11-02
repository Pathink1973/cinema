import Foundation
import CoreServices

final class FolderChangeWatcher {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "Cinema.FolderChanges", qos: .utility)
    private let changed: @Sendable () -> Void
    init(paths: [String], changed: @escaping @Sendable () -> Void) {
        self.changed = changed
        guard !paths.isEmpty else { return }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer)
        stream = FSEventStreamCreate(nil, { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FolderChangeWatcher>.fromOpaque(info).takeUnretainedValue().changed()
        }, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags)
        if let stream { FSEventStreamSetDispatchQueue(stream, queue); if !FSEventStreamStart(stream) { stop() } }
    }
    func stop() {
        if let stream { FSEventStreamStop(stream); FSEventStreamInvalidate(stream); FSEventStreamRelease(stream); self.stream = nil }
    }
    deinit { stop() }
}
