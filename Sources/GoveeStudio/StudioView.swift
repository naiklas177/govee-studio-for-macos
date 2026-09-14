import SwiftUI
import AmbienceCore

struct StudioView: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject private var language=LanguageSettings.shared
    var body: some View {
        VStack(spacing:0) {
            header
            ThinDivider()
            if model.setupTab {
            HStack(spacing:0) {
                DeviceSidebar().frame(width:238)
                Rectangle().fill(Palette.line).frame(width:1)
                EditorView(live:model.live).frame(maxWidth:.infinity,maxHeight:.infinity)
                Rectangle().fill(Palette.line).frame(width:1)
                InspectorView().frame(width:282)
            }
            } else { ShowView(live:model.live).frame(maxWidth:.infinity,maxHeight:.infinity) }
            ThinDivider()
            footer
        }
        .id(language.language)
        .environment(\.locale,Locale(identifier:language.language.rawValue))
        .background(Palette.background)
        .foregroundStyle(Palette.text)
        .preferredColorScheme(.dark)
        .frame(minWidth:1180,minHeight:760)
        .alert("Govee Studio",isPresented:Binding(get:{model.message != nil},set:{if !$0 { model.message=nil }})) {
            if model.message?.contains("Bildschirmaufnahme") == true {
                Button(tr("Einstellungen öffnen")) { model.openScreenPrivacy() }
            }
            Button(tr("OK"),role:.cancel) { model.message=nil }
        } message: { Text(verbatim:tr(model.message ?? "")) }
    }
    private var header: some View {
        HStack(spacing:14) {
            ZStack {
                RoundedRectangle(cornerRadius:11).fill(Palette.mint.opacity(0.10)).frame(width:37,height:37)
                Image(systemName:"waveform.path").font(.system(size:20,weight:.medium)).foregroundStyle(Palette.mint)
            }
            VStack(alignment:.leading,spacing:3) {
                Text(verbatim:tr("Govee Studio")).font(.system(size:16,weight:.semibold))
                Text(verbatim:tr("DESKTOP / LIGHT LAB")).font(.system(size:8,weight:.medium,design:.monospaced)).tracking(1.7).foregroundStyle(Palette.muted)
            }
            HStack(spacing:4) {
                ForEach(ExperienceMode.allCases,id:\.self) { mode in
                    Button { model.activateMode(mode) } label: { Label(tr(mode.rawValue),systemImage:mode.icon) }
                        .buttonStyle(StudioButtonStyle(prominent:!model.setupTab && (model.requestedMode ?? model.show.mode) == mode))
                }
                Button { model.setupTab=true } label: { Label(tr("Setup"),systemImage:"slider.horizontal.3") }
                    .buttonStyle(StudioButtonStyle(prominent:model.setupTab))
            }.padding(.leading,20)
            Spacer()
            Picker("Language / Sprache",selection:$language.language) {
                Text("DE").tag(AppLanguage.de)
                Text("EN").tag(AppLanguage.en)
            }.pickerStyle(.segmented).frame(width:80).accessibilityLabel("Language / Sprache")
            HStack(spacing:7) {
                Circle().fill(model.runState == .syncing ? Palette.mint:Palette.muted).frame(width:6,height:6)
                Text(verbatim:tr(statusText)).font(.system(size:11,weight:.medium,design:.monospaced)).foregroundStyle(model.runState == .syncing ? Palette.mint:Palette.muted)
            }.padding(.horizontal,12).padding(.vertical,8).background(Palette.raised,in:Capsule())
            if model.busy {
                Button { Task { await model.stop() } } label: {
                    Label(tr(model.runState == .starting ? "Abbrechen":"Stoppen"),systemImage:"stop.fill")
                }.buttonStyle(StudioButtonStyle(prominent:true)).disabled(model.runState == .stopping)
            } else if ((model.show.mode == .scenes && model.browseCloud) || (model.show.mode == .music && model.nativeMusic)) && !model.setupTab {
                Text(verbatim:tr("Effekt auswählen")).font(.system(size:11)).foregroundStyle(Palette.muted)
            } else {
                Button { model.begin(output:false) } label: { Label(tr("Vorschau"),systemImage:"eye") }
                    .buttonStyle(StudioButtonStyle())
                Button { model.begin(output:true) } label: { Label(tr(model.show.mode == .ambience ? "Sync starten":"Licht starten"),systemImage:"play.fill") }
                    .buttonStyle(StudioButtonStyle(prominent:true))
                    .disabled(model.devices.filter(\.enabled).isEmpty)
                    .keyboardShortcut(.return,modifiers:.command)
            }
        }.padding(.horizontal,22).frame(height:76)
    }
    private var statusText: String {
        if model.switchingMode { return "MODUSWECHSEL …" }
        if let room=model.activeRoom,!room.ambilightIDs.isEmpty { return "RAUM-MIX LÄUFT" }
        if model.activeCloud != nil { return "GOVEE · BESTÄTIGT" }
        switch model.runState {
        case .idle: return "LOKAL · BEREIT"
        case .starting: return "VERBINDET …"
        case .preview: return "NUR VORSCHAU"
        case .syncing: return model.show.mode == .ambience ? "SYNC LÄUFT":"LICHT LÄUFT"
        case .stopping: return "STOPPT …"
        }
    }
    private var footer: some View {
        HStack(spacing:8) {
            Image(systemName:"lock.shield").foregroundStyle(Palette.mint)
            Text(verbatim:tr(model.activeCloud == nil ? "Lokal auf deinem Mac":"Govee-Geräteeffekt")).font(.system(size:10,weight:.medium))
            Text(verbatim:tr("·")).foregroundStyle(Palette.muted)
            Text(verbatim:tr(model.notice)).font(.system(size:10)).foregroundStyle(Palette.muted).lineLimit(1)
            Spacer()
            Text(verbatim:tr("v0.9.0 · Created by Naiklas")).font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.muted)
        }.padding(.horizontal,20).frame(height:34)
    }
}

