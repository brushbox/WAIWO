import SwiftUI

struct OverlayContentView: View {
    let displayState: DisplayState
    let upcomingTodos: [String]
    let hasLinks: Bool
    let staleDateText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch displayState {
            case .activeTodo(let text):
                HStack(spacing: 4) {
                    Text(text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                    if hasLinks {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue.opacity(0.7))
                    }
                }
                if let staleDateText {
                    Text(staleDateText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.orange)
                }
                ForEach(Array(upcomingTodos.enumerated()), id: \.offset) { index, todo in
                    Text(todo)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary.opacity(index == 0 ? 0.5 : 0.3))
                        .lineLimit(1)
                }
            case .allDone:
                Text("All done!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.green)
            case .noNotesFound:
                Text("No daily notes found")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minWidth: 300, maxWidth: 450, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(4) // outer padding so shadow isn't clipped
    }
}
