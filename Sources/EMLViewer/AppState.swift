import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import EMLCore

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var message: Message?
    @Published var sourceURL: URL?
    @Published var errorText: String?

    private init() {}

    func open(_ url: URL) {
        do {
            let msg = try Message(url: url)
            self.message = msg
            self.sourceURL = url
            self.errorText = nil
        } catch {
            self.errorText = "Failed to open: \(error.localizedDescription)"
            self.message = nil
            self.sourceURL = url
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let eml = UTType(filenameExtension: "eml") {
            panel.allowedContentTypes = [eml]
        }
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    func saveAttachment(_ part: Part) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = part.filename ?? "attachment"
        if panel.runModal() == .OK, let url = panel.url {
            do { try part.decodedBody().write(to: url) }
            catch { NSSound.beep() }
        }
    }
}
