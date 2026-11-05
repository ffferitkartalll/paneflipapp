import AppKit
import PaneFlipCore
import SwiftUI

struct EditorView: View {
    let model: EditorModel
    /// The area zones are laid out in, in points: one screen's width of the editor stands for it.
    let area: CGSize
    @State private var showShapes = false
    @State private var showSpacing = false
    /// Within this many points of the centre, a new or dragged divider snaps to exactly 50 %.
    private let snapDistance: CGFloat = 20
    @Environment(\.displayScale) private var displayScale
    /// How far from the middle of the line being dragged it was taken, along its axis.
    @State private var grab: (line: UUID, offset: CGFloat)?
    /// The line being dragged is on a step.
    @State private var snappedLine = false

    var body: some View {
        GeometryReader { geo in
            // The strip is drawn at full size, one screen of it in view; the rest lies to the left and to the right, out of the panel.
            let total = CGFloat(model.strip.totalWidth)
            let rect = CGRect(x: -CGFloat(model.strip.leadingWidth + model.offset) * geo.size.width, y: 0,
                              width: total * geo.size.width, height: geo.size.height)
            let screenRect = CGRect(x: rect.minX + CGFloat(model.strip.leadingWidth) * geo.size.width, y: 0, width: geo.size.width, height: geo.size.height)
            let laid = model.laid(in: rect, screen: screenRect)
            let zones = laid.zones.enumerated().map { ZoneRect(id: $1.id, index: $0, rect: $1.rect) }
            let dividers = laid.dividers
            let target = splitTarget(zones: zones, dividers: dividers, size: geo.size)

            ZStack(alignment: .topLeading) {
                Color.black

                ForEach(zones) { z in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: max(z.rect.width - 6, 0), height: max(z.rect.height - 6, 0))
                        .overlay(alignment: .topLeading) {
                            Text(verbatim: label(of: z.id)).font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.5)).padding(12)
                        }
                        .overlay {
                            // Under the pointer the zone shows what a split there would leave (see `splitLabels`), not its whole size.
                            if target?.zone.id != z.id {
                                // The line being dragged, on a step: the zone beside it that is one whole side of it says its share under its size.
                                let step = draggedShare(of: z.id, dividers: dividers)
                                ZoneSizeLabel(size: EditorModel.size(of: z.rect, in: geo.size, area: area), share: step)
                            }
                        }
                        .offset(x: z.rect.minX + 3, y: z.rect.minY + 3)
                        .allowsHitTesting(false)
                }

                if total > 1 { screenFrames(rect, total: total) }

