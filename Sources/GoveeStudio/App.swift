import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: StudioModel?
    private var terminating=false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps:true)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminating { return .terminateNow }
        terminating=true
        Task { @MainActor in
            await model?.stop()
            model?.save()
            sender.reply(toApplicationShouldTerminate:true)
        }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

#if !MEDIA_EXPORT
@main
struct GoveeStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model=StudioModel()
    var body: some Scene {
        WindowGroup {
            StudioView().environmentObject(model)
                .onAppear { delegate.model=model }
        }
        .defaultSize(width:1320,height:850)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing:.newItem) {}
            CommandMenu("Licht") {
                Button("Sync starten") { model.begin(output:true) }.disabled(model.busy)
                Button("Stoppen") { Task { await model.stop() } }.keyboardShortcut(".",modifiers:.command)
                Divider()
                Button("Geräte suchen") { Task { await model.scan() } }
                Button("Setup-Ordner öffnen") { NSWorkspace.shared.open(model.directory) }
            }
        }
    }
}

#endif
