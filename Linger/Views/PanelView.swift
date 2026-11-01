import AppKit
import LingerCore
import SwiftUI

struct PanelView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    private var status: EngineStatus { model.output.status }

    private var isOn: Binding<Bool> {
        Binding(get: { model.settings.isOn }, set: { model.setOn($0) })
    }

    private var switchLine: String? {
        PanelCopy.switchLine(
            model.nextStepAside,
            now: Date(),
            appearanceIsAuto: model.appearanceIsAuto,
            stepAsideEnabled: model.settings.stepAsideEnabled,
            locale: .current,
            timeZone: .current
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if case .needsPermission = status {
                Button("Allow…") { model.requestAccess() }
            } else {
                pauseSection
            }
            if let switchLine {
                switchRow(switchLine)
            }
            footer
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { model.refresh() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PanelCopy.title(status))
                    .font(.system(size: 15, weight: .semibold))
                Text(PanelCopy.statusLine(status, locale: .current, timeZone: .current))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Keep me active", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.large)
                .disabled(status == .needsPermission)
        }
    }

    @ViewBuilder
    private var pauseSection: some View {
        if case .paused = status {
            Button { model.resume() } label: { chip("Resume") }
                .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pause for")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    pauseButton("15 min", .fifteenMinutes)
                    pauseButton("1 hour", .oneHour)
                    pauseButton("Today", .today)
                }
            }
            .disabled(status == .off)
        }
    }

    private func pauseButton(_ title: String, _ duration: PauseDuration) -> some View {
        Button { model.pause(duration) } label: { chip(title) }
            .buttonStyle(.plain)
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9).fill(.primary.opacity(0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }

    private func switchRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: switchSymbol)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.045)))
    }

    private var switchSymbol: String {
        guard model.appearanceIsAuto, let next = model.nextStepAside else { return "info.circle" }
        return next.target == .dark ? "moon.fill" : "sun.max.fill"
    }

    private var footer: some View {
        HStack {
            Button("Settings…") {
                openSettings()
                NSApp.activate()
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
}
