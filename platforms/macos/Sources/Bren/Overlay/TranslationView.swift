import AppKit
import SwiftUI

struct TranslationView: View {
    @ObservedObject var state: TranslationState
    let onClose: () -> Void
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onSubmitInput: (String) -> Void
    let onResize: (CGSize) -> Void
    let onResizeEnded: () -> Void

    @State private var isHovering = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            panelBackground

            if state.isLoadingOrb {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .transition(.scale(scale: 0.55).combined(with: .opacity))
            } else if state.isInputMode {
                inputPanel
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else {
                result
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white, .white.opacity(0.7))
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(
            cornerRadius: state.isLoadingOrb ? 22 : 24,
            style: .continuous
        ))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
        .onChange(of: state.isInputMode) { _, isInputMode in
            guard isInputMode else { return }
            Task { @MainActor in
                isInputFocused = true
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: state.isLoadingOrb)
    }

    private var panelBackground: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.82), location: 0),
                .init(color: .black.opacity(0.70), location: 0.48),
                .init(color: .black.opacity(0.78), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RoundedRectangle(cornerRadius: state.isLoadingOrb ? 22 : 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 0.7)
        }
    }

    private var result: some View {
        ZStack(alignment: .topTrailing) {
            output
                .padding(.leading, 16)
                .padding(.trailing, 48)
                .padding(.vertical, 15)

            if state.phase == .completed {
                HStack(spacing: 2) {
                    actionButton(
                        state.isPinned ? "pin.fill" : "pin",
                        label: state.isPinned ? "取消固定" : "固定",
                        emphasized: state.isPinned,
                        action: onTogglePin
                    )
                    actionButton("document.on.document", label: "复制", action: onCopy)
                    actionButton("xmark", label: "关闭", action: onClose)
                }
                .padding(.top, 9)
                .padding(.trailing, 9)
                .opacity(isHovering || state.isPinned ? 1 : 0)
                .animation(.easeOut(duration: 0.14), value: isHovering)
            }

            dragHandle
            resizeHandle
        }
    }

    private var inputPanel: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .topLeading) {
                if state.draft.isEmpty {
                    Text("输入中文或英文")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                        .padding(.top, 2)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: Binding(
                    get: { state.draft },
                    set: { value in state.updateDraft(value) }
                ))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .focused($isInputFocused)
                .onKeyPress(.return, phases: .down) { press in
                    guard !press.modifiers.contains(.shift) else { return .ignored }
                    submitInput()
                    return .handled
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 42)
            .padding(.top, 23)
            .padding(.bottom, 13)

            VStack(spacing: 5) {
                actionButton("xmark", label: "关闭", action: onClose)
                actionButton(
                    "arrow.up",
                    label: "翻译",
                    emphasized: !state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: submitInput
                )
                .disabled(state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 9)
            .padding(.trailing, 9)

            dragHandle
            resizeHandle
        }
    }

    private var dragHandle: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Color.clear
                    .frame(width: 48, height: 16)
                    .contentShape(Rectangle())
                    .gesture(WindowDragGesture())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.openHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .allowsWindowActivationEvents()
                Spacer()
            }
            Spacer()
        }
    }

    private var resizeHandle: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                Spacer()
                Color.clear
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in onResize(value.translation) }
                            .onEnded { _ in onResizeEnded() }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.frameResize(position: .bottomRight, directions: .all).set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .allowsWindowActivationEvents()
            }
        }
    }

    @ViewBuilder
    private var output: some View {
        switch state.phase {
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.circle")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            ScrollView {
                FormulaText(source: state.output)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func submitInput() {
        guard let text = state.submitInput() else { return }
        isInputFocused = false
        onSubmitInput(text)
    }

    private func actionButton(
        _ symbol: String,
        label: String,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(.primary.opacity(emphasized ? 0.18 : 0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
