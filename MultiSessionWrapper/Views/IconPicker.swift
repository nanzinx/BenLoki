import SwiftUI

/// Grade de ícones para escolher o símbolo da conta.
struct IconPicker: View {
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AccountIcon.all) { icon in
                let isSelected = icon.symbolName == selection
                Button {
                    selection = icon.symbolName
                } label: {
                    Image(systemName: icon.symbolName)
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                        .background(
                            isSelected ? Color.accentColor : Color(uiColor: .secondarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}
