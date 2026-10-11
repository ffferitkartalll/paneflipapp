import AppKit
import PaneFlipCore
import SwiftUI

struct EditorView: View {
    let model: EditorModel
    let settings: AppSettings
    /// Within this many points of the centre, a new or dragged divider snaps to exactly 50 %.
    private let snapDistance: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let zones = model.root.zones(in: rect).enumerated().map { ZoneRect(id: $1.id, index: $0, rect: $1.rect) }
            let dividers = model.root.dividers(in: rect)
            let target = splitTarget(zones: zones, dividers: dividers, size: geo.size)

            ZStack(alignment: .topLeading) {
                Color.black

                ForEach(zones) { z in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.05))
                        .frame(width: max(z.rect.width - 6, 0), height: max(z.rect.height - 6, 0))
                        .overlay(alignment: .topLeading) {
                            Text(verbatim: "\(z.index + 1)").font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.5)).padding(12)
                        }
                        .offset(x: z.rect.minX + 3, y: z.rect.minY + 3)
                        .allowsHitTesting(false)
                }

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
                            model.root = model.root.splitting(t.zone.id, sideBySide: t.sideBySide, ratio: t.ratio)
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

                ForEach(dividers) { d in dividerView(d) }

                controls
            }
            .coordinateSpace(name: "editor")
        }
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
                    Button { model.apply() } label: { Label("Apply", systemImage: "checkmark") }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            hint
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

    private func controlsRect(_ size: CGSize) -> CGRect {
        CGRect(x: size.width / 2 - 260, y: 0, width: 520, height: 190)   // buttons + hint
    }

    // MARK: Merge

    private struct MergePreview {
        let source: ZoneRect
        let target: ZoneRect?
        let result: LayoutNode?
        var valid: Bool { result != nil }
    }

    private func mergePreview(zones: [ZoneRect], area: CGRect) -> MergePreview? {
        guard let sid = model.mergeSource, let src = zones.first(where: { $0.id == sid }) else { return nil }
        guard let p = model.dragPoint, let tgt = zones.first(where: { $0.rect.contains(p) && $0.id != sid }) else {
            return MergePreview(source: src, target: nil, result: nil)
        }
        return MergePreview(source: src, target: tgt, result: model.root.merging(sid, tgt.id, in: area))
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
                if let result = mergePreview(zones: zones, area: area)?.result { model.root = result }
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
        model.root = model.root.settingRatio(d.id, r)
    }

    private func drag(_ d: SplitDivider) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("editor"))
            .onChanged { resize(d, to: $0.location) }
    }

    private func dividerView(_ d: SplitDivider) -> some View {
        let mid = d.sideBySide
            ? CGPoint(x: d.position, y: d.parent.midY)
            : CGPoint(x: d.parent.midX, y: d.position)
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
            Image(systemName: d.sideBySide ? "pause" : "equal")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(centered ? Color.black : Color.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(centered ? Color.white : Color.accentColor))
                .contentShape(Circle())
                .gesture(drag(d))
                .onTapGesture(count: 2) { model.root = model.root.collapsing(d.id) }
        }
        .position(mid)
    }
}
