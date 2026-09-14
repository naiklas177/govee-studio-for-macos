import SwiftUI

struct CloudLibraryView: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject var library: CloudLibrary
    @State private var deviceID=""
    @State private var wholeRoom=true
    @State private var query=""
    @State private var kind="all"
    private var currentID: String { deviceID.isEmpty ? (library.catalog.groups.first?.device ?? ""):deviceID }
    private var group: CloudSceneGroup? { library.catalog.groups.first { $0.device == currentID } }
    private var filtered: [CloudScene] {
        (group?.scenes ?? []).filter { (kind == "all" || $0.kind == kind) && (query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query)) }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                VStack(alignment:.leading,spacing:6) {
                    Text(verbatim:tr("Govees Spielzeugkiste.")).font(.system(size:24,weight:.semibold))
                    Text(verbatim:tr("Originaleffekte für den ganzen Raum oder einzelne Geräte.")).font(.system(size:11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName:"cloud").font(.system(size:25)).foregroundStyle(Palette.mint)
            }
            CredentialSettingsView(library:library)
            Button(tr(library.refreshing ? "Lädt …":"Katalog aktualisieren")) { Task { await library.refresh(devices:model.devices) } }
                .buttonStyle(StudioButtonStyle()).disabled(library.refreshing || library.key.isEmpty)
            Text(verbatim:tr(library.status)).font(.system(size:10)).foregroundStyle(Palette.muted).textSelection(.enabled)
            Picker(tr("Ausgabe"),selection:$wholeRoom) {
                Text(verbatim:tr("Ganzer Raum · Original")).tag(true)
                Text(verbatim:tr("Einzelgerät · Original & DIY")).tag(false)
            }.pickerStyle(.segmented)
            if wholeRoom {
                roomPicker
            } else {
            HStack {
                Picker(tr("Gerät"),selection:Binding(get:{currentID},set:{deviceID=$0})) {
                    ForEach(library.catalog.groups) { group in Text(verbatim:tr(model.devices.first(where:{$0.id == group.device})?.name ?? group.name)).tag(group.device) }
                }.frame(maxWidth:300)
                Picker(tr("Effekte"),selection:$kind) {
                    Text(verbatim:tr("Alle")).tag("all"); Text(verbatim:tr("Original")).tag("lightScene"); Text(verbatim:tr("DIY")).tag("diyScene")
                }.pickerStyle(.segmented).frame(width:210)
                Spacer()
            }
            TextField(tr("Effekte suchen …"),text:$query).textFieldStyle(.roundedBorder).accessibilityLabel(tr("Govee-Effekte suchen"))
            if let group {
                HStack {
                    Text(verbatim:tr("\(filtered.count) Effekte")).font(.system(size:11,weight:.medium))
                    Spacer()
                    if let date=group.updatedAt { Text(verbatim:tr("Stand \(date.formatted(date:.abbreviated,time:.shortened))")).font(.system(size:9)).foregroundStyle(Palette.muted) }
                }
                if let error=group.error { Text(verbatim:tr("Abruf unvollständig · \(error)")).font(.system(size:10)).foregroundStyle(.orange) }
                if !model.devices.contains(where:{$0.id == group.device && $0.enabled}) {
                    Text(verbatim:tr("Gerät im Setup aktivieren, um Effekte zu starten.")).font(.system(size:11)).foregroundStyle(.orange)
                }
            }
            if filtered.isEmpty {
                Text(verbatim:tr(library.catalog.groups.isEmpty ? "Key eingeben und den Katalog laden. Deine lokalen Szenen bleiben jederzeit verfügbar.":"Keine passenden Effekte. Bei leerem DIY-Katalog zuerst einen Look in Govee Home speichern und aktualisieren."))
                    .font(.system(size:12)).foregroundStyle(Palette.muted).padding(.vertical,20)
            }
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                ForEach(filtered) { scene in
                    Button { model.activateCloud(scene) } label: {
                        VStack(alignment:.leading,spacing:12) {
                            HStack {
                                Image(systemName:scene.kind == "diyScene" ? "paintbrush.pointed.fill":"sparkles").foregroundStyle(Palette.mint)
                                Spacer()
                                Text(verbatim:tr(scene.label.uppercased())).font(.system(size:8,design:.monospaced)).foregroundStyle(Palette.muted)
                            }
                            Text(scene.displayName).font(.system(size:12,weight:.semibold)).lineLimit(2).frame(height:32,alignment:.topLeading)
                            Label(tr(model.activeCloud?.id == scene.id ? "Govee bestätigt":"Auf Gerät starten"),systemImage:model.activeCloud?.id == scene.id ? "checkmark.circle.fill":"play.fill")
                                .font(.system(size:9)).foregroundStyle(Palette.mint)
                        }.frame(maxWidth:.infinity,alignment:.leading).padding(14)
                            .background(model.activeCloud?.id == scene.id ? Palette.mint.opacity(0.12):Palette.raised,in:RoundedRectangle(cornerRadius:10))
                    }.buttonStyle(.plain).disabled(library.key.isEmpty || !model.devices.contains(where:{$0.id == scene.device && $0.enabled}))
                    .accessibilityLabel(tr("\(scene.displayName), \(scene.label), auf ausgewähltem Gerät starten"))
                }
            }
            }
            Text(verbatim:tr("Katalog offline gespeichert · Start über Govee-Cloud · keine Bildschirm- oder Audiodaten übertragen. Stoppen stellt die gesicherten Grundwerte wieder her; ein vorheriger Govee-Effekt lässt sich daraus nicht rekonstruieren."))
                .font(.system(size:10)).foregroundStyle(Palette.muted)
        }.padding(20).background(Palette.panel,in:RoundedRectangle(cornerRadius:14))
    }
    private func sceneTitle(_ scene: CloudScene,in scenes: [CloudScene]) -> String {
        let variants=scenes.filter { $0.displayName == scene.displayName }
        guard variants.count > 1,let index=variants.firstIndex(of:scene) else { return scene.displayName }
        return scene.displayName+" · Variante \(index+1)"
    }
    private var roomPicker: some View {
        VStack(alignment:.leading,spacing:14) {
            Text(verbatim:tr("Je Gerät ein Originaleffekt. Alle aktivierten Leuchten starten gemeinsam; die Govee-Befehle werden nacheinander gesendet.")).font(.system(size:11)).foregroundStyle(Palette.muted)
            ForEach(model.devices.filter(\.enabled)) { device in
                let scenes=library.catalog.groups.first(where:{$0.device == device.id && $0.sku == device.sku})?.scenes.filter { $0.kind == "lightScene" }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending } ?? []
                VStack(alignment:.leading,spacing:7) {
                    Text(device.name).font(.system(size:12,weight:.semibold))
                    Picker(tr("Originalszene"),selection:Binding(get:{library.roomScenes.sceneIDs[device.id] ?? ""},set:{library.roomScenes.sceneIDs[device.id]=$0;library.saveRoomScenes()})) {
                        Text(verbatim:tr("Szene auswählen …")).tag("")
                        ForEach(scenes) { scene in Text(verbatim:tr(sceneTitle(scene,in:scenes))).tag(scene.id) }
                    }.accessibilityLabel(tr("Originalszene für \(device.name)"))
                    if scenes.isEmpty { Text(verbatim:tr("Für dieses Gerät zuerst den Katalog aktualisieren.")).font(.caption).foregroundStyle(.orange) }
                }.padding(12).background(Palette.raised,in:RoundedRectangle(cornerRadius:9))
            }
            Button(tr("Originalszenen auf allen Geräten starten")) { model.activateRoomScenes(library.roomScenes) }
                .buttonStyle(StudioButtonStyle(prominent:true))
                .disabled(library.key.isEmpty || (try? library.roomScenes.plan(devices:model.devices,catalog:library.catalog)) == nil)
            Text(verbatim:tr("Alle Geräte brauchen eine Auswahl. Modellspezifische Effekte bleiben beim passenden Gerät; es werden keine fremden Szenen-IDs übertragen.")).font(.system(size:10)).foregroundStyle(Palette.muted)
        }
    }
}