                // Empty space: hovering previews a split, clicking performs it.
                Color.clear.contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let p): if model.mergeSource == nil { model.hover = p }
                        case .ended: model.hover = nil
                        }
                    }
                    .gesture(SpatialTapGesture().onEnded { value in
                        model.shift = NSEvent.modifierFlags.contains(.shift)
                        if let t = splitTarget(at: value.location, zones: zones, dividers: dividers, size: geo.size), t.valid {
                            model.split(t.zone.id, sideBySide: t.sideBySide, ratio: t.ratio)
                        }
                    })
                    .simultaneousGesture(mergeDrag(zones: zones, area: rect))

                if let m = mergePreview(zones: zones, area: rect) {
                    mergeOverlay(m)
                }

                if let t = target { splitLabels(t, view: geo.size) }

                if let t = target {
                    Path { p in p.move(to: t.line.0); p.addLine(to: t.line.1) }
                        .stroke(t.valid ? (t.snapped ? Color.white : AppAccent.color) : Color.red,
                                lineWidth: t.snapped ? 3 : 2)
                        .allowsHitTesting(false)
                }

                // The edge of an area is not a line to drag: a screen has the width of the screen.
                // All lines first, then all handles: another divider's line must not run over a handle.
                let lines = dividers.filter { !model.isAreaLine($0.id) }
                ForEach(lines) { d in lineView(d, in: rect) }
                ForEach(lines) { d in handleView(d, in: rect) }

                ForEach(zones.filter { model.strip.part(of: $0.id) == .screen }) { z in defaultButton(z) }

                controls
                overflowButtons(size: geo.size)
            }
            .animation(.smooth(duration: 0.4), value: model.offset)
            .coordinateSpace(name: "editor")
        }
    }

    /// A star in the bottom left corner of each zone of the screen, as far from the left edge as from the bottom one: the filled one is the default zone, which takes the apps whose zone is gone.
    private func defaultButton(_ z: ZoneRect) -> some View {
        let on = model.effectiveDefaultZone == z.id
        let side: CGFloat = 32, gap: CGFloat = 12
        return Button { model.setDefaultZone(z.id) } label: { Image(systemName: on ? "star.fill" : "star") }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .frame(width: side, height: side)
            .help("Default zone")
            // The zone is drawn 3 points inside its rectangle; the button is a square, so both gaps are `gap`.
            .position(x: z.rect.minX + 3 + gap + side / 2, y: z.rect.maxY - 3 - gap - side / 2)
    }

    // MARK: Areas beyond the screen

    /// Zones are named as everywhere else: 1, 2, 3 on the screen, -1, -2 beyond the left edge, +1, +2 beyond the right one.
    private func label(of zone: UUID) -> String { ZoneLabel.text(of: zone, in: model.strip) }

    /// Every screen of the strip, the screen itself and each one beyond its edges, has the same dashed frame.
    private func screenFrames(_ rect: CGRect, total: CGFloat) -> some View {
        var spans = [(start: Double, width: Double)(model.strip.leadingWidth, 1)]
        var reached = model.strip.leadingWidth
        for area in model.strip.leading { spans.append((reached - area.width, area.width)); reached -= area.width }
        reached = model.strip.leadingWidth + 1
        for area in model.strip.trailing { spans.append((reached, area.width)); reached += area.width }
        return ZStack(alignment: .topLeading) {
            ForEach(spans.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .frame(width: CGFloat(spans[i].width) / total * rect.width, height: rect.height)
                    .offset(x: rect.minX + CGFloat(spans[i].start) / total * rect.width, y: rect.minY)
            }
        }
        .allowsHitTesting(false)
    }

    /// A plus button stands at an edge only where there is no screen beyond it: the view is at the outermost screen on that side.
    private func overflowButtons(size: CGSize) -> some View {
        ZStack {
            if model.canAddLeading {
                Button { model.addLeading() } label: { Image(systemName: "plus") }
                    .help("Add a screen on the left")
                    .position(x: 32, y: size.height / 2)
            }
            if model.canAddTrailing {
                Button { model.addTrailing() } label: { Image(systemName: "plus") }
                    .help("Add a screen on the right")
                    .position(x: size.width - 32, y: size.height / 2)
            }
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }

    // MARK: Controls

    private var shapes: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(LayoutPreset.suggested(for: area)) { preset in
                    Button {
                        model.useShape(preset)
                        showShapes = false
                    } label: {
                        LayoutMiniature(root: preset.root, screenSize: area, width: 120)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
        .frame(width: 440, height: 380)
    }

    /// The gap, the margin and the least zone size of this layout of this screen, shown here where their effect is seen; they are kept with Apply.
    private var spacing: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 6) {
            SliderSettingRow(title: "Gap between zones", detail: "Applies between zones only, never at screen edges.",
                             value: Binding(get: { Double(model.gap) }, set: { model.gap = CGFloat($0) }),
                             range: AppSettings.gapRange, step: AppSettings.gapStep)
            SliderSettingRow(title: "Margin at screen edges", detail: "Space between the zones and the edges of the screen.",
                             value: Binding(get: { Double(model.margin) }, set: { model.margin = CGFloat($0) }),
                             range: AppSettings.gapRange, step: AppSettings.gapStep)
            SliderSettingRow(title: "Minimum zone size", detail: "The layout editor won't split or resize a zone below this.",
                             value: $model.minZoneSize, range: AppSettings.minZoneSizeRange, step: AppSettings.minZoneSizeStep)
        }
        .padding(14)
        .frame(width: 340)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button { model.close() } label: { Label("Close", systemImage: "xmark") }
                        .buttonStyle(.glass)
                    Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(.glass)
                        .keyboardShortcut("z", modifiers: .command)
                        .disabled(!model.canUndo)
                    Button { model.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
                        .buttonStyle(.glass)
                        .keyboardShortcut("z", modifiers: [.command, .shift])
                        .disabled(!model.canRedo)
                    Button { showShapes = true } label: { Label("Layouts", systemImage: "square.grid.2x2") }
                        .buttonStyle(.glass)
                        .popover(isPresented: $showShapes) { shapes }
                    Button { showSpacing = true } label: { Label("Spacing", systemImage: "slider.horizontal.3") }
                        .buttonStyle(.glass)
                        .popover(isPresented: $showSpacing) { spacing }
                    Button { model.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(.glass)
                    if model.editedArea != nil {
                        Button { model.removeEditedArea() } label: { Label("Remove screen", systemImage: "trash") }
                            .buttonStyle(.glass)
                    }
                    Button { model.apply() } label: { Label("Apply", systemImage: "checkmark") }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            hint
            if !model.strip.leading.isEmpty || !model.strip.trailing.isEmpty { overflowHint }
            Spacer()
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity)
    }

    private var hint: some View {
        Text("Click to split  ·  Hold ⇧ for a horizontal split\nDrag a line to resize  ·  Double-click a handle to remove it\nDrag a zone onto its neighbour to merge them")
            .multilineTextAlignment(.center)
            .font(.callout).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .allowsHitTesting(false)
    }

    private var overflowHint: some View {
        Text("Scroll with two fingers or the mouse wheel to move between screens.")
            .multilineTextAlignment(.center)
            .font(.callout).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .allowsHitTesting(false)
    }

    private func controlsRect(_ size: CGSize) -> CGRect {
        CGRect(x: size.width / 2 - 260, y: 0, width: 520, height: model.strip.totalWidth > 1 ? 250 : 190)   // buttons + hints
    }

    // MARK: Merge

    private func mergePreview(zones: [ZoneRect], area: CGRect) -> MergePreview? {
        guard let sid = model.mergeSource, let src = zones.first(where: { $0.id == sid }) else { return nil }
        guard let p = model.dragPoint, let tgt = zones.first(where: { $0.rect.contains(p) && $0.id != sid }) else {
            return MergePreview(source: src, target: nil, result: nil)
        }
        return MergePreview(source: src, target: tgt, result: model.merged(sid, tgt.id))
    }

    private func mergeDrag(zones: [ZoneRect], area: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("editor"))
            .onChanged { v in
                if model.mergeSource == nil {
                    guard !controlsRect(area.size).contains(v.startLocation),
                          let z = zones.first(where: { $0.rect.contains(v.startLocation) }) else { return }
                    model.mergeSource = z.id
                    model.hover = nil
                }
                model.dragPoint = v.location
            }
            .onEnded { v in
                defer { model.mergeSource = nil; model.dragPoint = nil }
                model.dragPoint = v.location
                if let m = mergePreview(zones: zones, area: area), m.valid, let target = m.target { model.merge(m.source.id, target.id) }
            }
    }

    @ViewBuilder
    private func mergeOverlay(_ m: MergePreview) -> some View {
        highlight(m.source.rect, color: AppAccent.color)
        if let t = m.target {
            highlight(t.rect, color: m.valid ? .green : .red)
            if m.valid {
                let u = m.source.rect.union(t.rect)
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.green, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .frame(width: max(u.width - 6, 0), height: max(u.height - 6, 0))
                    .overlay {
                        Label("Merge", systemImage: "rectangle.compress.vertical")
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                    }
                    .offset(x: u.minX + 3, y: u.minY + 3)
                    .allowsHitTesting(false)
            }
        }
    }

    private func highlight(_ r: CGRect, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(color.opacity(0.25))
            .frame(width: max(r.width - 6, 0), height: max(r.height - 6, 0))
            .offset(x: r.minX + 3, y: r.minY + 3)
            .allowsHitTesting(false)
    }

    // MARK: Split preview

    private func splitTarget(zones: [ZoneRect], dividers: [SplitDivider], size: CGSize) -> SplitTarget? {
        guard let p = model.hover else { return nil }
        return splitTarget(at: p, zones: zones, dividers: dividers, size: size)
    }

    private func splitTarget(at p: CGPoint, zones: [ZoneRect], dividers: [SplitDivider], size: CGSize) -> SplitTarget? {
        if controlsRect(size).contains(p) { return nil }
        for d in dividers {
            let near = d.sideBySide
                ? abs(p.x - d.position) < 14 && p.y >= d.parent.minY && p.y <= d.parent.maxY
                : abs(p.y - d.position) < 14 && p.x >= d.parent.minX && p.x <= d.parent.maxX
            if near { return nil }
        }
        guard let z = zones.first(where: { $0.rect.contains(p) }) else { return nil }
        let side = !model.shift
        let extent = side ? z.rect.width : z.rect.height
        let origin = side ? z.rect.minX : z.rect.minY
        let minSize = model.minZoneSize
        let valid = extent >= 2 * minSize

        let pos = side ? p.x : p.y
        var snapped = false
        var r = Double((pos - origin) / extent)
        if valid, let step = SplitSnap.step(near: r, extent: Double(extent), distance: Double(snapDistance)) { r = step; snapped = true }
        if valid { let lo = minSize / Double(extent); r = min(max(r, lo), 1 - lo) }
        return SplitTarget(zone: z, sideBySide: side, ratio: r, valid: valid, snapped: snapped)
    }

    /// What each side of the split under the pointer would be: its size in points, and, on a step, its share of the zone under it. The two lines are one block, centred in the side.
    private func splitLabels(_ t: SplitTarget, view: CGSize) -> some View {
        let sides = [(t.halves.0, t.ratio), (t.halves.1, 1 - t.ratio)]
        return ZStack {
            ForEach(sides.indices, id: \.self) { i in
                let (rect, share) = sides[i]
                let step = t.snapped ? SplitSnap.share(of: share) : nil
                ZoneSizeLabel(size: EditorModel.size(of: rect, in: view, area: area), share: step)
                .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
    }

    /// The share (a half, a third and the like) of `zone` in the line being dragged, when that line stands on a step and the zone is a whole side of it.
    private func draggedShare(of zone: UUID, dividers: [SplitDivider]) -> (numerator: Int, denominator: Int)? {
        guard let line = grab?.line, let d = dividers.first(where: { $0.id == line }), snappedLine, let sides = model.strip.root.sides(ofSplit: line) ?? model.root.sides(ofSplit: line) else { return nil }
        if case .leaf(let id) = sides.first, id == zone { return SplitSnap.share(of: d.ratio) }
        if case .leaf(let id) = sides.second, id == zone { return SplitSnap.share(of: 1 - d.ratio) }
        return nil
    }

    // MARK: Dividers

    private func resize(_ d: SplitDivider, to p: CGPoint, in rect: CGRect) {
        let origin = d.sideBySide ? d.parent.minX : d.parent.minY
        var r = Double(((d.sideBySide ? p.x : p.y) - origin) / d.extent)
        let step = SplitSnap.step(near: r, extent: Double(d.extent), distance: Double(snapDistance))
        if let step { r = step }
        let lo = min(model.minZoneSize / Double(d.extent), 0.5)
        r = min(max(r, lo), 1 - lo)
        snappedLine = step != nil
        model.setRatio(d.id, r, in: rect, least: CGFloat(model.minZoneSize))
    }

    /// The line goes with the pointer from where its handle (or the line) was taken, not from the line's middle.
    private func drag(_ d: SplitDivider, in rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("editor"))
            .onChanged { value in
                if grab?.line != d.id { grab = (d.id, (d.sideBySide ? value.startLocation.x : value.startLocation.y) - d.position) }
                let offset = grab?.offset ?? 0
                resize(d, to: CGPoint(x: value.location.x - (d.sideBySide ? offset : 0), y: value.location.y - (d.sideBySide ? 0 : offset)), in: rect)
            }
            .onEnded { _ in
                grab = nil
                snappedLine = false
                model.endResize()
            }
    }

    /// On whole device pixels: a handle or a line between two pixels is drawn blurred.
    private func pixel(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x * displayScale).rounded() / displayScale, y: (point.y * displayScale).rounded() / displayScale)
    }

    /// Where the handle of a line stands: in the middle of the rectangle the line divides.
    private func middle(of d: SplitDivider) -> CGPoint {
        pixel(d.sideBySide ? CGPoint(x: d.position, y: d.parent.midY) : CGPoint(x: d.parent.midX, y: d.position))
    }

    private func lineView(_ d: SplitDivider, in rect: CGRect) -> some View {
        let centered = SplitSnap.isStep(d.ratio)
        return ZStack {
            Rectangle().fill(centered ? Color.white : AppAccent.color)
                .frame(width: d.sideBySide ? 2 : d.parent.width, height: d.sideBySide ? d.parent.height : 2)
            Rectangle().fill(.clear)
                .frame(width: d.sideBySide ? 14 : d.parent.width, height: d.sideBySide ? d.parent.height : 14)
                .contentShape(Rectangle())
                .gesture(drag(d, in: rect))
                .onHover { inside in
                    if inside { (d.sideBySide ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push() } else { NSCursor.pop() }
                }
        }
        .position(pixel(d.sideBySide ? CGPoint(x: d.position, y: d.parent.midY) : CGPoint(x: d.parent.midX, y: d.position)))
    }

    private func handleView(_ d: SplitDivider, in rect: CGRect) -> some View {
        Image(nsImage: DividerKnobView.image(sideBySide: d.sideBySide, atStep: SplitSnap.isStep(d.ratio)))
            .frame(width: DividerKnobView.side, height: DividerKnobView.side)
            .contentShape(Circle())
            .gesture(drag(d, in: rect))
            .onTapGesture(count: 2) { model.collapse(d.id) }
            .position(middle(of: d))
    }
}
