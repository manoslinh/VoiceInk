import SwiftUI

/// A menu for picking one or more transcription languages (or "Auto-detect").
///
/// "Auto-detect" is mutually exclusive with specific languages; selecting the
/// last remaining specific language off reverts to auto. The selection is read
/// from / written back as a comma-separated code string (e.g. "en,el").
struct MultiLanguageSelectionMenu: View {
    let availableLanguages: [String: String]
    let selection: String?
    let onChange: (String) -> Void

    private var sortedSpecificLanguages: [(key: String, value: String)] {
        availableLanguages
            .filter { $0.key != "auto" }
            .sorted { $0.value < $1.value }
            .map { (key: $0.key, value: $0.value) }
    }

    private var selectedCodes: Set<String> {
        Set(TranscriptionLanguageSupport.parseSelectedLanguages(selection).filter { $0 != "auto" })
    }

    private var isAuto: Bool {
        selectedCodes.isEmpty
    }

    private var summary: String {
        TranscriptionLanguageSupport.displaySummary(for: selection, available: availableLanguages)
    }

    var body: some View {
        Menu {
            Button {
                onChange("auto")
            } label: {
                menuRow(title: availableLanguages["auto"] ?? String(localized: "Auto-detect"), isOn: isAuto)
            }

            Divider()

            ForEach(sortedSpecificLanguages, id: \.key) { code, name in
                Button {
                    onChange(
                        TranscriptionLanguageSupport.toggling(
                            code,
                            in: selection,
                            available: availableLanguages
                        )
                    )
                } label: {
                    menuRow(title: name, isOn: selectedCodes.contains(code))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(summary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
            }
        }
    }

    @ViewBuilder
    private func menuRow(title: String, isOn: Bool) -> some View {
        HStack {
            Text(title)
            if isOn {
                Image(systemName: "checkmark")
            }
        }
    }
}
