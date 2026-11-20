import SwiftUI

/// The launcher a zone shows while no window is in it and the pointer is over it: the apps of the cards the zone's grid shows (left out when there are none) and, under them,
/// every app in alphabetical order. Each part is a panel as a settings tab has them, with its title in the accent colour. Opaque, not glass; it fades in and out.
struct ZoneLauncherView: View {
    let model: ZoneLauncherModel
    @State private var rests = false
    /// Room round the zone for the shadow: the panel is this much larger than the zone (what is clear takes no mouse).
    static let shadowRoom: CGFloat = 40
    private let columns = [GridItem(.adaptive(minimum: 116), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !model.placed.isEmpty { section("Apps previously placed in this zone", model.placed, placed: true).transition(.opacity) }
                section("All apps", model.all, placed: false)
            }
            .padding(20)
            .coordinateSpace(name: "launcher")
        }
        // No bar while the launcher comes in and the apps arrive (it would flash, as if it had been scrolled); it is there once the launcher rests.
        .scrollIndicators(rests ? .automatic : .hidden)
        .task(id: model.visible) {   // a task of an earlier showing is cancelled: it does not bring the bar back early
            rests = false
            guard model.visible else { return }
            do { try await Task.sleep(for: .milliseconds(700)); rests = true } catch {}
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: ZoneCorner.radius))
        // The edge and the shadow of a card of the zone's grid (`ZoneWindowsCard`): a light line inside the edge, a dark one outside it, and a shadow cast by a plain shape behind.
        .overlay {
            ZStack {
                RoundedRectangle(cornerRadius: ZoneCorner.radius).strokeBorder(.white.opacity(0.08), lineWidth: 1)
                RoundedRectangle(cornerRadius: ZoneCorner.radius + 1).strokeBorder(.black.opacity(0.85), lineWidth: 1).padding(-1)
            }
        }
        .background { RoundedRectangle(cornerRadius: ZoneCorner.radius).fill(.black).shadow(color: .black.opacity(0.5), radius: 16, y: 5) }
        .opacity(model.visible ? 1 : 0)
        .padding(Self.shadowRoom)
    }

    private func tile(_ app: LauncherApp, placed: Bool) -> some View {
        let carried = model.carried == app.bundleID
        return ZoneLauncherTile(app: app, glyph: model.glyph(of: app.bundleID), removes: placed, carrying: model.moving != nil, isMoving: model.moving == app.bundleID,
                                badge: { placed ? model.onRemove(app.bundleID) : model.onAdd(app.bundleID) })
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            // Before the offset: where the cell is, not where the carried app is (the others' cells move while one is carried, and are kept up to date meanwhile).
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("launcher")) } action: { if placed { model.frames[app.bundleID] = $0 } }
            .offset(carried ? model.carriedOffset : .zero)
            .zIndex(carried ? 1 : 0)
            .shadow(color: .black.opacity(carried ? 0.35 : 0), radius: 10, y: 4)
            // One gesture for the press, as the cards of the zone's grid have: a press that moves opens nothing, a press that does not move opens the app (a tap gesture beside a
            // drag one would take the drag).
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("launcher"))
                .onChanged { drag in
                    if model.carried == nil, placed, hypot(drag.translation.width, drag.translation.height) >= 4 { model.carry(app.bundleID, at: drag.startLocation) }
                    if model.carried == app.bundleID { model.drag(to: drag.location) }
                }
                .onEnded { drag in
                    if model.carried == app.bundleID { model.drop() }
                    else if hypot(drag.translation.width, drag.translation.height) < 4 { model.onLaunch(app.bundleID) }
                })
    }

    /// A panel as a settings tab has them (a form's grouped section) with its title above in the accent colour; made here because a form keeps to a width of its own and
    /// leaves the zone's sides empty.
    private func section(_ title: LocalizedStringKey, _ apps: [LauncherApp], placed: Bool) -> some View {
        // 10 points between the title and its panel, 10 in from the panel's edge: measured on a settings tab's grouped form.
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.body.weight(.semibold)).foregroundStyle(AppAccent.color).padding(.leading, 10)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(apps) { app in tile(app, placed: placed) }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.primary.opacity(0.06)))
        }
    }
}
