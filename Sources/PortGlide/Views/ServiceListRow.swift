import SwiftUI

struct ServiceListRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let state: ConnectionState
    let primaryTitle: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    var primaryDisabled = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                StatusBadge(state: state)
            }

            Spacer(minLength: 12)

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
            }
            if state.isActive {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.bordered)
                    .disabled(isWorking || primaryDisabled)
            } else {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || primaryDisabled)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var isWorking: Bool {
        if case .working = state { return true }
        return false
    }
}
