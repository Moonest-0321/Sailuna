import SwiftUI

/// 大綱與時間軸操作共用點擊範圍；保留系統的焦點與停用語意。
struct PlanningActionStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .frame(minWidth: 28, minHeight: prominent ? 32 : 30)
            .foregroundStyle(
                configuration.role == .destructive
                    ? Color.red
                    : (prominent ? Color.white : Color.primary)
            )
            .background(prominent ? Color.accentColor : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.22), lineWidth: prominent ? 0 : 1))
            .contentShape(Rectangle())
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.65 : 1))
    }
}
