import AppKit
import Dependencies
import DependenciesMacros
import Foundation
import UniformTypeIdentifiers

/// What the section asks of the system. A host that keeps a log of what the app did (Bridge
/// Commander's activity log) wraps `moveToTrash` and `deletePermanently` with its own, through
/// the store's `withDependencies`.
@DependencyClient
public struct DiskUsageClient: Sendable {
	public var volumes: @Sendable () -> [DiskVolume] = { [] }
	public var scan: @Sendable (_ root: URL) -> AsyncStream<DiskScanEvent> = { _ in .finished }
	/// Asks for a folder to scan; nil when the panel is cancelled.
	public var chooseFolder: @Sendable () async -> URL?
	public var moveToTrash: @Sendable (URL) async throws -> Void
	public var deletePermanently: @Sendable (URL) async throws -> Void
	public var showInFinder: @Sendable (URL) -> Void
	public var openFullDiskAccessSettings: @Sendable () -> Void
}

extension DiskUsageClient: DependencyKey {
	public static let liveValue = DiskUsageClient(
		volumes: { DiskVolumeLister.volumes() },
		scan: { DiskScanner.scan($0) },
		chooseFolder: {
			await MainActor.run {
				let panel = NSOpenPanel()
				panel.canChooseDirectories = true
				panel.canChooseFiles = false
				panel.allowsMultipleSelection = false
				panel.prompt = "Scan"
				panel.message = "Choose a folder to scan"
				return panel.runModal() == .OK ? panel.url : nil
			}
		},
		moveToTrash: { url in
			try await Task.detached(priority: .utility) {
				try FileManager.default.trashItem(at: url, resultingItemURL: nil)
			}.value
		},
		deletePermanently: { url in
			try await Task.detached(priority: .utility) {
				try FileManager.default.removeItem(at: url)
			}.value
		},
		showInFinder: { url in
			NSWorkspace.shared.activateFileViewerSelecting([url])
		},
		openFullDiskAccessSettings: {
			if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
				NSWorkspace.shared.open(url)
			}
		}
	)
}

extension DiskUsageClient: TestDependencyKey {
	public static let testValue = DiskUsageClient()
}
