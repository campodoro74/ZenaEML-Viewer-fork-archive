import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct WelcomeView: View {
    @EnvironmentObject var state: AppState
    @State private var isDefault: Bool = false
    @State private var assocStatus: String? = nil
    @State private var working: Bool = false

    private let githubURL = URL(string: "https://github.com/noma4i/emlviewer")!

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)

            Image(systemName: "envelope.open")
                .font(.system(size: 54, weight: .ultraLight))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("EMLViewer")
                    .font(.system(size: 20, weight: .semibold))
                Text("Version \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Minimalist .eml viewer for macOS")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.horizontal, 60).padding(.vertical, 4)

            VStack(spacing: 10) {
                Button {
                    state.openPanel()
                } label: {
                    Label("Open .eml file…", systemImage: "folder")
                        .frame(width: 220)
                }
                .controlSize(.large)
                .keyboardShortcut("o")

                VStack(spacing: 6) {
                    associationRow
                    if let status = assocStatus {
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let err = state.errorText {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }

            Spacer(minLength: 8)

            footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: refreshAssociation)
    }

    // MARK: - Association row

    private var associationRow: some View {
        HStack(spacing: 8) {
            if isDefault {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Default for .eml files")
                    .font(.system(size: 12))
            } else {
                Button {
                    setAsDefault()
                } label: {
                    Label("Set as default for .eml", systemImage: "paperclip.badge.ellipsis")
                        .frame(width: 220)
                }
                .controlSize(.regular)
                .disabled(working)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                NSWorkspace.shared.open(githubURL)
            } label: {
                HStack(spacing: 5) {
                    githubIconView
                    Text("GitHub")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            )

            Text("MIT License · 2026 Alexander Tsirel")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var githubIconView: some View {
        if let url = Bundle.module.url(forResource: "github", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .frame(width: 12, height: 12)
        } else {
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 11))
        }
    }

    // MARK: - Logic

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var emlType: UTType? {
        UTType(filenameExtension: "eml") ?? UTType("public.email-message")
    }

    private func refreshAssociation() {
        guard let type = emlType else { isDefault = false; return }
        guard let bundleID = Bundle.main.bundleIdentifier else { isDefault = false; return }

        if let handlerURL = NSWorkspace.shared.urlForApplication(toOpen: type),
           let bundle = Bundle(url: handlerURL),
           bundle.bundleIdentifier == bundleID {
            isDefault = true
        } else {
            isDefault = false
        }
    }

    private func setAsDefault() {
        guard let type = emlType else {
            assocStatus = "UTType lookup failed"
            return
        }
        let appURL = Bundle.main.bundleURL
        working = true
        assocStatus = nil

        Task { @MainActor in
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type)
                assocStatus = "EMLViewer is now the default"
                refreshAssociation()
            } catch {
                assocStatus = "Could not set: \(error.localizedDescription)"
            }
            working = false
        }
    }
}