struct DeviceSidebar: View {
    @EnvironmentObject var model: StudioModel
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            HStack {
                Eyebrow(text:"Dein Setup")
                Spacer()
                Text(verbatim:tr("\(model.onlineCount)/\(model.devices.count)")).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.mint)
            }.padding(.horizontal,20).padding(.top,26).padding(.bottom,18)
            ScrollView {
                VStack(spacing:9) {
                    ForEach(Array(model.devices.enumerated()),id:\.element.id) { index,device in
                        deviceCard(device,index:index)
                    }
                    if model.devices.isEmpty {
                        VStack(spacing:14) {
                            Image(systemName:"dot.radiowaves.left.and.right").font(.system(size:25)).foregroundStyle(Palette.mint)
                            Text(verbatim:tr(model.scanning ? "Suche deine Leuchten …":"Noch keine Leuchten gefunden")).font(.system(size:12,weight:.medium))
                            Text(verbatim:tr("LAN-Steuerung in Govee Home aktivieren. Mac und Leuchten brauchen dasselbe Netzwerk.")).font(.system(size:11)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                        }.padding(.vertical,28).padding(.horizontal,10)
                    }
                }.padding(.horizontal,12)
            }
            Button { Task { await model.scan() } } label: {
                HStack { Image(systemName:model.scanning ? "antenna.radiowaves.left.and.right":"arrow.clockwise"); Text(verbatim:tr(model.scanning ? "Suche läuft …":"Geräte suchen")); Spacer() }
            }.buttonStyle(.plain).font(.system(size:11,weight:.medium)).foregroundStyle(Palette.muted)
                .padding(20).disabled(model.scanning)
            ThinDivider()
            VStack(alignment:.leading,spacing:13) {
                Eyebrow(text:"Profile")
                HStack(spacing:8) {
                    TextField(tr("Profilname"),text:$model.profileName).textFieldStyle(.plain).font(.system(size:12)).padding(9).background(Palette.raised,in:RoundedRectangle(cornerRadius:7))
                    Button { model.saveProfile() } label: { Image(systemName:"square.and.arrow.down").font(.system(size:14)) }.buttonStyle(.plain).help(tr("Aktuelles Setup als Profil speichern"))
                }
                Menu {
                    if model.profiles.isEmpty { Text(verbatim:tr("Noch keine gespeicherten Profile")) }
                    ForEach(model.profiles) { profile in Button(profile.name) { model.loadProfile(profile) } }
                } label: { HStack { Image(systemName:"square.stack"); Text(verbatim:tr("Profil laden")); Spacer(); Image(systemName:"chevron.down") }.font(.system(size:11)).foregroundStyle(Palette.muted) }
                .menuStyle(.borderlessButton).disabled(model.busy)
                Text(verbatim:tr("Änderungen werden automatisch gesichert.")).font(.system(size:10)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
            }.padding(20)
        }.background(Palette.panel.opacity(0.55))
    }
    private func deviceCard(_ device: DeviceConfig,index: Int) -> some View {
        let selected=model.selectedID == device.id
        let tint=Palette.device(index)
        return Button { model.select(device.id) } label: {
            VStack(alignment:.leading,spacing:13) {
                HStack(spacing:10) {
                    Image(systemName:device.isHex ? "hexagon.fill":"point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size:21)).foregroundStyle(tint).frame(width:28)
                    VStack(alignment:.leading,spacing:4) {
                        Text(device.name).font(.system(size:12,weight:.semibold)).foregroundStyle(Palette.text).lineLimit(1)
                        Text(verbatim:tr(device.sku)).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength:0)
                    Circle().fill(model.isOnline(device) ? Palette.mint:Palette.muted.opacity(0.4)).frame(width:5,height:5)
                }
                HStack {
                    Text(verbatim:tr(device.enabled ? "\(device.mode == .whole ? 1:device.zones.count) Zonen":"Pausiert")).foregroundStyle(device.enabled ? tint:Palette.muted)
                    Spacer()
                    Text(verbatim:tr(device.ip)).foregroundStyle(Palette.muted)
                }.font(.system(size:9,design:.monospaced))
            }.padding(13).background(selected ? tint.opacity(0.08):Palette.raised.opacity(0.25),in:RoundedRectangle(cornerRadius:11))
                .overlay(RoundedRectangle(cornerRadius:11).strokeBorder(selected ? tint.opacity(0.42):Palette.line,lineWidth:1))
        }.buttonStyle(.plain)
    }
}
