import Testing
@testable import OpenClaw

@Suite struct SessionKeyTests {
    @Test func buildsCanonicalChannelSessionForAgent() {
        #expect(
            SessionKey.makeAgentSessionKey(
                agentId: "main",
                baseKey: "webchat:direct:openclaw-ios")
                == "agent:main:webchat:direct:openclaw-ios")
    }

    @Test func preservesCanonicalAndGlobalSessionKeys() {
        #expect(
            SessionKey.makeAgentSessionKey(
                agentId: "main",
                baseKey: "agent:main:telegram:direct:8771731961")
                == "agent:main:telegram:direct:8771731961")
        #expect(SessionKey.makeAgentSessionKey(agentId: "main", baseKey: "global") == "global")
    }
}
