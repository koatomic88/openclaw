import SwiftUI

struct TalkProTab: View {
    @Environment(NodeAppModel.self) private var appModel
    @AppStorage("talk.enabled") private var talkEnabled: Bool = false
    @AppStorage(TalkSpeechLocale.storageKey) private var talkSpeechLocale: String = TalkSpeechLocale.automaticID
    @AppStorage(TalkDefaults.speakerphoneEnabledKey) private var talkSpeakerphoneEnabled: Bool =
        TalkDefaults.speakerphoneEnabledByDefault
    @AppStorage("talk.background.enabled") private var talkBackgroundEnabled: Bool = false
    @State private var showPermissionPrompt = false
    var openSettings: () -> Void

    private var state: TalkProState {
        TalkProState(
            gatewayConnected: self.gatewayConnected,
            isEnabled: self.appModel.talkMode.isEnabled || self.talkEnabled,
            statusText: self.appModel.talkMode.statusText,
            isListening: self.appModel.talkMode.isListening,
            isSpeaking: self.appModel.talkMode.isSpeaking,
            isUserSpeechDetected: self.appModel.talkMode.isUserSpeechDetected,
            permissionState: self.appModel.talkMode.gatewayTalkPermissionState)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CommandControlBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        self.header
                        self.voiceHeroCard
                        self.conversationCard
                        self.voiceModeCard
                        self.controlsCard
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 18)
                }
                .safeAreaPadding(.bottom, OpenClawProMetric.bottomScrollInset)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: self.$showPermissionPrompt) {
            NavigationStack {
                TalkPermissionPromptView(
                    style: .sheet,
                    onPermissionReady: {
                        self.showPermissionPrompt = false
                        self.startTalk()
                    })
                    .padding()
                    .navigationTitle("Enable Talk")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Not Now") {
                                self.showPermissionPrompt = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .openClawSheetChrome()
        }
        .onAppear { self.alignPersistedTalkState() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 11) {
            OpenClawProMark(size: 31, shadowRadius: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text("Talk")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text(self.headerSubtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            self.statusChip
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(self.state.color)
                .frame(width: 7, height: 7)
            Text(self.state.chipText)
                .font(.caption.weight(.bold))
                .foregroundStyle(self.state.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(self.state.color.opacity(0.11))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(self.state.color.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var voiceHeroCard: some View {
        CommandPanel(tint: self.state.color, isProminent: true, padding: 16) {
            VStack(alignment: .center, spacing: 16) {
                TalkProOrb(
                    mode: self.state.waveformMode(micLevel: self.appModel.talkMode.micLevel),
                    color: self.state.color,
                    systemImage: self.state.icon)
                    .frame(height: 188)
                    .accessibilityHidden(true)

                VStack(spacing: 5) {
                    Text(self.state.title)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(self.heroSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: self.handlePrimaryAction) {
                    Label(self.state.primaryButtonTitle, systemImage: self.state.primaryButtonIcon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(self.state.primaryButtonFill)
                                .shadow(color: self.state.color.opacity(0.28), radius: 18, y: 8)
                        }
                }
                .buttonStyle(.plain)
                .disabled(self.state.primaryAction == .waiting)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var conversationCard: some View {
        CommandPanel(padding: 0) {
            VStack(spacing: 0) {
                self.cardHeader(title: "Conversation", value: self.state.chipText, color: self.state.color)
                    .padding(.horizontal, 12)
                    .padding(.top, 11)
                    .padding(.bottom, 3)
                self.infoRow(icon: "person.crop.circle.fill", title: "Agent", value: self.appModel.activeAgentName)
                Divider().padding(.leading, 54)
                self.infoRow(
                    icon: "bubble.left.and.text.bubble.right.fill",
                    title: "Session",
                    value: self.appModel.chatSessionKey)
                Divider().padding(.leading, 54)
                self.infoRow(icon: self.state.icon, title: "Runtime", value: self.appModel.talkMode.statusText)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var voiceModeCard: some View {
        CommandPanel(padding: 0) {
            VStack(spacing: 0) {
                self.cardHeader(
                    title: "Voice mode",
                    value: "Settings ›",
                    color: OpenClawBrand.accent,
                    action: self.openSettings)
                    .padding(.horizontal, 12)
                    .padding(.top, 11)
                    .padding(.bottom, 3)
                self.infoRow(icon: "waveform", title: "Mode", value: self.appModel.talkMode.gatewayTalkVoiceModeTitle)
                Divider().padding(.leading, 54)
                self.infoRow(icon: "antenna.radiowaves.left.and.right", title: "Transport", value: self.transportText)
                Divider().padding(.leading, 54)
                self.infoRow(icon: "key.fill", title: "Permission", value: self.permissionText)
                Divider().padding(.leading, 54)
                self.infoRow(icon: "globe", title: "Speech language", value: self.speechLocaleText)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var controlsCard: some View {
        CommandPanel(padding: 0) {
            VStack(spacing: 0) {
                self.cardHeader(title: "Controls", value: nil, color: .secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 11)
                    .padding(.bottom, 3)
                Toggle("Speakerphone", isOn: self.$talkSpeakerphoneEnabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                Divider().padding(.leading, 14)
                Toggle("Background listening", isOn: self.$talkBackgroundEnabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                Divider().padding(.leading, 14)
                Button(action: self.openSettings) {
                    HStack {
                        Label("Voice & Talk settings", systemImage: "slider.horizontal.3")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private func cardHeader(
        title: String,
        value: String?,
        color: Color,
        action: (() -> Void)? = nil) -> some View
    {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer(minLength: 8)
            if let value {
                if let action {
                    Button(value, action: action)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                } else {
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
            }
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(self.state.color)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(self.state.color.opacity(0.11))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var gatewayConnected: Bool {
        GatewayStatusBuilder.build(appModel: self.appModel) == .connected
    }

    private var headerSubtitle: String {
        let mode = self.appModel.talkMode.gatewayTalkVoiceModeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let agent = self.appModel.activeAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode.isEmpty || mode == "Not loaded" { return agent.isEmpty ? "Realtime voice" : agent }
        if agent.isEmpty { return mode }
        return "\(agent) • \(mode)"
    }

    private var heroSubtitle: String {
        if self.state
            .prefersPermissionCopy { return "Gateway approval is required before this phone can capture voice." }
        if !self.gatewayConnected { return "Connect to your gateway to start a voice conversation." }
        let subtitle = (self.appModel.talkMode.gatewayTalkVoiceModeSubtitle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !subtitle.isEmpty { return subtitle }
        return "Routes voice to \(self.appModel.activeAgentName)."
    }

    private var transportText: String {
        let provider = self.appModel.talkMode.gatewayTalkProviderLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let transport = self.appModel.talkMode.gatewayTalkTransportLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider.isEmpty || provider == "Not loaded" { return transport.isEmpty ? "Not loaded" : transport }
        if transport.isEmpty || transport == "Not loaded" { return provider }
        return "\(provider) • \(transport)"
    }

    private var permissionText: String {
        if let failure = self.appModel.talkMode.gatewayTalkPermissionState.failureMessage {
            return failure
        }
        return self.appModel.talkMode.gatewayTalkPermissionState.statusLabel
    }

    private var speechLocaleText: String {
        if self.talkSpeechLocale == TalkSpeechLocale.automaticID { return "Automatic" }
        return self.talkSpeechLocale
    }

    private func alignPersistedTalkState() {
        if self.appModel.talkMode.gatewayTalkPermissionState.requiresTalkPermissionAction,
           self.talkEnabled || self.appModel.talkMode.isEnabled
        {
            self.stopTalk()
        } else if self.talkEnabled != self.appModel.talkMode.isEnabled {
            self.appModel.setTalkEnabled(self.talkEnabled)
        }
    }

    private func handlePrimaryAction() {
        switch self.state.primaryAction {
        case .start:
            self.startTalk()
        case .stop:
            self.stopTalk()
        case .enablePermission:
            self.stopTalk()
            self.showPermissionPrompt = true
        case .openSettings:
            self.openSettings()
        case .waiting:
            break
        }
    }

    private func startTalk() {
        self.talkEnabled = true
        self.appModel.setTalkEnabled(true)
    }

    private func stopTalk() {
        self.talkEnabled = false
        self.appModel.setTalkEnabled(false)
    }
}

enum TalkProPrimaryAction: Equatable {
    case start
    case stop
    case enablePermission
    case openSettings
    case waiting
}

enum TalkProWaveformMode: Equatable {
    case level(Double)
    case inputSpeech
    case speaking
    case indeterminate
    case still
}

struct TalkProState: Equatable {
    let gatewayConnected: Bool
    let isEnabled: Bool
    let statusText: String
    let isListening: Bool
    let isSpeaking: Bool
    let isUserSpeechDetected: Bool
    let permissionState: TalkGatewayPermissionState

    private var normalizedStatus: String {
        self.statusText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var title: String {
        if !self.gatewayConnected { return "Gateway offline" }
        switch self.permissionState {
        case .missingScope, .requestFailed:
            return "Gateway permission required"
        case .requestingUpgrade:
            return "Requesting approval"
        case .upgradeRequested:
            return "Approval requested"
        case .apiKeyMissing:
            return "Voice API key missing"
        case .loadFailed:
            return "Voice config failed"
        default:
            break
        }
        if self.isSpeaking { return "Speaking" }
        if self.isListening { return "Listening" }
        if self.normalizedStatus.contains("connecting") { return "Connecting" }
        if self.normalizedStatus.contains("thinking") { return "Asking ATOM" }
        if self.isEnabled { return "Ready to talk" }
        return "Talk is off"
    }

    var chipText: String {
        if !self.gatewayConnected { return "Offline" }
        switch self.permissionState {
        case .missingScope, .requestFailed:
            return "Needs approval"
        case .requestingUpgrade, .upgradeRequested:
            return "Pending"
        case .apiKeyMissing:
            return "API key"
        case .loadFailed:
            return "Config"
        default:
            break
        }
        if self.isSpeaking { return "Speaking" }
        if self.isListening { return "Listening" }
        if self.isEnabled { return "Ready" }
        return "Off"
    }

    var icon: String {
        if !self.gatewayConnected { return "wifi.slash" }
        switch self.permissionState {
        case .missingScope, .requestFailed:
            return "key.fill"
        case .requestingUpgrade:
            return "paperplane.fill"
        case .upgradeRequested:
            return "hourglass"
        case .apiKeyMissing, .loadFailed:
            return "exclamationmark.triangle.fill"
        default:
            break
        }
        if self.isSpeaking { return "speaker.wave.2.fill" }
        if self.isListening { return "mic.fill" }
        if self.normalizedStatus.contains("thinking") { return "sparkles" }
        if self.normalizedStatus.contains("connecting") { return "dot.radiowaves.left.and.right" }
        return "waveform"
    }

    var color: Color {
        if !self.gatewayConnected { return .secondary }
        switch self.permissionState {
        case .requestFailed, .loadFailed:
            return OpenClawBrand.danger
        case .missingScope, .requestingUpgrade, .upgradeRequested, .apiKeyMissing:
            return OpenClawBrand.warn
        default:
            return self.isEnabled ? OpenClawBrand.ok : OpenClawBrand.accentHot
        }
    }

    var primaryAction: TalkProPrimaryAction {
        if !self.gatewayConnected { return .openSettings }
        switch self.permissionState {
        case .missingScope, .requestFailed:
            return .enablePermission
        case .requestingUpgrade, .upgradeRequested:
            return .waiting
        case .apiKeyMissing, .loadFailed:
            return .openSettings
        default:
            return self.isEnabled ? .stop : .start
        }
    }

    var primaryButtonTitle: String {
        switch self.primaryAction {
        case .start: "Start Talk"
        case .stop: "Stop Talk"
        case .enablePermission: "Enable Talk"
        case .openSettings: self.gatewayConnected ? "Open Voice Control" : "Open Mac Link Control"
        case .waiting: "Waiting for Approval"
        }
    }

    var primaryButtonIcon: String {
        switch self.primaryAction {
        case .start: "play.fill"
        case .stop: "stop.fill"
        case .enablePermission: "key.fill"
        case .openSettings: "gearshape.fill"
        case .waiting: "hourglass"
        }
    }

    var primaryButtonFill: AnyShapeStyle {
        switch self.primaryAction {
        case .stop:
            AnyShapeStyle(OpenClawBrand.danger)
        case .waiting:
            AnyShapeStyle(OpenClawBrand.warn.opacity(0.72))
        default:
            AnyShapeStyle(LinearGradient(
                colors: [self.color.opacity(0.95), OpenClawBrand.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
        }
    }

    var prefersPermissionCopy: Bool {
        switch self.permissionState {
        case .missingScope, .requestingUpgrade, .upgradeRequested, .requestFailed:
            true
        default:
            false
        }
    }

    func waveformMode(micLevel: Double) -> TalkProWaveformMode {
        if !self.gatewayConnected { return .still }
        switch self.permissionState {
        case .requestingUpgrade, .upgradeRequested:
            return .indeterminate
        case .missingScope, .requestFailed, .apiKeyMissing, .loadFailed:
            return .still
        default:
            break
        }
        if self.isSpeaking { return .speaking }
        if self.isListening, self.isUserSpeechDetected { return .inputSpeech }
        if self.isListening { return .level(micLevel) }
        if self.normalizedStatus.contains("connecting") || self.normalizedStatus.contains("thinking") {
            return .indeterminate
        }
        return self.isEnabled ? .indeterminate : .still
    }
}

private struct TalkProOrb: View {
    let mode: TalkProWaveformMode
    let color: Color
    let systemImage: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let particles = TalkProOrbParticle.make(count: 118)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 14.0)) { timeline in
            Canvas { context, size in
                let time = self.reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                self.draw(in: &context, size: size, time: time)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let profile = self.motionProfile(time: time)
        let isSpeaking = profile.speechRipple > 0
        let layoutTime = isSpeaking ? 0 : time
        let fieldPulse = self.speechFieldPulse(time: time, profile: profile)
        let radius = min(size.width, size.height) * profile.spread * (1 + fieldPulse * profile.speechRipple * 3.75)
        let breath = 1 + profile.breathe * sin(time * profile.breatheSpeed)
        let rotation = layoutTime * profile.rotationSpeed
        context.blendMode = .plusLighter

        let sortedParticles = self.particles.sorted { lhs, rhs in
            self.depth(for: lhs, time: layoutTime, rotation: rotation)
                < self.depth(for: rhs, time: layoutTime, rotation: rotation)
        }

        for particle in sortedParticles {
            let point = self.project(
                particle,
                center: center,
                radius: radius,
                time: layoutTime,
                rotation: rotation,
                breath: breath,
                profile: profile)
            let depth = self.depth(for: particle, time: layoutTime, rotation: rotation)
            let perspective = 0.68 + depth * 0.36
            let activityWave = 0.5 + 0.5 * sin(layoutTime * profile.waveSpeed + Double(particle.baseY) * 1.8)
            let size = particle.size * profile.size * perspective
                * (0.88 + CGFloat(activityWave) * profile.sizePulse)
            let edgePresence = self.edgePresence(point: point, center: center, radius: radius)
            let listeningAlpha = profile.edgeBandBias > 0 ? (0.30 + edgePresence * 0.70) : 1
            let alpha = particle.alpha * profile.alpha * (0.52 + depth * 0.44)
                * Double(0.92 + CGFloat(activityWave) * 0.08)
                * listeningAlpha
            let haloRadius = size * (4.6 + profile.activity * 1.8 + fieldPulse * profile.speechRipple * 8)

            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - haloRadius,
                    y: point.y - haloRadius,
                    width: haloRadius * 2,
                    height: haloRadius * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        self.color.opacity(alpha * 0.18),
                        self.color.opacity(alpha * 0.04),
                        .clear,
                    ]),
                    center: point,
                    startRadius: 0,
                    endRadius: haloRadius))
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - size,
                    y: point.y - size,
                    width: size * 2,
                    height: size * 2)),
                with: .color(self.color.opacity(alpha)))
            if particle.isCore {
                let coreSize = max(0.75, size * 0.42)
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - coreSize,
                        y: point.y - coreSize,
                        width: coreSize * 2,
                        height: coreSize * 2)),
                    with: .color(Color.white.opacity(alpha * 0.48)))
            }
        }
    }

    private func project(
        _ particle: TalkProOrbParticle,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        rotation: Double,
        breath: CGFloat,
        profile: TalkProOrbMotionProfile) -> CGPoint
    {
        let cosR = CGFloat(cos(rotation))
        let sinR = CGFloat(sin(rotation))
        let flockTime = time * profile.waveSpeed
        let latitudeBand = CGFloat(sin(flockTime + Double(particle.baseY) * 2.0 + particle.phase * 0.10))
        let diagonalBand = CGFloat(cos(flockTime * 0.70 + Double(particle.baseX + particle.baseZ) * 1.6))
        let turningBand = CGFloat(sin(flockTime * 0.50 + particle.phase * 0.18))
        let listenPull = profile.listeningPull * latitudeBand * (0.40 + particle.shell * 0.60)
        let radial = breath * (1 + profile.activity * 0.018 * latitudeBand)
        let x = (particle.baseX * cosR - particle.baseZ * sinR) * radial
        let murmurationX = (-particle.baseY * latitudeBand + turningBand * 0.25) * profile.horizontalFlow
        let y = particle.baseY * radial + (diagonalBand * profile.verticalFlow) + listenPull
        let rawPoint = CGPoint(
            x: center.x + (x + murmurationX) * radius,
            y: center.y + y * radius)
        guard profile.edgeBandBias > 0 else { return rawPoint }
        let dx = rawPoint.x - center.x
        let dy = rawPoint.y - center.y
        let distance = max(0.0001, hypot(dx, dy))
        let target = radius * (0.72 + 0.06 * CGFloat(sin(time * 0.030 + particle.phase)))
        guard distance < target else { return rawPoint }
        let pull = min(profile.edgeBandBias, (target - distance) / max(1, target) * profile.edgeBandBias)
        let nextDistance = distance + (target - distance) * pull
        return CGPoint(
            x: center.x + dx / distance * nextDistance,
            y: center.y + dy / distance * nextDistance)
    }

    private func edgePresence(point: CGPoint, center: CGPoint, radius: CGFloat) -> Double {
        let distance = hypot(point.x - center.x, point.y - center.y)
        return Double(min(1, max(0, distance / max(1, radius * 0.70))))
    }

    private func speechFieldPulse(time: TimeInterval, profile: TalkProOrbMotionProfile) -> CGFloat {
        guard profile.speechRipple > 0 else { return 0 }
        let phrase = 0.30 + 0.70 * max(0, sin(time * 0.62 - .pi * 0.20))
        let syllable = pow(max(0, sin(time * 4.15)), 1.18)
        let emphasis = pow(max(0, sin(time * 2.05 + .pi * 0.24)), 2.0)
        let attack = pow(max(0, sin(time * 8.30 - .pi * 0.12)), 4.5) * 0.38
        let release = max(0, sin(time * 4.15 - .pi * 0.58)) * 0.30
        let sizeVariation = 0.72
            + 0.30 * (0.5 + 0.5 * sin(time * 0.91 + .pi * 0.31))
            + 0.16 * (0.5 + 0.5 * sin(time * 1.73 + .pi * 0.07))
        let pulse = phrase * (syllable * 0.74 + emphasis * 0.46 + release + attack) * sizeVariation
        return CGFloat(min(1.18, pulse))
    }

    private func depth(for particle: TalkProOrbParticle, time: TimeInterval, rotation: Double) -> CGFloat {
        let cosR = CGFloat(cos(rotation))
        let sinR = CGFloat(sin(rotation))
        let z = particle.baseX * sinR + particle.baseZ * cosR
        let softDrift = CGFloat(sin(time * 0.025 + Double(particle.baseY) * 1.6)) * 0.025
        return max(0, min(1, (z + 1 + softDrift) / 2))
    }

    private func motionProfile(time: TimeInterval) -> TalkProOrbMotionProfile {
        let base = TalkProOrbMotionProfile(
            activity: 0.10,
            spread: 0.34,
            alpha: 0.58,
            size: 1.0,
            breathe: 0.009,
            breatheSpeed: 0.030,
            rotationSpeed: 0.0011,
            driftSpeed: 0.0035,
            waveSpeed: 0.006,
            horizontalFlow: 0.0007,
            verticalFlow: 0.00055,
            listeningPull: 0,
            speechRipple: 0,
            edgeBandBias: 0,
            sizePulse: 0.012)

        switch self.mode {
        case .still:
            return base
        case .indeterminate:
            return base.adjusted(
                activity: 0.18,
                alpha: 0.72,
                breathe: 0.014,
                breatheSpeed: 0.052,
                rotationSpeed: 0.0024,
                driftSpeed: 0.008,
                waveSpeed: 0.015,
                horizontalFlow: 0.0016,
                verticalFlow: 0.0012,
                sizePulse: 0.026)
        case let .level(level):
            let clamped = min(max(level, 0), 1)
            return base.adjusted(
                activity: 0.20 + CGFloat(clamped) * 0.08,
                spread: 0.35 + CGFloat(clamped) * 0.010,
                alpha: 0.80,
                breathe: 0.018 + CGFloat(clamped) * 0.006,
                breatheSpeed: 0.080,
                rotationSpeed: 0.0045,
                driftSpeed: 0.018,
                waveSpeed: 0.032 + clamped * 0.010,
                horizontalFlow: 0.003,
                verticalFlow: 0.0022,
                listeningPull: 0.004 + CGFloat(clamped) * 0.003,
                edgeBandBias: 0.72,
                sizePulse: 0.038)
        case .inputSpeech:
            return base.adjusted(
                activity: 0.36,
                spread: 0.37,
                alpha: 0.88,
                size: 1.04,
                breathe: 0.026,
                breatheSpeed: 0.095,
                rotationSpeed: 0.006,
                driftSpeed: 0.022,
                waveSpeed: 0.045,
                horizontalFlow: 0.004,
                verticalFlow: 0.003,
                listeningPull: 0.010,
                edgeBandBias: 0.76,
                sizePulse: 0.055)
        case .speaking:
            return base.adjusted(
                activity: 0.22,
                spread: 0.38,
                alpha: 0.94,
                size: 1.10,
                breathe: 0.060,
                breatheSpeed: 2.05,
                rotationSpeed: 0,
                driftSpeed: 0,
                waveSpeed: 0,
                horizontalFlow: 0,
                verticalFlow: 0,
                speechRipple: 0.17,
                sizePulse: 0.020)
        }
    }
}

private struct TalkProOrbMotionProfile {
    let activity: CGFloat
    let spread: CGFloat
    let alpha: Double
    let size: CGFloat
    let breathe: CGFloat
    let breatheSpeed: Double
    let rotationSpeed: Double
    let driftSpeed: Double
    let waveSpeed: Double
    let horizontalFlow: CGFloat
    let verticalFlow: CGFloat
    let listeningPull: CGFloat
    let speechRipple: CGFloat
    let edgeBandBias: CGFloat
    let sizePulse: CGFloat

    func adjusted(
        activity: CGFloat? = nil,
        spread: CGFloat? = nil,
        alpha: Double? = nil,
        size: CGFloat? = nil,
        breathe: CGFloat? = nil,
        breatheSpeed: Double? = nil,
        rotationSpeed: Double? = nil,
        driftSpeed: Double? = nil,
        waveSpeed: Double? = nil,
        horizontalFlow: CGFloat? = nil,
        verticalFlow: CGFloat? = nil,
        listeningPull: CGFloat? = nil,
        speechRipple: CGFloat? = nil,
        edgeBandBias: CGFloat? = nil,
        sizePulse: CGFloat? = nil) -> TalkProOrbMotionProfile
    {
        TalkProOrbMotionProfile(
            activity: activity ?? self.activity,
            spread: spread ?? self.spread,
            alpha: alpha ?? self.alpha,
            size: size ?? self.size,
            breathe: breathe ?? self.breathe,
            breatheSpeed: breatheSpeed ?? self.breatheSpeed,
            rotationSpeed: rotationSpeed ?? self.rotationSpeed,
            driftSpeed: driftSpeed ?? self.driftSpeed,
            waveSpeed: waveSpeed ?? self.waveSpeed,
            horizontalFlow: horizontalFlow ?? self.horizontalFlow,
            verticalFlow: verticalFlow ?? self.verticalFlow,
            listeningPull: listeningPull ?? self.listeningPull,
            speechRipple: speechRipple ?? self.speechRipple,
            edgeBandBias: edgeBandBias ?? self.edgeBandBias,
            sizePulse: sizePulse ?? self.sizePulse)
    }
}

private struct TalkProOrbParticle {
    let baseX: CGFloat
    let baseY: CGFloat
    let baseZ: CGFloat
    let shell: CGFloat
    let phase: Double
    let size: CGFloat
    let alpha: Double
    let isCore: Bool

    static func make(count: Int) -> [TalkProOrbParticle] {
        guard count > 1 else { return [] }
        let increment = CGFloat.pi * (3 - sqrt(CGFloat(5)))
        return (0..<count).map { index in
            let progress = CGFloat(index) / CGFloat(count - 1)
            let y = 1 - progress * 2
            let radius = sqrt(max(0, 1 - y * y))
            let theta = CGFloat(index) * increment
            let shell = 0.52 + 0.48 * CGFloat((index * 17) % 29) / 28
            let phase = Double(index * 37).truncatingRemainder(dividingBy: 360) * .pi / 180
            let isCore = index % 11 == 0 || index < 8
            return TalkProOrbParticle(
                baseX: cos(theta) * radius * shell,
                baseY: y * shell,
                baseZ: sin(theta) * radius * shell,
                shell: shell,
                phase: phase,
                size: isCore ? 1.75 : 1.05 + CGFloat((index * 13) % 9) * 0.075,
                alpha: isCore ? 0.92 : 0.56 + Double((index * 19) % 10) * 0.035,
                isCore: isCore)
        }
    }
}

private struct TalkProWaveform: View {
    let mode: TalkProWaveformMode
    let tint: Color
    let barCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { timeline in
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<self.barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(self.tint.opacity(self.opacity(for: index)))
                        .frame(width: 4, height: self.height(for: index, date: timeline.date))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func height(for index: Int, date: Date) -> CGFloat {
        let minimum = 6.0
        let maximum = 48.0
        return CGFloat(minimum + ((maximum - minimum) * self.amplitude(for: index, date: date)))
    }

    private func opacity(for index: Int) -> Double {
        switch self.mode {
        case .still:
            index == self.barCount / 2 ? 0.64 : 0.30
        default:
            0.82
        }
    }

    private func amplitude(for index: Int, date: Date) -> Double {
        if self.reduceMotion {
            switch self.mode {
            case let .level(level): return min(max(level, 0.10), 1.0)
            case .inputSpeech: return 0.72
            case .speaking: return 0.62
            case .indeterminate: return 0.34
            case .still: return 0.18
            }
        }

        let t = date.timeIntervalSinceReferenceDate
        let phase = Double(index) * 0.52
        switch self.mode {
        case let .level(level):
            let clamped = min(max(level, 0), 1)
            let shaped = 0.12 + (0.88 * clamped)
            let variation = 0.72 + (0.28 * sin((t * 12.0) + phase))
            return min(max(shaped * variation, 0.10), 1.0)
        case .inputSpeech:
            let primary = 0.5 + (0.5 * sin((t * 14.0) + phase))
            let secondary = 0.5 + (0.5 * sin((t * 5.0) + (phase * 1.35)))
            return min(max(0.16 + (0.60 * primary) + (0.24 * secondary), 0.14), 1.0)
        case .speaking:
            let wave = 0.5 + (0.5 * sin((t * 7.5) + phase))
            let secondary = 0.5 + (0.5 * sin((t * 3.0) + (phase * 0.7)))
            return min(max(0.18 + (0.58 * wave) + (0.24 * secondary), 0.12), 1.0)
        case .indeterminate:
            let center = (sin((t * 3.2) + phase) + 1) / 2
            return 0.16 + (0.42 * center)
        case .still:
            return index == self.barCount / 2 ? 0.32 : 0.16
        }
    }
}
