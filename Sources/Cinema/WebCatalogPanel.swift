import SwiftUI
import CoreImage.CIFilterBuiltins

struct WebCatalogPanel: View {
    @ObservedObject var service: WebCatalog
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Cinema no iPhone", systemImage: "iphone.radiowaves.left.and.right").font(.title2.bold())
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.buttonStyle(.plain).help("Fechar painel")
            }
            Text("A tua biblioteca, favoritos e coleções, no Safari do iPhone. A reprodução continua no VLC, com legendas incluídas e verificadas.").foregroundStyle(.secondary)
            if service.starting { ProgressView("A abrir a tua sala na rede local…") }
            if let error = service.error { Text(error).foregroundStyle(.orange).font(.callout).textSelection(.enabled) }
            if let link = service.link, service.active {
                HStack(spacing: 24) {
                    if let qr = qr(link.absoluteString) { Image(nsImage: qr).interpolation(.none).resizable().frame(width: 210, height: 210).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16)) }
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Catálogo ativo", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("1. Liga o iPhone à mesma rede.\n2. Lê este QR code com a câmara.\n3. Escolhe um filme e a legenda.\n4. Prepara a cópia e toca em Abrir no VLC.").font(.callout).lineSpacing(5)
                        Button("Copiar URL") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link.absoluteString, forType: .string) }
                    }
                }
                if service.addresses.count > 1 {
                    Picker("Endereço do Mac", selection: $service.selectedAddress) { ForEach(service.addresses, id: \.self) { Text($0).tag($0) } }.onChange(of: service.selectedAddress) { _, _ in service.refreshLink() }
                }
                Text(link.absoluteString).font(.caption2).textSelection(.enabled).lineLimit(3)
                if !service.preparation.isEmpty, let progress = service.preparationProgress {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(service.preparation).font(.callout.bold()).lineLimit(1)
                        PreparationProgressView(progress: progress)
                    }.padding(16).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                }
                HStack {
                    Button("Limpar cópias temporárias") { confirmClear = true }
                    Spacer()
                    Button("Desativar catálogo") { service.stop() }
                }
            } else if !service.starting {
                Button("Ativar catálogo na rede Wi-Fi") { Task { await service.start() } }.buttonStyle(.borderedProminent).tint(.orange)
            }
            Divider()
            Text("O VLC deve estar instalado no iPhone. Mantém o Mac acordado, o Cinema aberto e o disco dos filmes ligado. Podes fechar este painel: o catálogo continua ativo até o desativares ou fechares a aplicação.").font(.caption).foregroundStyle(.secondary)
            Text("Acesso apenas pela rede local, protegido por uma ligação com código aleatório. Quem tiver o URL na rede pode consultar a biblioteca e alterar favoritos e coleções. Não partilhes o QR com outras pessoas. No Safari, usa Partilhar → Adicionar ao ecrã principal para guardar o ícone do Cinema.").font(.caption).foregroundStyle(.secondary)
        }.padding(30).frame(width: 680).preferredColorScheme(.dark)
        .alert("Limpar os filmes preparados?", isPresented: $confirmClear) {
            Button("Cancelar", role: .cancel) {}
            Button("Limpar cópias", role: .destructive) { service.clearPrepared() }
        } message: { Text("As ligações dos vídeos preparados deixam de funcionar. Os filmes originais e a biblioteca permanecem intactos.") }
    }
    private func qr(_ text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8); filter.correctionLevel = "M"
        guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let cg = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: image.extent.width, height: image.extent.height))
    }
}
