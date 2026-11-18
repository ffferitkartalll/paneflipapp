import PaneFlipCore
import SwiftUI
import UniformTypeIdentifiers

/// One screen: its name and size, then its layouts as cards and the card for adding another.
struct ScreenLayoutsSection: View {
    let screen: ScreenInfo
    /// How wide the picture of a layout of this display is drawn.
    let pictureWidth: CGFloat
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let editor: LayoutEditing
    @State private var choosesShape = false
    @State private var importing = false
    @State private var importFailed = false
    /// Where the row of layouts is scrolled to and how far it can go, to step it by one layout.
    @State private var position = ScrollPosition(x: 0)
    @State private var offset: CGFloat = 0
    @State private var maxOffset: CGFloat = 0

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    let all = repository.layouts(for: screen.key)
                    ForEach(all) { layout in
                        LayoutCard(screen: screen, pictureWidth: pictureWidth, layout: layout, defaultTitle: layout.defaultTitle(in: all),
                                   isDefault: repository.isDefault(layout: layout.id, key: screen.key), layouts: layouts, editor: editor)
                    }
                }
                .scrollTargetLayout()
                .fixedSize(horizontal: false, vertical: true)   // the row is as tall as its tallest card
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .scrollPosition($position)
            .scrollTargetBehavior(.viewAligned)   // let go anywhere, the row comes to rest on the nearest layout
            .onScrollGeometryChange(for: CGPoint.self) { CGPoint(x: $0.contentOffset.x, y: max($0.contentSize.width - $0.containerSize.width, 0)) } action: { _, now in
                offset = now.x
                maxOffset = now.y
            }
            // The wheel of a mouse moves the row by one layout for each notch, with the pointer over it and no Shift key.
            .background(WheelStepCatcher { notch in
                guard maxOffset > 0 else { return false }   // all the layouts show: the wheel scrolls the page
                let target = PagedScroll.offset(after: PagedScroll.notch(notch), from: offset, pitch: pictureWidth + 14, maxOffset: maxOffset)
                withAnimation(.smooth(duration: 0.25)) { position.scrollTo(x: target) }
                return true
            })
        } header: {
            HStack {
                Label(screen.name, systemImage: "display")
                Text(verbatim: "\(Int(screen.size.width))×\(Int(screen.size.height))").foregroundStyle(.secondary)
                Spacer()
                // Import to the left of Add, both at the right edge of the panel.
                footerButton("square.and.arrow.down", "Import") { importing = true }
                footerButton("plus", "Add") { choosesShape = true }
            }
        }
        .sheet(isPresented: $choosesShape) {
            LayoutPresetSheet(screen: screen, pictureWidth: pictureWidth) { preset, edit in
                let layout = layouts.addLayout(for: screen.key, preset: preset)
                if edit { editor.edit(on: screen, layoutID: layout.id) }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let opened = url.startAccessingSecurityScopedResource()
            defer { if opened { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let layout = try? NamedLayout.imported(from: data) {
                layouts.importLayout(for: screen.key, layout)
            } else {
                importFailed = true
            }
        }
        .alert("This file is not a layout.", isPresented: $importFailed) { Button("Done") {} }
    }

    private func footerButton(_ icon: String, _ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.body).frame(width: 24, height: 24).contentShape(.rect) }
            .buttonStyle(.plain)
            .hoverHighlight(radius: 6)
            .help(title)
            .accessibilityLabel(title)
    }
}
