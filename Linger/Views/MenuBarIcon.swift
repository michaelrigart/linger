import LingerCore
import SwiftUI

struct MenuBarIcon: View {
    let model: AppModel

    var body: some View {
        Image(PanelCopy.menuBarImage(model.output.status))
            .accessibilityLabel("Linger")
    }
}
