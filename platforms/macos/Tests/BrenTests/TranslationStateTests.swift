import Testing
@testable import Bren

@MainActor
struct TranslationStateTests {
    @Test
    func loadingUsesCompactOrb() {
        let state = TranslationState()
        state.begin()
        #expect(state.isLoadingOrb)
        #expect(state.preferredSize == OverlayMetrics.loadingSize)
    }

    @Test
    func shortResultStaysCompact() {
        let state = TranslationState()
        state.begin()
        state.complete(text: "你好。")
        #expect(!state.isLoadingOrb)
        #expect(state.preferredSize.width == OverlayMetrics.minimumWidth)
        #expect(state.preferredSize.height == OverlayMetrics.minimumResultHeight)
    }

    @Test
    func longResultHonorsSizeBounds() {
        let state = TranslationState()
        state.begin()
        state.complete(text: String(repeating: "Liquid Glass 液态玻璃 ", count: 80))
        #expect(state.preferredSize.width <= OverlayMetrics.maximumWidth)
        #expect(state.preferredSize.height <= OverlayMetrics.maximumHeight)
    }

    @Test
    func pinTogglesWithoutChangingTranslation() {
        let state = TranslationState()
        state.begin()
        state.complete(text: "你好。")
        state.togglePinned()
        #expect(state.isPinned)
        #expect(state.output == "你好。")
        state.togglePinned()
        #expect(!state.isPinned)
    }
}
