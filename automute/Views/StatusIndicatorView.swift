import SwiftUI

struct StatusIndicatorView: View {
    let state: MonitoringState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorForStatus)
                .frame(width: 8, height: 8)

            Text(state.statusText)
                .font(.system(.body, design: .rounded))
        }
    }

    private var colorForStatus: Color {
        switch state.statusColor {
        case .green:
            return .green
        case .orange:
            return .orange
        case .red:
            return .red
        case .gray:
            return .gray
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        StatusIndicatorView(state: .active)
        StatusIndicatorView(state: .disabled)
        StatusIndicatorView(state: .idle(seconds: 154))
        StatusIndicatorView(state: .muted(reason: .inactivity))
        StatusIndicatorView(state: .screenLocked)
    }
    .padding()
}
