import SwiftUI

struct StatusBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(state.title)
                .font(.caption)
                .foregroundStyle(stateIsError ? Color.red : Color.secondary)
                .lineLimit(2)
        }
    }

    private var color: Color {
        switch state {
        case .idle: return .secondary
        case .ready: return .blue
        case .working: return .orange
        case .active: return .green
        case .failed: return .red
        }
    }

    private var stateIsError: Bool {
        if case .failed = state { return true }
        return false
    }
}
