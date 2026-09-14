import SwiftUI
import AmbienceCore

struct NativeMusicView: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject var library: CloudLibrary
    private var devices: [DeviceConfig] { model.devices.filter(\.enabled) }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text(verbatim:tr("Der ganze Raum spielt mit.")).font(.system(size:24,weight:.semibold))
            Text(verbatim:tr("Govee-Musik auf allen Leuchten – oder Hexagon-Musik mit Ambilight auf den Strips. Jede Leuchte bekommt genau eine Quelle; Musik und Bildschirmfarben werden nicht auf demselben Gerät überlagert."))
                .font(.system(size:11)).foregroundStyle(Palette.muted)
            CredentialSettingsView(library:library)
            Button(tr(library.loadingMusic ? "Lädt …":"Musikmodi abrufen")) { Task { await library.refreshMusic(devices:model.devices) } }.buttonStyle(StudioButtonStyle()).disabled(library.key.isEmpty || library.loadingMusic)
            HStack {
                Button(tr("Ganzer Raum · Musik")) { preset(mixed:false) }.buttonStyle(StudioButtonStyle())
                Button(tr("Hexagon-Musik + Strip-Ambilight")) { preset(mixed:true) }.buttonStyle(StudioButtonStyle())
            }
            ForEach(devices) { device in
                HStack(spacing:12) {
                    VStack(alignment:.leading,spacing:4) { Text(device.name).font(.system(size:12,weight:.semibold)); Text(verbatim:tr(device.sku)).font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.muted) }.frame(width:150,alignment:.leading)
                    Picker(tr("Quelle für \(device.name)"),selection:Binding(get:{library.room.role(device)},set:{library.room.roles[device.id]=$0})) {
                        ForEach(RoomLightRole.allCases,id:\.self) { role in Text(verbatim:tr(role.rawValue)).tag(role) }
                    }.labelsHidden().frame(width:170)
                    if library.room.role(device) == .music {
                        if let profile=library.musicProfiles.first(where:{$0.device == device.id && $0.sku == device.sku}) {
                            Picker(tr("Musikmodus für \(device.name)"),selection:Binding(get:{library.room.mode(profile)?.value ?? 0},set:{library.room.modes[device.id]=$0})) {
                                ForEach(profile.modes,id:\.value) { mode in Text(verbatim:tr(mode.name)).tag(mode.value) }
                            }.labelsHidden()
                        } else { Text(verbatim:tr("Musikmodi zuerst abrufen")).font(.system(size:10)).foregroundStyle(.orange) }
                    } else if library.room.role(device) == .ambilight { Text(verbatim:tr("Bildschirm & Mapping aus Setup")).font(.system(size:10)).foregroundStyle(Palette.mint) }
                    Spacer(minLength:0)
                }.padding(12).background(Palette.raised,in:RoundedRectangle(cornerRadius:9))
            }
            HStack {
                Text(verbatim:tr(library.musicStatus)).font(.system(size:10)).foregroundStyle(Palette.muted)
                Spacer()
                Button(tr("Raum-Musik starten")) { model.activateRoom() }.buttonStyle(StudioButtonStyle(prominent:true)).disabled(library.key.isEmpty || devices.isEmpty)
            }
            Text(verbatim:tr("Zuordnung mit Raum-Musik starten übernehmen; Farben und Regler rechts lassen sich während der Ausgabe anwenden. Govee reagiert im Geräte-Modus; nur zugeordnete Ambilight-Leuchten erhalten Mac-Bildschirmfarben. Keine Mac-Audioübertragung an Govee. Stoppen stellt alle gesicherten Grundwerte wieder her."))
                .font(.system(size:10)).foregroundStyle(Palette.muted)
        }.padding(22).background(Palette.panel,in:RoundedRectangle(cornerRadius:14))
    }
    private func preset(mixed: Bool) {
        for device in devices { library.room.roles[device.id]=mixed && !device.isHex ? .ambilight:.music }
        library.saveRoom()
    }
}

struct RoomOutputStatus: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject var live: LiveTelemetry
    let plan: RoomOutputPlan
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Label(tr(plan.ambilightIDs.isEmpty ? "Govee-Gerätemusik / Effekte":"Raum-Mix · getrennte Ausgabe pro Leuchte"),systemImage:"waveform").foregroundStyle(Palette.mint).font(.system(size:12,weight:.semibold))
            ForEach(plan.commands) { command in
                HStack {
                    Text(verbatim:tr(model.devices.first(where:{$0.id == command.device})?.name ?? command.sku)).frame(width:150,alignment:.leading)
                    Text(verbatim:tr(command.displayName)).foregroundStyle(Palette.mint)
                    Spacer(); Text(verbatim:tr("Govee bestätigt")).foregroundStyle(Palette.muted)
                }.font(.system(size:10))
            }
            ForEach(plan.ambilightIDs,id:\.self) { id in
                HStack {
                    Text(verbatim:tr(model.devices.first(where:{$0.id == id})?.name ?? "Ambilight")).frame(width:150,alignment:.leading)
                    Text(verbatim:tr("Ambilight")).foregroundStyle(Palette.mint)
                    ForEach(Array((live.colors[id] ?? []).prefix(12).enumerated()),id:\.offset) { _,rgb in Capsule().fill(Palette.rgb(rgb)).frame(width:12,height:8) }
                    Spacer()
                    Text(verbatim:tr(live.colors[id] == nil ? "Warte auf Bildschirm":String(format:"%.1f FPS",live.fps))).foregroundStyle(Palette.muted)
                }.font(.system(size:10))
            }
            Text(verbatim:tr("Govee-Animationen werden am Gerät dargestellt. Farbvorschau nur für Ambilight.")).font(.system(size:9)).foregroundStyle(Palette.muted)
        }.padding(20).background(Palette.panel,in:RoundedRectangle(cornerRadius:14))
    }
}
