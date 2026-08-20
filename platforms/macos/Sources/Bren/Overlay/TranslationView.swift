import SwiftUI

struct TranslationView: View {
    @ObservedObject var state: TranslationState
    let onClose: () -> Void
    let onCopy: () -> Void
    let onTogglePin: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack {
            if state.isLoadingOrb {
                ProgressView()
                    .controlSize(.small)
                    .transition(.scale(scale: 0.55).combined(with: .opacity))
            } else {
                result
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .frame(width: state.preferredSize.width, height: state.preferredSize.height)
        .foregroundStyle(adaptiveForeground, adaptiveForeground.opacity(0.68))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: state.isLoadingOrb)
    }

    private var adaptiveForeground: Color {
        state.foregroundTone == .white ? .white : .black
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
                .opacity(isHovering || state.isPinned ? 1 : 0.52)
                .animation(.easeOut(duration: 0.14), value: isHovering)
            }
        }
    }

    @ViewBuilder
    private var output: some View {
        switch state.phase {
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.circle")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            ScrollView {
                Text(state.output)
                    .font(.system(size: 16.5, weight: .semibold))
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
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
