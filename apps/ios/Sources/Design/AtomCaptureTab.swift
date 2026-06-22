import OpenClawChatUI
import OpenClawKit
import SwiftUI
import UIKit

struct AtomCaptureTab: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("talk.enabled") private var talkEnabled: Bool = false
    @AppStorage("atom.companion.speakerEnabled") private var speakerEnabled: Bool = true
    @AppStorage("atom.companion.wakeEnabled") private var wakeEnabled: Bool = false
    @AppStorage("atom.companion.translationEnabled") private var translationEnabled: Bool = false
    @State private var observationText = ""
    @State private var orbScale: CGFloat = 1
    @State private var isSending = false
    @State private var statusText = "Ready to route through Mac ATOM"
    @State private var errorText: String?
    @State private var activeSheet: AtomCompanionSheet?
    @State private var showChatModeChoices = false
    var openChat: () -> Void = {}
    var openTalk: () -> Void = {}
    var openOps: () -> Void = {}
    var openControl: () -> Void = {}

    private enum AtomCompanionSheet: Identifiable {
        case text
        case security
        case approvals
        case commandCenter

        var id: String {
            switch self {
            case .text: "text"
            case .security: "security"
            case .approvals: "approvals"
            case .commandCenter: "commandCenter"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                self.lapisBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        self.companionMenu
                        Spacer()
                        self.secureLinkStatus
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer(minLength: 0)

                    VStack(spacing: 16) {
                        KnowledgeOrbView(
                            scale: self.orbScale,
                            reduceMotion: self.reduceMotion,
                            isListening: self.appModel.talkMode.isListening || self.appModel.talkMode.isUserSpeechDetected,
                            isSpeaking: self.appModel.talkMode.isSpeaking)
                            .frame(width: 360, height: 360)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        self.orbScale = min(max(value, 0.82), 2.35)
                                    }
                                    .onEnded { value in
                                        withAnimation(.snappy(duration: 0.18)) {
                                            self.orbScale = min(max(value, 0.82), 2.35)
                                        }
                                    })
                    }
                    .offset(y: -10)

                    Spacer(minLength: 0)

                    self.orbHomeControls
                        .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .confirmationDialog("Chat with ATOM", isPresented: self.$showChatModeChoices, titleVisibility: .hidden) {
                Button("Text Chat") { self.openChat() }
                Button("Voice Chat") { self.openTalk() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: self.$activeSheet) { sheet in
                switch sheet {
                case .text:
                    self.atomTextSheet
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                case .security:
                    AtomCompanionSecuritySheet(
                        gatewayConnected: self.gatewayConnected,
                        deviceID: AtomCompanionSecureChannel.deviceID,
                        gatewayName: self.appModel.gatewayServerName,
                        gatewayAddress: self.appModel.gatewayRemoteAddress,
                        speakerEnabled: self.$speakerEnabled,
                        wakeEnabled: self.$wakeEnabled,
                        translationEnabled: self.$translationEnabled,
                        talkEnabled: Binding(
                            get: { self.appModel.talkMode.isEnabled },
                            set: { enabled in
                                self.talkEnabled = enabled
                                self.appModel.setTalkEnabled(enabled)
                            }))
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                case .approvals:
                    AtomApprovalsTab()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .commandCenter:
                    CommandCenterTab(
                        openChat: {
                            self.activeSheet = nil
                            self.openChat()
                        },
                        openSettings: {
                            self.activeSheet = nil
                            self.openControl()
                        })
                }
            }
        }
    }

    private var lapisBackground: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(red: 1, green: 0.72, blue: 0.20).opacity(0.14),
                    Color(red: 0.38, green: 0.22, blue: 0.04).opacity(0.06),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 24,
                endRadius: 430)
            RadialGradient(
                colors: [
                    Color(red: 1, green: 0.82, blue: 0.38).opacity(0.10),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.72),
                startRadius: 8,
                endRadius: 240)
        }
    }

    private var companionMenu: some View {
        Menu {
            Button(action: self.openChat) {
                Label("Open Text Chat", systemImage: "bubble.left.and.text.bubble.right.fill")
            }
            Button(action: self.openTalk) {
                Label("Open Voice", systemImage: "waveform.circle.fill")
            }
            Button { self.activeSheet = .text } label: {
                Label("Quick Capture", systemImage: "text.badge.plus")
            }
            Button { self.activeSheet = .approvals } label: {
                Label("Approvals", systemImage: "checkmark.shield.fill")
            }
            Button { self.activeSheet = .commandCenter } label: {
                Label("Command Center", systemImage: "command.circle.fill")
            }
            Button(action: self.openOps) {
                Label("Agent Ops", systemImage: "square.grid.2x2.fill")
            }
            Button(action: self.openControl) {
                Label("Control Settings", systemImage: "slider.horizontal.3")
            }
            Divider()
            Button {
                self.speakerEnabled.toggle()
            } label: {
                Label(
                    self.speakerEnabled ? "Speaker On" : "Speaker Off",
                    systemImage: self.speakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            Button {
                self.wakeEnabled.toggle()
            } label: {
                Label(
                    self.wakeEnabled ? "Wake Mode On" : "Wake Mode Off",
                    systemImage: self.wakeEnabled ? "dot.radiowaves.left.and.right" : "moon.zzz.fill")
            }
            Button {
                self.translationEnabled.toggle()
            } label: {
                Label(
                    self.translationEnabled ? "Translation On" : "Translation Off",
                    systemImage: self.translationEnabled ? "globe.asia.australia.fill" : "globe")
            }
            Divider()
            Button { self.activeSheet = .security } label: {
                Label("Pair Mac ATOM", systemImage: "lock.shield.fill")
            }
            Button { self.activeSheet = .security } label: {
                Label("Privacy & Audit", systemImage: "checkmark.shield.fill")
            }
        } label: {
            ClockworkGearCluster()
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ATOM controls")
    }

    private var secureLinkStatus: some View {
        Circle()
            .fill(self.attentionDotColor)
            .frame(width: self.hasAttention ? 9 : 7, height: self.hasAttention ? 9 : 7)
            .overlay {
                Circle()
                    .strokeBorder(self.attentionDotColor.opacity(0.34), lineWidth: 1)
                    .frame(width: 22, height: 22)
            }
            .shadow(color: self.attentionDotColor.opacity(self.hasAttention ? 0.95 : 0.48), radius: self.hasAttention ? 14 : 8)
            .frame(width: 32, height: 32)
        .contentShape(Rectangle())
        .onTapGesture { self.activeSheet = self.hasAttention ? .approvals : .security }
        .accessibilityLabel(self.hasAttention ? "ATOM attention needed" : "ATOM status")
    }

    private var orbHomeControls: some View {
        HStack(spacing: 18) {
            self.orbControlButton(
                icon: "bubble.left",
                label: "Chat",
                isActive: false,
                action: { self.showChatModeChoices = true })
            self.orbControlButton(
                icon: self.appModel.talkMode.isEnabled ? "mic.fill" : "mic",
                label: "Mic",
                isActive: self.appModel.talkMode.isEnabled,
                action: self.handleVoiceAction)
            self.orbControlButton(
                icon: "dot.radiowaves.left.and.right",
                label: "Auto",
                isActive: self.wakeEnabled,
                action: { self.wakeEnabled.toggle() })
        }
        .padding(.horizontal, 4)
    }

    private func orbControlButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? Color.black : Color(red: 1, green: 0.82, blue: 0.40))
                .frame(width: 42, height: 42)
                .background {
                    Circle()
                        .fill(isActive ? Color(red: 1, green: 0.76, blue: 0.28) : Color.black.opacity(0.36))
                        .overlay {
                            Circle()
                                .strokeBorder(Color(red: 1, green: 0.76, blue: 0.28).opacity(isActive ? 0.72 : 0.46), lineWidth: 1)
                        }
                }
                .shadow(color: Color(red: 1, green: 0.72, blue: 0.22).opacity(isActive ? 0.38 : 0.18), radius: 12, y: 6)
                .overlay(
                    Circle().strokeBorder(
                        Color.white.opacity(isActive ? 0.18 : 0.07),
                        lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: "atom")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.36))
                .frame(width: 34, height: 34)
                .background(Color.black, in: Circle())
                .overlay(Circle().strokeBorder(Color(red: 1, green: 0.75, blue: 0.26).opacity(0.36), lineWidth: 1))
                .shadow(color: Color(red: 1, green: 0.75, blue: 0.26).opacity(0.28), radius: 12, y: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("ATOM")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("Private companion for Praveen")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            self.presenceChip
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var captureHero: some View {
        CommandPanel(tint: Color(red: 1, green: 0.75, blue: 0.26), isProminent: true, padding: 16) {
            VStack(alignment: .center, spacing: 14) {
                KnowledgeOrbView(scale: self.orbScale, reduceMotion: self.reduceMotion)
                    .frame(height: 292)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                self.orbScale = min(max(value, 0.86), 2.25)
                            }
                            .onEnded { value in
                                withAnimation(.snappy(duration: 0.18)) {
                                    self.orbScale = min(max(value, 0.86), 2.25)
                                }
                            })
                VStack(spacing: 5) {
                    Text(self.presenceTitle)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(self.presenceSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 8) {
                    CaptureStatusPill(title: "Brain", value: "Mac ATOM", color: Color(red: 1, green: 0.75, blue: 0.26))
                    CaptureStatusPill(title: "Mode", value: self.presenceMode, color: self.presenceColor)
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var primaryControlsCard: some View {
        CommandPanel(padding: 12) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: self.openChat) {
                        Label("Text Chat", systemImage: "bubble.left.and.text.bubble.right.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(OpenClawBrand.accent)
                            }
                    }
                    .buttonStyle(.plain)

                    Button(action: self.openTalk) {
                        Label("Voice", systemImage: "waveform.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(self.presenceColor)
                            }
                    }
                    .buttonStyle(.plain)
                }

                Button { self.activeSheet = .security } label: {
                    Label("Pairing, permissions, device scopes, and approvals", systemImage: "lock.shield.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var presenceChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(self.presenceColor)
                .frame(width: 7, height: 7)
            Text(self.presenceMode)
                .font(.caption.weight(.bold))
                .foregroundStyle(self.presenceColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(self.presenceColor.opacity(0.11), in: Capsule(style: .continuous))
    }

    private var presenceTitle: String {
        if self.appModel.talkMode.isSpeaking { return "ATOM is speaking" }
        if self.appModel.talkMode.isUserSpeechDetected { return "ATOM hears you" }
        if self.appModel.talkMode.isListening { return "ATOM is listening" }
        if self.appModel.talkMode.isEnabled { return "ATOM is awake" }
        return "ATOM is standing by"
    }

    private var presenceSubtitle: String {
        if self.gatewayConnected {
            return "Text or voice routes through Mac ATOM, with useful traces staged for the KG."
        }
        return "Pair this iPhone to the Mac gateway to enable private voice, text, and KG capture."
    }

    private var presenceMode: String {
        if self.appModel.talkMode.isSpeaking { return "Speaking" }
        if self.appModel.talkMode.isUserSpeechDetected { return "Hearing" }
        if self.appModel.talkMode.isListening { return "Listening" }
        if self.translationEnabled { return "Translate" }
        if self.appModel.talkMode.isEnabled { return "Awake" }
        return self.gatewayConnected ? "Secure" : "Pair"
    }

    private var presenceColor: Color {
        if self.appModel.talkMode.isSpeaking { return OpenClawBrand.warn }
        if self.appModel.talkMode.isListening || self.appModel.talkMode.isUserSpeechDetected { return OpenClawBrand.ok }
        if self.gatewayConnected { return Color(red: 1, green: 0.75, blue: 0.26) }
        return .secondary
    }

    private var hasAttention: Bool {
        self.appModel.pendingExecApprovalPrompt != nil || !self.gatewayConnected
    }

    private var attentionDotColor: Color {
        self.hasAttention ? Color(red: 1, green: 0.76, blue: 0.28) : Color(red: 0.72, green: 0.58, blue: 0.25)
    }

    private var voiceButtonTitle: String {
        self.appModel.talkMode.isEnabled ? "Stop Voice" : "Talk"
    }

    private var voiceButtonIcon: String {
        self.appModel.talkMode.isEnabled ? "stop.fill" : "waveform"
    }

    private var gatewayConnected: Bool {
        GatewayStatusBuilder.build(appModel: self.appModel) == .connected
    }

    private func handleVoiceAction() {
        if self.appModel.talkMode.isEnabled {
            self.talkEnabled = false
            self.appModel.setTalkEnabled(false)
        } else {
            self.talkEnabled = true
            self.appModel.setTalkEnabled(true)
        }
    }

    private var atomTextSheet: some View {
        NavigationStack {
            ZStack {
                self.lapisBackground
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Text ATOM", systemImage: "keyboard.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.38))
                        Spacer()
                        self.secureTransportPill
                    }

                    TextEditor(text: self.$observationText)
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(minHeight: 180)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if self.observationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Send text to Mac ATOM over the paired channel...")
                                    .font(.body)
                                    .foregroundStyle(Color.white.opacity(0.46))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    Text(self.errorText ?? self.statusText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(self.errorText == nil ? Color.white.opacity(0.58) : OpenClawBrand.danger)

                    Button(action: self.stageTextObservation) {
                        Label(self.isSending ? "Sending..." : "Send", systemImage: "lock.shield.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(red: 0.02, green: 0.06, blue: 0.18))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                self.canStage
                                    ? Color(red: 1, green: 0.78, blue: 0.32)
                                    : Color.white.opacity(0.22),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!self.canStage || self.isSending)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { self.activeSheet = nil }
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }
        }
    }

    private var secureTransportPill: some View {
        Label(
            self.gatewayConnected ? "Secure" : "Pair",
            systemImage: self.gatewayConnected ? "lock.fill" : "lock.slash.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(self.gatewayConnected ? Color(red: 0.56, green: 1, blue: 0.70) : Color(red: 1, green: 0.78, blue: 0.32))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule(style: .continuous))
    }

    private var companionModesCard: some View {
        CommandPanel(padding: 0) {
            VStack(spacing: 0) {
                CaptureActionRow(
                    icon: "ear.and.waveform",
                    title: "Listening-only",
                    detail: "Wake or button controlled. ATOM speaks only when asked or when a permitted alert matters.",
                    color: OpenClawBrand.ok)
                Divider().padding(.leading, 54)
                CaptureActionRow(
                    icon: "globe.asia.australia.fill",
                    title: "World skills",
                    detail: "Translation, travel, maps, weather, and local recommendations route through ATOM.",
                    color: Color(red: 1, green: 0.75, blue: 0.26))
                Divider().padding(.leading, 54)
                CaptureActionRow(
                    icon: "person.badge.shield.checkmark.fill",
                    title: "Approval-gated actions",
                    detail: "Banking, security, and other high-trust skills require explicit permission and audit trails.",
                    color: OpenClawBrand.warn)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var securityCard: some View {
        CommandPanel(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Private by design", systemImage: "lock.doc.fill")
                    .font(.headline.weight(.bold))
                Text(
                    "The phone is a thin companion. Mac ATOM owns memory, model routing, permissions, and KG writeback. "
                        + "Sensitive app access should be explicit and scoped.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                            Text("Tell ATOM what to remember, validate, or route into the KG...")
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
                    Label(self.isSending ? "Sending..." : "Send to ATOM KG", systemImage: "tray.and.arrow.down.fill")
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

        guard let message = AtomCompanionSecureChannel.signedTextEnvelopeMessage(
            plaintext: trimmed,
            mode: self.translationEnabled ? "translation" : "text",
            gatewayConnected: self.gatewayConnected)
        else {
            self.errorText = "Pair this iPhone with Mac ATOM before sending trusted companion text."
            self.statusText = "Secure pairing required"
            return
        }

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

private struct AtomCompanionSecuritySheet: View {
    let gatewayConnected: Bool
    let deviceID: String
    let gatewayName: String?
    let gatewayAddress: String?
    @Binding var speakerEnabled: Bool
    @Binding var wakeEnabled: Bool
    @Binding var translationEnabled: Bool
    @Binding var talkEnabled: Bool
    @Environment(NodeAppModel.self) private var appModel
    @Environment(GatewayConnectionController.self) private var gatewayController
    @Environment(\.dismiss) private var dismiss
    @AppStorage("camera.enabled") private var cameraEnabled: Bool = true
    @AppStorage("location.enabledMode") private var locationModeRaw: String = OpenClawLocationMode.off.rawValue
    @AppStorage("screen.preventSleep") private var preventSleep: Bool = true
    @AppStorage("talk.background.enabled") private var talkBackgroundEnabled: Bool = false
    @AppStorage("talk.button.enabled") private var talkButtonEnabled: Bool = true
    @State private var setupCode = ""
    @State private var pairingStatus: String?
    @State private var showQRScanner = false
    @State private var isPairing = false
    @State private var isRetryingLink = false
    @State private var locationStatusText: String?
    @State private var previousLocationModeRaw: String = OpenClawLocationMode.off.rawValue

    private var hasOperatorToken: Bool {
        DeviceAuthStore.loadToken(deviceId: self.deviceID, role: "operator") != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                self.background
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        self.header
                        self.statusPanel
                        self.pairingPanel
                        self.coreControlsPanel
                        self.modePanel
                        self.voiceIdentityPanel
                        self.protocolPanel
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { self.dismiss() }
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }
            .fullScreenCover(isPresented: self.$showQRScanner) {
                QRScannerView(
                    onGatewayLink: { link in
                        self.showQRScanner = false
                        self.setupCode = ""
                        Task { await self.applyGatewayLink(link, source: "QR") }
                    },
                    onError: { message in
                        self.showQRScanner = false
                        self.pairingStatus = message
                    },
                    onDismiss: {})
                    .ignoresSafeArea()
            }
            .onAppear {
                self.previousLocationModeRaw = self.locationModeRaw
            }
            .onChange(of: self.locationModeRaw) { _, newValue in
                self.handleLocationModeChange(newValue)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.07, blue: 0.24),
                Color(red: 0.03, green: 0.12, blue: 0.36),
                Color(red: 0.01, green: 0.04, blue: 0.15),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("ATOM Secure Link", systemImage: "lock.shield.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.34))
            Text("Pair this iPhone to Mac ATOM. Text, transcript, translation, and approval events use a scoped signed envelope over the pinned gateway channel.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.statusLine(
                icon: self.hasOperatorToken ? "🔒" : "🔐",
                title: self.hasOperatorToken ? "Mac ATOM trusted" : "Pair Mac ATOM",
                value: self.gatewayConnected ? "Encrypted channel available" : "Scan or enter a Mac pairing code")
            self.statusLine(
                icon: "📱",
                title: "Device identity",
                value: String(self.deviceID.prefix(12)) + "...")
            self.statusLine(
                icon: "🧠",
                title: self.gatewayName ?? "Mac ATOM",
                value: self.gatewayAddress ?? "Waiting for paired gateway")
            if !self.gatewayConnected {
                Button {
                    Task { await self.retryMacLink() }
                } label: {
                    if self.isRetryingLink {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color(red: 1, green: 0.74, blue: 0.28))
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Retry Mac Link", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 1, green: 0.74, blue: 0.28))
                .disabled(self.isRetryingLink)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var pairingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pairing", systemImage: "qrcode.viewfinder")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.34))

            HStack(spacing: 10) {
                Button {
                    Task { await self.openQRScanner() }
                } label: {
                    Label("Scan QR", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1, green: 0.74, blue: 0.28))

                Button {
                    Task { await self.applySetupCode() }
                } label: {
                    if self.isPairing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Connect", systemImage: "bolt.horizontal.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .tint(Color.white.opacity(0.82))
                .disabled(self.isPairing)
            }

            TextField("Paste Mac ATOM setup code", text: self.$setupCode, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.footnote.monospaced())
                .foregroundStyle(.white)
                .lineLimit(2...4)
                .padding(12)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

            if let pairingStatus {
                Text(pairingStatus)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var modePanel: some View {
        VStack(spacing: 10) {
            self.toggleRow(emoji: "👂", title: "Listen", subtitle: "Speech capture is visibly controlled.", isOn: self.$talkEnabled)
            self.toggleRow(emoji: self.speakerEnabled ? "🔊" : "🔇", title: "Speaker", subtitle: "ATOM can speak responses aloud.", isOn: self.$speakerEnabled)
            self.toggleRow(emoji: "⚡", title: "Wake", subtitle: "Wake phrase mode stays explicit.", isOn: self.$wakeEnabled)
            self.toggleRow(emoji: "🌐", title: "Translate", subtitle: "Ambient translation is a separate mode.", isOn: self.$translationEnabled)
        }
        .padding(14)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var coreControlsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Core App Controls", systemImage: "slider.horizontal.3")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.34))

            self.toggleRow(
                emoji: "📷",
                title: "Camera tool",
                subtitle: "Allow ATOM to request camera capture while this app is open.",
                isOn: self.$cameraEnabled)
            self.toggleRow(
                emoji: "🔆",
                title: "Keep awake",
                subtitle: "Keep the iPhone screen awake while ATOM is open.",
                isOn: self.$preventSleep)
            self.toggleRow(
                emoji: "🛰️",
                title: "Background talk",
                subtitle: "Let active Talk sessions continue briefly in the background.",
                isOn: self.$talkBackgroundEnabled)
            self.toggleRow(
                emoji: "🎙️",
                title: "Talk button",
                subtitle: "Show the voice/talk controls in ATOM.",
                isOn: self.$talkButtonEnabled)

            VStack(alignment: .leading, spacing: 8) {
                self.statusLine(
                    icon: "📍",
                    title: "Location context",
                    value: self.locationModeTitle)
                Picker("Location context", selection: self.$locationModeRaw) {
                    Text("Off").tag(OpenClawLocationMode.off.rawValue)
                    Text("While Using").tag(OpenClawLocationMode.whileUsing.rawValue)
                    Text("Always").tag(OpenClawLocationMode.always.rawValue)
                }
                .pickerStyle(.segmented)
                .tint(Color(red: 1, green: 0.74, blue: 0.28))
                if let locationStatusText {
                    Text(locationStatusText)
                        .font(.caption)
                        .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.26))
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var voiceIdentityPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Voice Identity", systemImage: "waveform.and.person.filled")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.34))

            self.statusLine(
                icon: "🗣️",
                title: "Speaker labeling",
                value: "Mac ATOM labels transcript turns for the KG")
            self.statusLine(
                icon: "👤",
                title: "Praveen profile",
                value: self.hasOperatorToken ? "Ready for encrypted enrollment samples" : "Pair Mac ATOM first")
            self.statusLine(
                icon: "🧬",
                title: "Voiceprints",
                value: "Embeddings only; raw audio is not sent in trusted payloads")

            Text("Voice identity can enrich memory, meetings, and ambient observations, but Face ID/passcode remains the authority for sensitive actions.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var protocolPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Channel Rules", systemImage: "checkmark.shield.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.34))
            self.rule("wss:// only with Mac gateway identity pinned during pairing.")
            self.rule("Pairing and approval actions require Face ID or device passcode.")
            self.rule("Device key signs each event envelope.")
            self.rule("Message sequence, timestamp, mode, and scope block stale/replayed requests.")
            self.rule("High-risk actions require Face ID/passcode plus Mac ATOM policy.")
        }
        .padding(14)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }

    private func statusLine(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 11) {
            Text(icon)
                .font(.system(size: 17))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.56))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
    }

    private func toggleRow(emoji: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 11) {
                Text(emoji)
                    .font(.system(size: 17))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .tint(Color(red: 1, green: 0.74, blue: 0.28))
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(Color(red: 1, green: 0.74, blue: 0.28))
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @MainActor
    private func openQRScanner() async {
        if let error = await AtomBiometricGate.authorize(reason: "Confirm before pairing this iPhone with Mac ATOM.") {
            self.pairingStatus = "Pairing locked: \(error)"
            return
        }
        self.appModel.disconnectGateway()
        self.pairingStatus = "Opening secure scanner..."
        self.showQRScanner = true
    }

    private func applySetupCode() async {
        if let error = await AtomBiometricGate.authorize(reason: "Confirm before pairing this iPhone with Mac ATOM.") {
            self.pairingStatus = "Pairing locked: \(error)"
            return
        }
        let raw = self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            self.pairingStatus = "Paste a Mac ATOM setup code first."
            return
        }
        guard let link = GatewayConnectDeepLink.fromSetupInput(raw) else {
            self.pairingStatus = "That setup code was not recognized, or it points to an insecure remote gateway."
            return
        }
        await self.applyGatewayLink(link, source: "setup code")
    }

    @MainActor
    private func applyGatewayLink(_ link: GatewayConnectDeepLink, source: String) async {
        self.isPairing = true
        defer { self.isPairing = false }

        let instanceId = GatewaySettingsStore.currentInstanceID()
        let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)
        if setupAuth.hasBootstrapToken {
            GatewayOnboardingReset.prepareForBootstrapPairing(appModel: self.appModel, instanceId: instanceId)
        } else {
            self.appModel.disconnectGateway()
        }

        if !instanceId.isEmpty {
            GatewaySettingsStore.saveGatewayBootstrapToken(setupAuth.bootstrapToken, instanceId: instanceId)
            if setupAuth.shouldApplyTokenField {
                GatewaySettingsStore.saveGatewayToken(setupAuth.token, instanceId: instanceId)
            }
            if setupAuth.shouldApplyPasswordField {
                GatewaySettingsStore.saveGatewayPassword(setupAuth.password, instanceId: instanceId)
            }
        }

        self.pairingStatus = "Pairing with Mac ATOM from \(source)..."
        await self.gatewayController.connectManual(
            host: link.host,
            port: link.port,
            useTLS: link.tls,
            authOverride: setupAuth.manualAuthOverride,
            forceReconnect: true)
        self.pairingStatus = self.gatewayController.pendingTrustPrompt == nil
            ? "Pairing request sent. Approve on Mac ATOM if prompted."
            : "Verify the Mac gateway fingerprint to continue pairing."
    }

    @MainActor
    private func retryMacLink() async {
        guard !self.isRetryingLink else { return }
        self.isRetryingLink = true
        self.pairingStatus = "Retrying Mac ATOM link..."
        defer { self.isRetryingLink = false }
        self.appModel.gatewayPairingPaused = false
        self.appModel.gatewayPairingRequestId = nil
        await self.gatewayController.connectLastKnown()
        self.pairingStatus = self.gatewayConnected ? "Mac ATOM link restored." : "Retry sent. Keep ATOM open and approve on the Mac if prompted."
    }

    private var locationModeTitle: String {
        switch OpenClawLocationMode(rawValue: self.locationModeRaw) ?? .off {
        case .off:
            return "Off"
        case .whileUsing:
            return "While using"
        case .always:
            return "Always"
        }
    }

    private func handleLocationModeChange(_ newValue: String) {
        guard newValue != self.previousLocationModeRaw else { return }
        guard let mode = OpenClawLocationMode(rawValue: newValue) else { return }
        let previous = self.previousLocationModeRaw
        Task {
            await self.applyLocationMode(mode, rawValue: newValue, previous: previous)
        }
    }

    @MainActor
    private func applyLocationMode(_ mode: OpenClawLocationMode, rawValue: String, previous: String) async {
        self.locationStatusText = nil
        if mode == .off {
            self.previousLocationModeRaw = rawValue
            self.gatewayController.refreshActiveGatewayRegistrationFromSettings()
            return
        }

        let granted = await self.appModel.requestLocationPermissions(mode: mode)
        if granted {
            self.previousLocationModeRaw = rawValue
            self.gatewayController.refreshActiveGatewayRegistrationFromSettings()
        } else {
            self.locationModeRaw = previous
            self.previousLocationModeRaw = previous
            self.locationStatusText = "Location permission was not granted."
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

private struct ClockworkGearCluster: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = self.reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                self.gear(size: 17, teeth: 10)
                    .rotationEffect(.degrees(time * 12))
                    .offset(x: -5, y: -4)
                self.gear(size: 12, teeth: 9)
                    .rotationEffect(.degrees(-time * 18))
                    .offset(x: 8, y: 1)
                self.gear(size: 8, teeth: 8)
                    .rotationEffect(.degrees(time * 25))
                    .offset(x: -6, y: 8)
            }
            .frame(width: 34, height: 34)
            .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.34))
            .shadow(color: Color(red: 1, green: 0.72, blue: 0.22).opacity(0.28), radius: 8)
        }
    }

    private func gear(size: CGFloat, teeth: Int) -> some View {
        ZStack {
            GearShape(teeth: teeth)
                .stroke(lineWidth: max(1, size * 0.075))
                .frame(width: size, height: size)
            Circle()
                .stroke(lineWidth: max(1, size * 0.06))
                .frame(width: size * 0.34, height: size * 0.34)
        }
    }
}

private struct GearShape: Shape {
    let teeth: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.78
        let steps = max(6, self.teeth * 2)
        var path = Path()

        for index in 0...steps {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * CGFloat.pi / CGFloat(steps)
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct KnowledgeOrbView: View {
    let scale: CGFloat
    let reduceMotion: Bool
    var isListening = false
    var isSpeaking = false

    private let nodes: [KnowledgeOrbNode] = Self.makeNodes()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
        let time = self.reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
        self.draw(in: context, size: size, time: time)
            }
        }
    }

    private func draw(in originalContext: GraphicsContext, size: CGSize, time: TimeInterval) {
        var context = originalContext
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let stateBoost: CGFloat = self.isSpeaking ? 1.12 : (self.isListening ? 1.06 : 1)
        let radius = min(size.width, size.height) * 0.38 * self.scale * stateBoost
        let rotationY = 0.48 + time * (self.isSpeaking ? 0.13 : 0.075)
        let rotationX = -0.18 + sin(time * 0.04) * 0.04
        let projected = self.nodes.enumerated().map { index, node in
            let spherePoint = Self.fibonacciPoint(index: index, count: self.nodes.count)
            let rotated = Self.rotate(spherePoint, rotationX: rotationX, rotationY: rotationY)
            let depth = (rotated.z + 1) / 2
            let perspective = 0.66 + depth * 0.48
            let point = CGPoint(
                x: center.x + rotated.x * radius * perspective,
                y: center.y + rotated.y * radius * perspective)
            let nodeRadius = (0.55 + CGFloat(node.value) * 0.075 + sqrt(CGFloat(node.degree)) * 0.13)
                * perspective
                * sqrt(self.scale)
            return KnowledgeOrbProjectedNode(
                node: node,
                point: point,
                radius: nodeRadius,
                z: rotated.z,
                alpha: max(0.16, 0.22 + depth * 0.78))
        }

        self.drawAtmosphere(in: &context, center: center, radius: radius, time: time)

        context.blendMode = .plusLighter
        let sorted = projected.sorted(by: { $0.z < $1.z })
        self.drawConnections(in: &context, projected: sorted)

        for item in projected.sorted(by: { $0.z < $1.z }) where item.z > -0.92 {
            let haloRadius = item.radius * (self.isSpeaking ? 4.8 : 3.8)
            let haloRect = CGRect(
                x: item.point.x - haloRadius,
                y: item.point.y - haloRadius,
                width: haloRadius * 2,
                height: haloRadius * 2)
            context.fill(
                Path(ellipseIn: haloRect),
                with: .radialGradient(
                    Gradient(colors: [
                        item.node.color.opacity((self.isSpeaking ? 0.36 : 0.25) * item.alpha),
                        item.node.color.opacity(0.05 * item.alpha),
                        .clear,
                    ]),
                    center: item.point,
                    startRadius: 0,
                    endRadius: haloRadius))
            context.fill(
                Path(ellipseIn: CGRect(
                    x: item.point.x - item.radius,
                    y: item.point.y - item.radius,
                    width: item.radius * 2,
                    height: item.radius * 2)),
                with: .color(item.node.color.opacity(item.alpha)))
            context.fill(
                Path(ellipseIn: CGRect(
                    x: item.point.x - max(0.7, item.radius * 0.34),
                    y: item.point.y - max(0.7, item.radius * 0.34),
                    width: max(1.1, item.radius * 0.58),
                    height: max(1.1, item.radius * 0.58))),
                with: .color(Color.white.opacity(0.48 * item.alpha)))
        }

        guard self.scale > 1.36 else { return }
        let labeled = projected
            .filter { $0.z > -0.10 }
            .sorted { $0.node.value > $1.node.value }
            .prefix(self.scale > 1.9 ? 9 : 5)
        for item in labeled {
            let text = Text(item.node.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.50).opacity(item.alpha))
            context.draw(text, at: CGPoint(x: item.point.x + item.radius + 12, y: item.point.y))
        }
    }

    private func drawAtmosphere(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval) {
        context.blendMode = .plusLighter
        let pulse = self.isSpeaking ? 0.18 + 0.12 * sin(time * 7) : (self.isListening ? 0.11 + 0.04 * sin(time * 4) : 0)
        for index in 0..<5 {
            let progress = CGFloat(index) / 4
            let ringRadius = radius * (0.76 + progress * 0.18 + pulse)
            let ringRect = CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2)
            context.stroke(
                Path(ellipseIn: ringRect),
                with: .color(Color(red: 1, green: 0.78, blue: 0.32).opacity(0.03 + (self.isListening || self.isSpeaking ? 0.05 : 0.015))),
                lineWidth: 0.7)
        }
        context.stroke(
            Path(ellipseIn: CGRect(
                x: center.x - radius * 0.93,
                y: center.y - radius * 0.93,
                width: radius * 1.86,
                height: radius * 1.86)),
            with: .color(Color(red: 1, green: 0.78, blue: 0.32).opacity(self.isSpeaking ? 0.28 : 0.16)),
            lineWidth: self.isSpeaking ? 1.2 : 0.8)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius * 1.12,
                y: center.y - radius * 1.12,
                width: radius * 2.24,
                height: radius * 2.24)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1, green: 0.78, blue: 0.32).opacity(self.isSpeaking ? 0.18 : 0.12),
                    Color(red: 1, green: 0.58, blue: 0.18).opacity(0.055),
                    .clear,
                ]),
                center: center,
                startRadius: 4,
                endRadius: radius * 1.14))
    }

    private func drawConnections(in context: inout GraphicsContext, projected: [KnowledgeOrbProjectedNode]) {
        let visible = projected.filter { $0.z > -0.34 }
        guard visible.count > 3 else { return }
        for index in visible.indices {
            let item = visible[index]
            for otherIndex in visible.indices where otherIndex > index {
                let other = visible[otherIndex]
                let dx = item.point.x - other.point.x
                let dy = item.point.y - other.point.y
                let distance = sqrt(dx * dx + dy * dy)
                let threshold = CGFloat(item.node.degree + other.node.degree) * 2.15
                guard distance < threshold, (item.node.seed + other.node.seed + index + otherIndex).isMultiple(of: 5) else {
                    continue
                }
                var path = Path()
                path.move(to: item.point)
                path.addLine(to: other.point)
                let alpha = max(0, 1 - distance / threshold) * 0.20 * min(item.alpha, other.alpha)
                context.stroke(
                    path,
                    with: .color(Color(red: 1, green: 0.75, blue: 0.26).opacity(alpha)),
                    lineWidth: 0.55)
            }
        }
    }

    private static func makeNodes() -> [KnowledgeOrbNode] {
        let anchors: [KnowledgeOrbNode] = [
            .init(label: "ATOM", kind: .core, degree: 28, value: 10, seed: 1),
            .init(label: "Memory", kind: .core, degree: 23, value: 9, seed: 2),
            .init(label: "Skills", kind: .skill, degree: 21, value: 9, seed: 3),
            .init(label: "Projects", kind: .project, degree: 20, value: 8, seed: 4),
            .init(label: "Agents", kind: .agent, degree: 19, value: 8, seed: 5),
            .init(label: "World", kind: .source, degree: 16, value: 7, seed: 6),
            .init(label: "Decisions", kind: .decision, degree: 15, value: 7, seed: 7),
            .init(label: "Preferences", kind: .preference, degree: 14, value: 7, seed: 8),
            .init(label: "Tasks", kind: .task, degree: 13, value: 6, seed: 9),
            .init(label: "Evidence", kind: .source, degree: 12, value: 6, seed: 10),
        ]
        let kinds: [KnowledgeOrbKind] = [.source, .task, .skill, .project, .lesson, .agent, .decision, .preference]
        let generated = (0..<360).map { index in
            let kind = kinds[index % kinds.count]
            let degree = 3 + ((index * 7 + 11) % 18)
            let value = 2 + ((index * 5 + 3) % 7)
            return KnowledgeOrbNode(label: "Node \(index + 1)", kind: kind, degree: degree, value: value, seed: index + 20)
        }
        return anchors + generated
    }

    private static func fibonacciPoint(index: Int, count: Int) -> KnowledgeOrbPoint {
        guard count > 1 else { return KnowledgeOrbPoint(x: 0, y: 0, z: 1) }
        let offset = CGFloat(2) / CGFloat(count)
        let increment = CGFloat.pi * (3 - sqrt(CGFloat(5)))
        let y = CGFloat(index) * offset - 1 + offset / 2
        let r = sqrt(max(0, 1 - y * y))
        let phi = CGFloat(index) * increment
        return KnowledgeOrbPoint(x: cos(phi) * r, y: y, z: sin(phi) * r)
    }

    private static func rotate(
        _ point: KnowledgeOrbPoint,
        rotationX: CGFloat,
        rotationY: CGFloat) -> KnowledgeOrbPoint
    {
        let cosX = cos(rotationX)
        let sinX = sin(rotationX)
        let cosY = cos(rotationY)
        let sinY = sin(rotationY)
        let y1 = point.y * cosX - point.z * sinX
        let z1 = point.y * sinX + point.z * cosX
        return KnowledgeOrbPoint(x: point.x * cosY + z1 * sinY, y: y1, z: -point.x * sinY + z1 * cosY)
    }
}

private struct KnowledgeOrbPoint {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

private struct KnowledgeOrbNode {
    let label: String
    let kind: KnowledgeOrbKind
    let degree: Int
    let value: Int
    let seed: Int

    var color: Color {
        self.kind.color
    }
}

private struct KnowledgeOrbProjectedNode {
    let node: KnowledgeOrbNode
    let point: CGPoint
    let radius: CGFloat
    let z: CGFloat
    let alpha: CGFloat
}

private enum KnowledgeOrbKind {
    case core
    case agent
    case skill
    case project
    case decision
    case preference
    case lesson
    case task
    case source

    var color: Color {
        switch self {
        case .core:
            Color(red: 1, green: 0.96, blue: 0.72)
        case .agent, .skill, .project:
            Color(red: 1, green: 0.82, blue: 0.36)
        case .decision, .preference:
            Color(red: 1, green: 0.70, blue: 0.26)
        case .lesson, .task:
            Color(red: 0.96, green: 0.74, blue: 0.34)
        case .source:
            Color(red: 1, green: 0.88, blue: 0.52)
        }
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
