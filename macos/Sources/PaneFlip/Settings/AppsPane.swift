import PaneFlipCore
import SwiftUI

/// Tab: what PaneFlip does with particular apps.
struct AppsPane: View {
    @Bindable var settings: AppSettings
    let catalog: AppCatalog
    let editor: LayoutAppsEditing

    var body: some View {
        Form {
            IgnoredAppsSection(settings: settings, catalog: catalog, editor: editor)
                .disabled(!settings.values.placementEnabled)
        }
        .formStyle(.grouped)
    }
}
