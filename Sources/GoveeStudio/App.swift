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
    @ObservedObject private var language=LanguageSettings.shared
    var body: some Scene {
        WindowGroup {
            StudioView().environmentObject(model)
                .onAppear { delegate.model=model }
        }
        .defaultSize(width:1320,height:850)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing:.newItem) {}
            CommandMenu(tr("Licht")) {
                Button(tr("Sync starten")) { model.begin(output:true) }.disabled(model.busy)
                Button(tr("Stoppen")) { Task { await model.stop() } }.keyboardShortcut(".",modifiers:.command)
                Divider()
                Button(tr("Geräte suchen")) { Task { await model.scan() } }
                Button(tr("Setup-Ordner öffnen")) { NSWorkspace.shared.open(model.directory) }
            }
        }
    }
}

#endif
