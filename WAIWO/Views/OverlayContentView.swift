import SwiftUI

struct OverlayContentView: View {
    let displayState: DisplayState
    let staleDateText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch displayState {
            case .activeTodo(let text):
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                if let staleDateText {
                    Text(staleDateText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.orange)
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
        .padding(.vertical, 12)
        .frame(minWidth: 300, maxWidth: 450, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
