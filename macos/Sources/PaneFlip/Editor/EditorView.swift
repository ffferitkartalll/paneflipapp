import AppKit
import PaneFlipCore
import SwiftUI

struct EditorView: View {
    let model: EditorModel
    let settings: AppSettings
    /// The area zones are laid out in, in points: one screen's width of the editor stands for it.
    let area: CGSize
    /// Within this many points of the centre, a new or dragged divider snaps to exactly 50 %.
    private let snapDistance: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            // The strip is drawn at full size, one screen of it in view; the rest lies to the left and to the right, out of the panel.
            let total = CGFloat(model.strip.totalWidth)
            let rect = CGRect(x: -CGFloat(model.strip.leadingWidth + model.offset) * geo.size.width, y: 0,
                              width: total * geo.size.width, height: geo.size.height)
            let zones = model.root.zones(in: rect).enumerated().map { ZoneRect(id: $1.id, index: $0, rect: $1.rect) }
            let dividers = model.root.dividers(in: rect)
            let target = splitTarget(zones: zones, dividers: dividers, size: geo.size)

            ZStack(alignment: .topLeading) {
                Color.black

                ForEach(zones) { z in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(model.strip.part(of: z.id) == .screen ? Color.white.opacity(0.05) : Color.orange.opacity(0.18))
                        .frame(width: max(z.rect.width - 6, 0), height: max(z.rect.height - 6, 0))
                        .overlay(alignment: .topLeading) {
                            Text(verbatim: label(of: z.id)).font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.5)).padding(12)
                        }
                        .overlay {
                            Text(verbatim: size(of: z.rect, in: geo.size)).font(.title3.monospacedDigit()).foregroundStyle(.white.opacity(0.4))
                        }
                        .offset(x: z.rect.minX + 3, y: z.rect.minY + 3)
                        .allowsHitTesting(false)
                }

                if total > 1 { screenFrame(rect, total: total) }

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

                if let t = target {
                    Path { p in p.move(to: t.line.0); p.addLine(to: t.line.1) }
                        .stroke(t.valid ? (t.snapped ? Color.white : Color.accentColor) : Color.red,
                                lineWidth: t.snapped ? 3 : 2)
                        .allowsHitTesting(false)
                }

                // The edge of an area is not a line to drag: a screen has the width of the screen.
                // All lines first, then all handles: another divider's line must not run over a handle.
                let lines = dividers.filter { !model.isAreaLine($0.id) }
                ForEach(lines) { d in lineView(d) }
                ForEach(lines) { d in handleView(d) }

                controls
                overflowButtons(size: geo.size)
            }
            .animation(.smooth(duration: 0.4), value: model.offset)
            .overlay(alignment: .bottomTrailing) { if total > 1 { preview.padding(24) } }
            .coordinateSpace(name: "editor")
        }
    }

    /// A zone's size in points, worked out from its share of the editor.
    private func size(of rect: CGRect, in view: CGSize) -> String {
        "\(Int((rect.width / view.width * area.width).rounded())) × \(Int((rect.height / view.height * area.height).rounded()))"
    }

    // MARK: Areas beyond the screen

    /// Zones are named as everywhere else: 1, 2, 3 on the screen, -1, -2 beyond the left edge, +1, +2 beyond the right one.
    private func label(of zone: UUID) -> String { ZoneLabel.text(of: zone, in: model.strip) }

    /// Where the screen itself lies within the strip.
    private func screenFrame(_ rect: CGRect, total: CGFloat) -> some View {
        let before = CGFloat(model.strip.leadingWidth) / total * rect.width
        return RoundedRectangle(cornerRadius: 12)
            .strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .frame(width: rect.width / total, height: rect.height)
            .offset(x: rect.minX + before, y: rect.minY)
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

    // MARK: Preview of the strip

    /// The whole strip in small, with the screen the editor shows marked, and which screen it is.
    private var preview: some View {
        let rests = model.strip.areaRests
        let here = rests.indices.min { abs(rests[$0] - model.offset) < abs(rests[$1] - model.offset) } ?? 0
        return StripPreview(strip: model.strip, offset: model.offset, caption: Text("Screen \(here + 1) of \(rests.count)"), animated: true)
            .allowsHitTesting(false)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button { model.close() } label: { Label("Close", systemImage: "xmark") }
                        .buttonStyle(.glass)
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

    private struct MergePreview {
        let source: ZoneRect
        let target: ZoneRect?
        let result: StripLayout?
        var valid: Bool { result != nil }
    }

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
        highlight(m.source.rect, color: .accentColor)
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
        let minSize = settings.values.minZoneSize
        let valid = extent >= 2 * minSize

        var pos = side ? p.x : p.y
        var snapped = false
        if valid, abs(pos - (origin + extent / 2)) < snapDistance { pos = origin + extent / 2; snapped = true }
        var r = Double((pos - origin) / extent)
        if valid { let lo = minSize / Double(extent); r = min(max(r, lo), 1 - lo) }
        return SplitTarget(zone: z, sideBySide: side, ratio: r, valid: valid, snapped: snapped)
    }

    // MARK: Dividers

    private func resize(_ d: SplitDivider, to p: CGPoint) {
        let origin = d.sideBySide ? d.parent.minX : d.parent.minY
        var pos = d.sideBySide ? p.x : p.y
        if abs(pos - (origin + d.extent / 2)) < snapDistance { pos = origin + d.extent / 2 }
        var r = Double((pos - origin) / d.extent)
        let lo = min(settings.values.minZoneSize / Double(d.extent), 0.5)
        r = min(max(r, lo), 1 - lo)
        model.setRatio(d.id, r)
    }

    private func drag(_ d: SplitDivider) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("editor"))
            .onChanged { resize(d, to: $0.location) }
    }

    private func middle(of d: SplitDivider) -> CGPoint {
        d.sideBySide ? CGPoint(x: d.position, y: d.parent.midY) : CGPoint(x: d.parent.midX, y: d.position)
    }

    private func lineView(_ d: SplitDivider) -> some View {
        let centered = abs(d.ratio - 0.5) < 0.0001
        return ZStack {
            Rectangle().fill(centered ? Color.white : Color.accentColor)
                .frame(width: d.sideBySide ? 2 : d.parent.width, height: d.sideBySide ? d.parent.height : 2)
            Rectangle().fill(.clear)
                .frame(width: d.sideBySide ? 14 : d.parent.width, height: d.sideBySide ? d.parent.height : 14)
                .contentShape(Rectangle())
                .gesture(drag(d))
                .onHover { inside in
                    if inside { (d.sideBySide ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push() } else { NSCursor.pop() }
                }
        }
        .position(middle(of: d))
    }

    private func handleView(_ d: SplitDivider) -> some View {
        let centered = abs(d.ratio - 0.5) < 0.0001
        return Image(systemName: d.sideBySide ? "pause" : "equal")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(centered ? Color.black : Color.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(centered ? Color.white : Color.accentColor))
            .contentShape(Circle())
            .gesture(drag(d))
            .onTapGesture(count: 2) { model.collapse(d.id) }
            .position(middle(of: d))
    }
}
