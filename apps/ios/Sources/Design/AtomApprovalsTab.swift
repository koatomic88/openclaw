import SwiftUI

struct AtomApprovalsTab: View {
    @Environment(NodeAppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            ZStack {
                CommandControlBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        self.header
                        self.pendingCard
                        self.boundariesCard
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
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(OpenClawBrand.warn, in: Circle())
                .shadow(color: OpenClawBrand.warn.opacity(0.24), radius: 12, y: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Approvals")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("You stay in control of risky actions")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var pendingCard: some View {
        CommandPanel(
            tint: self.appModel.pendingExecApprovalPrompt == nil ? nil : OpenClawBrand.warn,
            isProminent: self.appModel.pendingExecApprovalPrompt != nil,
            padding: 14)
        {
            if let prompt = self.appModel.pendingExecApprovalPrompt {
                VStack(alignment: .leading, spacing: 12) {
                    Label("ATOM needs approval", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(OpenClawBrand.warn)

                    Text(prompt.commandText)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 6) {
                        ApprovalMetadataLine(title: "Agent", value: prompt.agentId ?? self.appModel.activeAgentName)
                        ApprovalMetadataLine(title: "Host", value: prompt.host ?? "Gateway")
                        ApprovalMetadataLine(title: "Node", value: prompt.nodeId ?? "Current device")
                    }

                    if let errorText = self.appModel.pendingExecApprovalPromptErrorText,
                       !errorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        Text(errorText)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(OpenClawBrand.danger)
                    }

                    self.approvalButtons(allowsAllowAlways: prompt.allowsAllowAlways)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("No approvals waiting", systemImage: "checkmark.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(OpenClawBrand.ok)
                    Text(
                        "ATOM will pause here before sending messages, changing files, "
                            + "running risky commands, or touching money/security-sensitive systems.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private func approvalButtons(allowsAllowAlways: Bool) -> some View {
        VStack(spacing: 9) {
            Button {
                Task { await self.appModel.resolvePendingExecApprovalPrompt(decision: "allow-once") }
            } label: {
                Label("Allow Once", systemImage: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(self.appModel.pendingExecApprovalPromptResolving)

            if allowsAllowAlways {
                Button {
                    Task { await self.appModel.resolvePendingExecApprovalPrompt(decision: "allow-always") }
                } label: {
                    Label("Allow Always", systemImage: "checkmark.shield")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(self.appModel.pendingExecApprovalPromptResolving)
            }

            Button(role: .destructive) {
                Task { await self.appModel.resolvePendingExecApprovalPrompt(decision: "deny") }
            } label: {
                Label("Reject", systemImage: "xmark")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(self.appModel.pendingExecApprovalPromptResolving)
        }
        .controlSize(.large)
    }

    private var boundariesCard: some View {
        CommandPanel(padding: 12) {
            VStack(alignment: .leading, spacing: 9) {
                Label("Hard boundaries", systemImage: "lock.fill")
                    .font(.headline.weight(.bold))
                Text(
                    "External messages, destructive file changes, secrets, credentials, calendar sends, "
                        + "and any money/trading action must stay gated by approval.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }
}

private struct ApprovalMetadataLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(self.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            Text(self.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : self.value)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
