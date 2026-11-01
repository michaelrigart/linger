import LingerCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                Picker("Start after you've been idle for", selection: $model.settings.idleDelay) {
                    ForEach(LingerSettings.idleDelayChoices, id: \.self) { Text(Self.duration($0)).tag($0) }
                }
                LabeledContent("Accessibility permission") {
                    if model.output.status == .needsPermission {
                        HStack {
                            Text("Not allowed")
                                .foregroundStyle(.secondary)
                            Button("Allow…") { model.requestAccess() }
                        }
                    } else {
                        Text("Allowed")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Light/dark") {
                Toggle("Step aside so macOS can switch light/dark", isOn: $model.settings.stepAsideEnabled)
                Picker("Allow up to", selection: $model.settings.gapBudget) {
                    ForEach(LingerSettings.gapBudgetChoices, id: \.self) { Text("\(Self.duration($0)) away per switch").tag($0) }
                }
                .disabled(!model.settings.stepAsideEnabled)
                LabeledContent("Appearance", value: appearanceText)
                LabeledContent("Next step-aside", value: nextStepAsideText)
                LabeledContent("Location") {
                    Text(PanelCopy.locationLine(identifier: TimeZone.current.identifier, coordinates: model.coordinates))
                        .foregroundStyle(.secondary)
                }
            }
            Section("About") {
                LabeledContent("Version", value: Self.version)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { on in
                model.markLoginItemConfigured()
                do {
                    try LoginItem.setEnabled(on)
                } catch {
                    Log.engine.error("login item change failed, code \((error as NSError).code, privacy: .public)")
                }
                launchAtLogin = LoginItem.isEnabled
            }
        )
    }

    private var appearanceText: String {
        let name = model.effectiveAppearance.rawValue.capitalized
        return model.appearanceIsAuto ? "Auto, currently \(name)" : "\(name), not Auto"
    }

    private var nextStepAsideText: String {
        guard model.settings.stepAsideEnabled else { return "Off" }
        guard model.appearanceIsAuto, let next = model.nextStepAside else { return "None expected" }
        let time = PanelCopy.clock(next.at, locale: .current, timeZone: .current)
        return "\(next.target.rawValue.capitalized) around \(time)"
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
