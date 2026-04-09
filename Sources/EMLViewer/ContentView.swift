import SwiftUI
import AppKit
import UniformTypeIdentifiers
import EMLCore

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            if let msg = state.message {
                MessageView(message: msg)
            } else {
                DropZone()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url = url else { return }
            Task { @MainActor in state.open(url) }
        }
        return true
    }
}

struct DropZone: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.open")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.secondary)
            Text("Drop a .eml file here")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Open…") { state.openPanel() }
                .keyboardShortcut("o")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MessageView: View {
    let message: Message

    var body: some View {
        VStack(spacing: 0) {
            HeaderPanel(message: message)
            Divider()
            BodyView(message: message)
            if !message.attachments.isEmpty {
                Divider()
                AttachmentsBar(attachments: message.attachments)
            }
        }
    }
}

struct HeaderPanel: View {
    let message: Message
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.subject.isEmpty ? "(no subject)" : message.subject)
                .font(.title3).bold()
                .textSelection(.enabled)
            Text("From: \(message.from)").foregroundStyle(.secondary)
            Text("To: \(message.to)").foregroundStyle(.secondary)
            if !message.cc.isEmpty { Text("Cc: \(message.cc)").foregroundStyle(.secondary) }
            Text(message.date).foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct BodyView: View {
    let message: Message
    var body: some View {
        Group {
            if let html = message.htmlBody {
                WebView(html: html, message: message)
            } else if let plain = message.plainBody {
                ScrollView {
                    Text(plain)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .font(.system(.body, design: .monospaced))
                }
            } else {
                Text("(no body)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct AttachmentsBar: View {
    let attachments: [Part]
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(attachments.enumerated()), id: \.offset) { _, a in
                    Button(action: { state.saveAttachment(a) }) {
                        Label(a.filename ?? "attachment", systemImage: "paperclip")
                    }
                }
            }
            .padding(8)
        }
    }
}
