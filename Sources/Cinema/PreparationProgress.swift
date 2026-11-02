import Foundation
import SwiftUI

struct PreparationProgress: Codable, Sendable, Equatable {
    var percent: Int
    var stage: String
    var elapsedSeconds: Int
    static let initial = PreparationProgress(percent: 1, stage: "A analisar o vídeo…", elapsedSeconds: 0)
}
final class PreparationReporter: @unchecked Sendable {
    private let lock = NSLock()
    private let start = Date()
    private var last = PreparationProgress.initial
    private let callback: @Sendable (PreparationProgress) -> Void
    init(callback: @escaping @Sendable (PreparationProgress) -> Void) { self.callback = callback }
    func emit(_ percent: Double, stage: String) {
        lock.lock()
        let update = PreparationProgress(percent: max(last.percent, min(100, Int(percent.isFinite ? percent : 1))), stage: stage, elapsedSeconds: max(0, Int(Date().timeIntervalSince(start))))
        let changed = update != last
        last = update
        lock.unlock()
        if changed || update.percent == 1 { callback(update) }
    }
}
func remuxProgress(_ line: String, duration: Double?) -> Double? {
    guard line.hasPrefix("out_time_us="), let microseconds = Double(line.dropFirst("out_time_us=".count)), microseconds.isFinite, let duration, duration.isFinite, duration > 0 else { return nil }
    return 2 + min(1, max(0, microseconds / 1_000_000 / duration)) * 83
}

struct PreparationProgressView: View {
    let progress: PreparationProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.stage).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(progress.percent)%").font(.system(.callout, design: .rounded).weight(.bold)).monospacedDigit().foregroundStyle(.orange)
            }
            ProgressView(value: Double(progress.percent), total: 100).tint(.orange)
            Text(String(format: "Decorrido %02d:%02d", progress.elapsedSeconds / 60, progress.elapsedSeconds % 60)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

struct CatalogPreparationFooter: View {
    @ObservedObject var service: WebCatalog
    var showDetails: () -> Void
    var body: some View {
        if let progress = service.preparationProgress, progress.percent < 100, !service.preparation.isEmpty {
            HStack(spacing: 20) {
                Image(systemName: "iphone.radiowaves.left.and.right").foregroundStyle(.orange).font(.title2)
                VStack(alignment: .leading, spacing: 6) {
                    Text("A preparar: \(service.preparation)").font(.caption.bold()).lineLimit(1)
                    PreparationProgressView(progress: progress)
                }.frame(maxWidth: .infinity)
                Button("Detalhes", action: showDetails)
            }.padding(.horizontal, 28).padding(.vertical, 12).background(.regularMaterial)
        }
    }
}
