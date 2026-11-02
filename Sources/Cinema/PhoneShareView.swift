import SwiftUI
import CoreImage.CIFilterBuiltins

@MainActor final class PhoneShareModel: ObservableObject {
    @Published var busy = false
    @Published var progress = PreparationProgress.initial
    @Published var link: URL?
    @Published var error: String?
    @Published var selectedAddress = ""
    @Published var addresses = PhoneServer.addresses()
    private var server: PhoneServer?
    private var task: Task<Void, Never>?
    private var runner: MediaCommand?
    private var temporaryDirectory: URL?
    private var port: UInt16?
    private var generation = UUID()
    private var expiryTask: Task<Void, Never>?
    func prepare(_ movie: Movie, subtitle: String?) {
        stop(); error = nil
        addresses = PhoneServer.addresses()
        guard let first = addresses.first else { error = "Liga o Mac à rede Wi-Fi ou Ethernet e tenta novamente."; return }
        selectedAddress = first; busy = true
        let job = generation
        let runner = MediaCommand(); self.runner = runner
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaPhone-" + UUID().uuidString)
        temporaryDirectory = directory
        task = Task {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let file = directory.appendingPathComponent("film.mkv")
                try await withTaskCancellationHandler {
                    try await Task.detached(priority: .userInitiated) { try PhoneMedia.prepare(movie: movie, subtitle: subtitle, output: file, runner: runner) { update in
                        Task { @MainActor [weak self] in
                            guard let self, self.generation == job, self.busy else { return }
                            var visible = update
                            if visible.percent == 100 { visible.percent = 99; visible.stage = "A abrir a ligação de streaming…" }
                            self.progress = visible
                        }
                    } }.value
                } onCancel: { runner.cancel() }
                try Task.checkCancellation()
                let server = try PhoneServer(file: file, title: movie.displayTitle)
                self.server = server
                port = try await server.start()
                try Task.checkCancellation()
                refreshLink(); busy = false
                progress.percent = 100; progress.stage = "Legendas verificadas. Pronto para reproduzir."
                expiryTask = Task {
                    do { try await Task.sleep(for: .seconds(7200)) } catch { return }
                    self.stop(); self.error = "A partilha expirou. Prepara o vídeo novamente para criar outra ligação."
                }
            } catch {
                guard generation == job else { try? FileManager.default.removeItem(at: directory); return }
                busy = false
                if !Task.isCancelled { self.error = error.localizedDescription }
                server?.stop(); server = nil
                try? FileManager.default.removeItem(at: directory)
            }
        }
    }
    func refreshLink() {
        guard let server, let port else { return }
        link = URL(string: "http://\(selectedAddress):\(port)/\(server.token)/")
    }
    func stop() {
        generation = UUID(); expiryTask?.cancel(); expiryTask = nil
        task?.cancel(); runner?.cancel(); server?.stop(); server = nil
        link = nil; port = nil; busy = false; progress = .initial
        if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
        temporaryDirectory = nil
    }
}
struct PhoneShareView: View {
    @Environment(\.dismiss) private var dismiss
    let movie: Movie
    @StateObject private var model = PhoneShareModel()
    @State private var subtitle = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Ver no iPhone", systemImage: "iphone.radiowaves.left.and.right").font(.title2.bold())
                Spacer()
                Button { model.stop(); dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
            }
            Text(movie.displayTitle).font(.headline)
            Text("Mac e iPhone na mesma rede. Instala o VLC no iPhone e mantém esta janela aberta durante a reprodução ou transferência.").foregroundStyle(.secondary)
            if model.link == nil {
                Picker("Legenda a incluir", selection: $subtitle) {
                    if movie.subtitles.isEmpty { Text("Primeira faixa interna (se existir)").tag("") }
                    ForEach(movie.subtitles, id: \.self) { path in Text(URL(fileURLWithPath: path).lastPathComponent).tag(path) }
                }.disabled(model.busy)
                if model.busy {
                    PreparationProgressView(progress: model.progress)
                    Text("Pode demorar e exige espaço livre equivalente ao vídeo. O original permanece intacto.").font(.caption).foregroundStyle(.secondary)
                    Button("Cancelar") { model.stop() }
                } else {
                    Button("Preparar vídeo com legendas") { model.prepare(movie, subtitle: subtitle.isEmpty ? nil : subtitle) }.buttonStyle(.borderedProminent).tint(.orange)
                }
            }
            if let error = model.error { Text(error).foregroundStyle(.orange).textSelection(.enabled).lineLimit(6) }
            if let link = model.link {
                PreparationProgressView(progress: model.progress)
                HStack(alignment: .center, spacing: 24) {
                    if let qr = qr(link.absoluteString) { Image(nsImage: qr).interpolation(.none).resizable().frame(width: 220, height: 220).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14)) }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Legendas verificadas", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("Lê o QR code com a câmara do iPhone e toca em Abrir no VLC. Também podes guardar o vídeo no VLC para ver offline.")
                        Text("A legenda está incluída como faixa predefinida. Se o VLC a ocultar por preferência, ativa “Legendas Cinema” no leitor.").font(.caption).foregroundStyle(.secondary)
                        Button("Copiar ligação") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link.absoluteString, forType: .string) }
                    }
                }
                if model.addresses.count > 1 {
                    Picker("Endereço do Mac", selection: $model.selectedAddress) { ForEach(model.addresses, id: \.self) { Text($0).tag($0) } }.onChange(of: model.selectedAddress) { _, _ in model.refreshLink() }
                }
                Text(link.absoluteString).font(.caption2).textSelection(.enabled).lineLimit(3)
                Text("Partilha apenas na rede local, válida durante 2 horas. Quem tiver esta ligação na rede pode ver este filme. Fechar a janela termina o acesso e remove a cópia temporária.").font(.caption).foregroundStyle(.secondary)
                Button("Terminar partilha") { model.stop() }
            }
        }.padding(30).frame(width: 680).preferredColorScheme(.dark)
            .onAppear { subtitle = movie.subtitles.first ?? "" }
            .onDisappear { model.stop() }
    }
    private func qr(_ text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8); filter.correctionLevel = "M"
        guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let cg = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: image.extent.width, height: image.extent.height))
    }
}
