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
            ToastOverlay()
        }
        .background(Color(nsColor: .textBackgroundColor))
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


// MARK: - Drop zone

struct DropZone: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.open")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("Drop a .eml file here")
                .font(.title3.weight(.regular))
                .foregroundStyle(.secondary)
            Button("Open…") { state.openPanel() }
                .controlSize(.large)
                .keyboardShortcut("o")
            if let err = state.errorText {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Toast

struct ToastOverlay: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack {
            Spacer()
            if let text = state.toast {
                Text(text)
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                if state.toast == text { state.toast = nil }
                            }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.toast)
        .allowsHitTesting(false)
    }
}

// MARK: - Message

struct MessageView: View {
    let message: Message

    var body: some View {
        VStack(spacing: 0) {
            HeaderPanel(message: message)
            Divider().opacity(0.6)
            BodyView(message: message)
            if !message.attachments.isEmpty {
                Divider().opacity(0.6)
                AttachmentsBar(attachments: message.attachments)
            }
        }
    }
}

struct HeaderPanel: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message.subject.isEmpty ? "(no subject)" : message.subject)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)
                .lineLimit(3)

            VStack(alignment: .leading, spacing: 3) {
                row("From", message.from)
                row("To",   message.to)
                if !message.cc.isEmpty { row("Cc", message.cc) }
                row("Date", message.date)
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                        .padding(18)
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

// MARK: - Attachments

struct AttachmentsBar: View {
    let attachments: [Part]
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(attachments.count) attachment\(attachments.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    state.downloadAll(attachments)
                } label: {
                    Label("Download All", systemImage: "arrow.down.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Save all attachments to Downloads")
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(attachments.enumerated()), id: \.offset) { _, a in
                        AttachmentChip(part: a)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

struct AttachmentChip: View {
    let part: Part
    @EnvironmentObject var state: AppState
    @State private var hovered = false

    var body: some View {
        Button(action: { state.openAttachment(part) }) {
            HStack(spacing: 10) {
                FileIcon(part: part)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(part.filename ?? "attachment")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 220, alignment: .leading)
                    Text(sizeString)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(hovered ? 0.45 : 0.18))
            )
            .shadow(color: .black.opacity(hovered ? 0.08 : 0.0), radius: 3, y: 1)
            .scaleEffect(hovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.12), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Open") { state.openAttachment(part) }
            Button("Save As…") { state.saveAsAttachment(part) }
        }
        .help("Open \(part.filename ?? "attachment")")
    }

    private var sizeString: String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(part.decodedBody().count))
    }
}

// MARK: - System file icon

struct FileIcon: NSViewRepresentable {
    let part: Part

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.image = icon()
        return v
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = icon()
    }

    private func icon() -> NSImage {
        let ws = NSWorkspace.shared
        if let name = part.filename {
            let ext = (name as NSString).pathExtension.lowercased()
            if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
                return ws.icon(for: type)
            }
        }
        if let type = UTType(mimeType: part.contentType) {
            return ws.icon(for: type)
        }
        return ws.icon(for: .data)
    }
}
