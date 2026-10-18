import AppKit
import ComposableArchitecture
import DiskUsageFeature
import Sparkle
import SwiftUI

/// The Disk section on its own: the `DiskUsageFeature` package Bridge Commander embeds as a
/// section, in a window of its own.
@main
struct DiskHorizonApp: App {
	@State
	private var store = Store(initialState: DiskUsageReducer.State()) {
		DiskUsageReducer()
	}

	@AppStorage("uiFontSize")
	private var uiFontSize = TextSize.default

	/// Created with the app, as Sparkle expects: a started updater schedules its background
	/// checks from here.
	private let updaterController = SPUStandardUpdaterController(
		startingUpdater: startsUpdater,
		updaterDelegate: nil,
		userDriverDelegate: nil
	)

	var body: some Scene {
		Window("DiskHorizon", id: "main") {
			DiskUsageView(store: store) {
				AppTitle(scale: TextSize.scale(for: uiFontSize))
			}
			.background(Color(nsColor: .windowBackgroundColor))
			.frame(minWidth: 900, minHeight: 560)
			.diskUsageUIFontScale(TextSize.scale(for: uiFontSize))
		}
		.windowStyle(.hiddenTitleBar)
		.defaultSize(width: 1280, height: 820)
		.commands {
			CommandGroup(after: .appInfo) {
				CheckForUpdatesView(updater: updaterController.updater)
			}
			CommandGroup(replacing: .newItem) {
				// Back to the picker; a finished scan stays there as a recent scan.
				Button("New Scan") { store.send(.view(.newScanTapped)) }
					.keyboardShortcut("n", modifiers: .command)
				Button("Scan Folder…") { store.send(.view(.chooseFolderTapped)) }
					.keyboardShortcut("o", modifiers: .command)
			}
			CommandGroup(after: .toolbar) {
				Button("Bigger Text") { uiFontSize = TextSize.clamped(uiFontSize + 1) }
					.keyboardShortcut("=", modifiers: .command)
					.disabled(uiFontSize >= TextSize.maximum)
				Button("Smaller Text") { uiFontSize = TextSize.clamped(uiFontSize - 1) }
					.keyboardShortcut("-", modifiers: .command)
					.disabled(uiFontSize <= TextSize.minimum)
				Button("Actual Size") { uiFontSize = TextSize.default }
					.keyboardShortcut("0", modifiers: .command)
					.disabled(uiFontSize == TextSize.default)
				Divider()
			}
		}

		Settings {
			SettingsView(updater: updaterController.updater)
		}
	}
}

/// The header's leading view: the app's icon and name, where Bridge Commander puts its section
/// switcher.
private struct AppTitle: View {
	let scale: CGFloat

	var body: some View {
		HStack(spacing: 6) {
			Image(nsImage: NSApp.applicationIconImage)
				.resizable()
				.frame(width: 22 * scale, height: 22 * scale)
			Text("DiskHorizon")
				.font(.system(size: 13 * scale, weight: .semibold))
		}
		.padding(.horizontal, 4)
	}
}

/// The text size, as the point size of body text — Bridge Commander's Settings ▸ Appearance
/// setting, here in the View menu.
enum TextSize {
	/// macOS's body size: scale 1.
	static let `default`: Double = 13
	static let minimum: Double = 10
	static let maximum: Double = 20

	static func clamped(_ size: Double) -> Double {
		min(max(size, minimum), maximum)
	}

	static func scale(for size: Double) -> CGFloat {
		CGFloat(clamped(size) / `default`)
	}
}
