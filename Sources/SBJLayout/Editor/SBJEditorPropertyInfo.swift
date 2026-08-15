import SwiftUI

@MainActor
struct SBJEditorPropertyInfoContainer: View {
    let content: AnyView
    let propertyName: String
    let info: SBJPropertyInfo?

    var body: some View {
        if let info {
            ZStack(alignment: .topTrailing) {
                content
                    .padding(.trailing, 30)
                SBJEditorPropertyInfoButton(propertyName: propertyName, info: info)
                    .padding(.top, 4)
                    .padding(.trailing, 4)
            }
        } else {
            content
        }
    }
}

@MainActor
private struct SBJEditorPropertyInfoButton: View {
    let propertyName: String
    let info: SBJPropertyInfo
    @State private var isPresented = false

    private var title: String {
        info.title ?? propertyName
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(info.accessibilityLabel ?? "Information about \(title)")
        .accessibilityHint(info.accessibilityHint ?? info.summary)
#if os(iOS)
        .popover(isPresented: $isPresented) {
            SBJEditorPropertyInfoSheet(title: title, info: info) {
                isPresented = false
            }
            .presentationCompactAdaptation(.popover)
        }
#else
        .sheet(isPresented: $isPresented) {
            SBJEditorPropertyInfoSheet(title: title, info: info) {
                isPresented = false
            }
        }
#endif
    }
}

@MainActor
private struct SBJEditorPropertyInfoSheet: View {
    let title: String
    let info: SBJPropertyInfo
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 12)
                Button("Done", action: dismiss)
            }

            Text(info.summary)
                .font(.headline)

            ScrollView {
                Text(info.details)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(idealWidth: 440, maxWidth: 520, idealHeight: 320, maxHeight: 520)
    }
}
