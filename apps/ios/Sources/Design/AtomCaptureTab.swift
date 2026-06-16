import OpenClawChatUI
import SwiftUI

struct AtomCaptureTab: View {
    @Environment(NodeAppModel.self) private var appModel
    @State private var observationText = ""
    @State private var isSending = false
    @State private var statusText = "Ready to stage an observation"
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                CommandControlBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        self.header
                        self.captureHero
                        self.textCaptureCard
                        self.fastCaptureCard
                        self.stagingRulesCard
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 18)
                }
                .safeAreaPadding(.bottom, OpenClawProMetric.bottomScrollInset)
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(OpenClawBrand.accent, in: Circle())
                .shadow(color: OpenClawBrand.accent.opacity(0.24), radius: 12, y: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Capture")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("Stage the world around you for ATOM memory")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var captureHero: some View {
        CommandPanel(tint: OpenClawBrand.accent, isProminent: true, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("KG staging, not permanent memory", systemImage: "shield.lefthalf.filled")
                    .font(.headline.weight(.bold))
                Text(
                    "ATOM will treat captures as untrusted observations until they are reviewed or accepted by policy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    CaptureStatusPill(title: "Source", value: "iPhone", color: OpenClawBrand.accent)
                    CaptureStatusPill(title: "Mode", value: "Review", color: OpenClawBrand.warn)
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var textCaptureCard: some View {
        CommandPanel(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Text observation", systemImage: "text.badge.plus")
                    .font(.headline.weight(.bold))
                TextEditor(text: self.$observationText)
                    .font(.body)
                    .frame(minHeight: 126)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.primary.opacity(0.045))
                    }
                    .overlay {
                        if self.observationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Tell ATOM what to remember or what you are seeing...")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                if let errorText {
                    Text(errorText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(OpenClawBrand.danger)
                } else {
                    Text(self.statusText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Button(action: self.stageTextObservation) {
                    Label(self.isSending ? "Staging..." : "Stage with ATOM", systemImage: "tray.and.arrow.down.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(self.canStage ? OpenClawBrand.accent : Color.secondary.opacity(0.45))
                        }
                }
                .buttonStyle(.plain)
                .disabled(!self.canStage || self.isSending)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var fastCaptureCard: some View {
        CommandPanel(padding: 0) {
            VStack(spacing: 0) {
                CaptureActionRow(
                    icon: "mic.fill",
                    title: "Voice note",
                    detail: "Use Talk, then say: remember this.",
                    color: OpenClawBrand.accent)
                Divider().padding(.leading, 54)
                CaptureActionRow(
                    icon: "camera.fill",
                    title: "Photo",
                    detail: "Use ATOM Share for the first build.",
                    color: OpenClawBrand.warn)
                Divider().padding(.leading, 54)
                CaptureActionRow(
                    icon: "link",
                    title: "URL or file",
                    detail: "Share into ATOM staging.",
                    color: OpenClawBrand.ok)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var stagingRulesCard: some View {
        CommandPanel(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Memory rules", systemImage: "lock.doc.fill")
                    .font(.headline.weight(.bold))
                Text(
                    "Captures include source, timestamp, and review intent. "
                        + "ATOM should not turn them into durable KG facts until review accepts them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var canStage: Bool {
        !self.observationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func stageTextObservation() {
        Task { await self.sendObservation() }
    }

    private func sendObservation() async {
        let trimmed = self.observationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.isSending = true
        self.errorText = nil
        defer { self.isSending = false }

        let message = """
        ATOM KG capture request from iOS.

        Source: iPhone ATOM app
        Capture type: text_observation
        User intent: stage for review, not permanent memory yet

        Observation:
        \(trimmed)

        Please create a KG staging note with source, timestamp, modality, and confidence.
        Do not treat this as durable accepted memory until review/acceptance policy confirms it.
        """

        do {
            let transport = IOSGatewayChatTransport(gateway: self.appModel.operatorSession)
            _ = try await transport.sendMessage(
                sessionKey: self.appModel.chatSessionKey,
                message: message,
                thinking: "medium",
                idempotencyKey: UUID().uuidString,
                attachments: [])
            self.statusText = "Sent to ATOM for KG staging"
            self.observationText = ""
        } catch {
            self.errorText = "Could not stage capture: \(error.localizedDescription)"
        }
    }
}

private struct CaptureStatusPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(self.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(self.value)
                .font(.caption.weight(.bold))
                .foregroundStyle(self.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(self.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct CaptureActionRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: self.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(self.color)
                .frame(width: 32, height: 32)
                .background(self.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(.subheadline.weight(.semibold))
                Text(self.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
