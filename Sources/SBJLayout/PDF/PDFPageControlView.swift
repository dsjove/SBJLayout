#if !os(watchOS)
import SwiftUI
import SBJFoundation

/// Shared SwiftUI page-navigation and text-search chrome for an SBJLayout PDF controller.
///
/// Search is folded into the existing control so callers keep using the same
/// `PDFPageControlView(controller:)` integration point.
public struct PDFPageControlView<Controller: PDFPageNavigating & PDFTextSearching>: View {
    @Bindable var controller: Controller
    @FocusState private var searchFieldFocused: Bool

    public init(controller: Controller) {
        self.controller = controller
    }

    public var body: some View {
        HStack(spacing: 8) {
            if controller.isSearchPresented {
                searchControls
            } else {
                pageControls
            }
        }
    }

    @ViewBuilder
    private var pageControls: some View {
        let pageRange = controller.currentPage

        Button(action: controller.goToFirstPage) {
            Image(.system("backward.end"))
        }
        .accessibilityLabel("First Page")
        .disabled(!pageRange.canGoBackward)

        Button(action: controller.goToPreviousPage) {
            Image(.system("chevron.left"))
        }
        .accessibilityLabel("Previous Page")
        .disabled(!pageRange.canGoBackward)

        Text(pageRange.description)
            .monospacedDigit()
            .fixedSize()
            .accessibilityLabel(pageRange.pageAccessibilityLabel)

        Button(action: controller.goToNextPage) {
            Image(.system("chevron.right"))
        }
        .accessibilityLabel("Next Page")
        .disabled(!pageRange.canGoForward)

        Button(action: controller.goToLastPage) {
            Image(.system("forward.end"))
        }
        .accessibilityLabel("Last Page")
        .disabled(!pageRange.canGoForward)

        Button {
            controller.isSearchPresented = true
            focusSearchField()
        } label: {
            Image(.system("magnifyingglass"))
        }
        .accessibilityLabel("Search PDF")
    }

    @ViewBuilder
    private var searchControls: some View {
        TextField("Search PDF", text: $controller.searchQuery)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 120, idealWidth: 180, maxWidth: 220)
            .focused($searchFieldFocused)
            .submitLabel(.search)
            .onSubmit(controller.goToNextSearchMatch)
            .sbjActiveSearch(controller.isSearchActive, padding: 1)

        Text(searchMatchDescription)
            .monospacedDigit()
            .fixedSize()
            .accessibilityLabel(searchMatchAccessibilityLabel)

        Button(action: controller.goToPreviousSearchMatch) {
            Image(.system("chevron.up"))
        }
        .accessibilityLabel("Previous Search Result")
        .disabled(controller.searchMatchCount == 0)

        Button(action: controller.goToNextSearchMatch) {
            Image(.system("chevron.down"))
        }
        .accessibilityLabel("Next Search Result")
        .disabled(controller.searchMatchCount == 0)

        Button(action: closeSearch) {
            Image(.system("xmark"))
        }
        .accessibilityLabel("Close Search")
    }

    private var searchMatchDescription: String {
        guard !controller.searchQuery.isEmpty else { return "" }
        guard let current = controller.currentSearchMatchNumber,
              controller.searchMatchCount > 0
        else { return "0/0" }
        return "\(current)/\(controller.searchMatchCount)"
    }

    private var searchMatchAccessibilityLabel: String {
        guard !controller.searchQuery.isEmpty else { return "No search" }
        guard let current = controller.currentSearchMatchNumber,
              controller.searchMatchCount > 0
        else { return "No search results" }
        return "Search result \(current) of \(controller.searchMatchCount)"
    }

    private func closeSearch() {
        searchFieldFocused = false
        controller.clearSearch()
    }

    private func focusSearchField() {
        Task { @MainActor in
            await Task.yield()
            guard controller.isSearchPresented else { return }
            searchFieldFocused = true
        }
    }
}
#endif
