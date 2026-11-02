import SwiftUI
import AppKit

extension Notification.Name { static let cinemaFocusSearch = Notification.Name("Cinema.FocusSearch") }

struct LibraryToolbar: View {
    @EnvironmentObject private var library: Library
    let section: String
    @Binding var query: String
    @State private var focusRequest = 0
    var body: some View {
        HStack(spacing: 12) {
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? section : "Pesquisa").font(.system(size: 21, weight: .semibold))
            Spacer()
            if library.isScanning { ProgressView().controlSize(.small).help("A verificar o disco…") }
            else if library.busy { ProgressView().controlSize(.small).help("A obter dados do TMDB…") }
            NativeLibrarySearch(text: $query, focusRequest: focusRequest).frame(width: 270, height: 26)
            Button { library.scan() } label: { Image(systemName: "arrow.clockwise") }
                .help(library.isScanning ? "Pedir nova verificação após a atual" : "Atualizar ficheiros da biblioteca (⌘R)")
                .accessibilityLabel("Atualizar biblioteca")
            FullscreenControl().frame(width: 34, height: 26)
        }.padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 18)
            .onReceive(NotificationCenter.default.publisher(for: .cinemaFocusSearch)) { _ in focusRequest += 1 }
    }
}
struct NativeLibrarySearch: NSViewRepresentable {
    @Binding var text: String
    let focusRequest: Int
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Título, realizador ou nome do ficheiro"
        field.setAccessibilityLabel("Pesquisar na biblioteca")
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
        field.maximumRecents = 0
        field.delegate = context.coordinator
        return field
    }
    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text { field.stringValue = text }
        if context.coordinator.lastFocus != focusRequest {
            context.coordinator.lastFocus = focusRequest
            field.window?.makeKeyAndOrderFront(nil)
            NSApp.activate()
            field.window?.makeFirstResponder(field)
        }
    }
    @MainActor final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var lastFocus = 0
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField { text.wrappedValue = field.stringValue }
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) { return true }
            if selector == #selector(NSResponder.cancelOperation(_:)) { text.wrappedValue = ""; (control as? NSSearchField)?.stringValue = ""; return true }
            return false
        }
    }
}
struct FullscreenControl: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Alternar ecrã inteiro")!, target: context.coordinator, action: #selector(Coordinator.toggle(_:)))
        button.bezelStyle = .rounded
        button.imagePosition = .imageOnly
        button.toolTip = "Entrar ou sair do ecrã inteiro"
        button.setAccessibilityLabel("Alternar ecrã inteiro")
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {}
    @MainActor final class Coordinator: NSObject {
        @objc func toggle(_ sender: NSButton) {
            guard let window = sender.window else { return }
            window.collectionBehavior.remove([.fullScreenNone, .fullScreenAuxiliary])
            window.collectionBehavior.insert(.fullScreenPrimary)
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            window.toggleFullScreen(nil)
        }
    }
}
