import SwiftUI

struct InputView: View {
    enum Mode {
        case todo
        case journal
    }

    let mode: Mode
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(mode == .todo ? "New TODO" : "Journal Entry")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(mode == .todo ? "Enter to submit" : "⌘⏎ to submit")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            if mode == .todo {
                TextField("What are you working on?", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .focused($isFocused)
                    .onSubmit { submit() }
                    .onKeyPress(.escape) { cancel(); return .handled }
            } else {
                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(.clear)

                Button("Submit") { submit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .hidden()
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }

    private func cancel() {
        onCancel()
    }
}