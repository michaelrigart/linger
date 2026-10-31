import LingerCore
import SwiftUI

struct MenuBarIcon: View {
    let model: AppModel

    var body: some View {
        Image(systemName: PanelCopy.iconSymbol(model.output.status))
            .accessibilityLabel("Linger")
    }
}
