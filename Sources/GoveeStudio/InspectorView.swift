import SwiftUI
import AmbienceCore

struct InspectorView: View {
    @EnvironmentObject var model: StudioModel
    @State private var advanced=false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                Eyebrow(text:"02 / Feinabstimmung")
                if let device=model.selected {
                    deviceControls(device)
                    ThinDivider()
                    zoneControls(device)
                    ThinDivider()
                }
                ChannelLab()
                globalControls
                if model.recoveryAvailable {
                    VStack(alignment:.leading,spacing:10) {
                        Text("Vorherige Sitzung").font(.system(size:12,weight:.semibold))
                        Text("Gesicherte Lichtwerte sind noch vorhanden.").font(.system(size:10)).foregroundStyle(Palette.muted)
                        Button("Lichtwerte wiederherstellen") { Task { await model.recoverPrevious() } }
                            .buttonStyle(StudioButtonStyle()).disabled(model.busy)
                    }.padding(12).background(Palette.purple.opacity(0.12),in:RoundedRectangle(cornerRadius:9))
                }
            }.padding(20).padding(.top,7)
        }.background(Palette.panel.opacity(0.55))
    }
    private func deviceControls(_ device: DeviceConfig) -> some View {
        VStack(alignment:.leading,spacing:15) {
            TextField("Gerätename",text:Binding(get:{model.selected?.name ?? ""},set:{value in model.editSelected{$0.name=value}}))
                .font(.system(size:18,weight:.medium)).textFieldStyle(.plain)
            HStack {
                Text("Im Sync verwenden").font(.system(size:11))
                Spacer()
                Toggle("Im Sync verwenden",isOn:Binding(get:{model.selected?.enabled ?? false},set:{value in model.editSelected{$0.enabled=value}}))
                    .labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(Palette.mint).disabled(model.busy)
            }
            slider("Helligkeit",value:Binding(get:{model.selected?.gain ?? 0.5},set:{value in model.editSelected{$0.gain=value}}),range:0...1,display:"\(Int(device.gain*100)) %")
            HStack {
                Text("Segmente").font(.system(size:11))
                Spacer()
                Stepper(value:Binding(get:{model.selected?.zones.count ?? 1},set:{model.setCount($0)}),in:1...84) {
                    Text("\(device.zones.count)").font(.system(size:12,design:.monospaced)).frame(minWidth:22)
                }.fixedSize().disabled(model.busy || device.mode == .whole)
            }
            if !device.calibrated {
                Text("Startwert · Anzahl und Reihenfolge am Gerät prüfen.")
                    .font(.system(size:10)).foregroundStyle(Color.orange.opacity(0.85)).fixedSize(horizontal:false,vertical:true)
            }
            Toggle("Reihenfolge umkehren",isOn:Binding(get:{model.selected?.reverse ?? false},set:{value in model.editSelected{$0.reverse=value}}))
                .font(.system(size:11)).toggleStyle(.checkbox)
            DisclosureGroup(isExpanded:$advanced) {
                VStack(alignment:.leading,spacing:12) {
                    Picker("Ausgabe",selection:Binding(get:{model.selected?.mode ?? .whole},set:{value in model.editSelected{$0.mode=value}})) {
                        ForEach(OutputMode.allCases,id:\.self) { Text($0.rawValue).tag($0) }
                    }.font(.system(size:10)).disabled(model.busy)
                    if device.mode == .dreamview {
                        Picker("Protokoll",selection:Binding(get:{model.selected?.header ?? .automatic},set:{value in model.editSelected{$0.header=value}})) {
                            ForEach(StreamHeader.allCases,id:\.self) { Text($0.label).tag($0) }
                        }.font(.system(size:10)).disabled(model.busy)
                        Toggle("Auf Gerät strecken",isOn:Binding(get:{model.selected?.stretch ?? false},set:{value in model.editSelected{$0.stretch=value}}))
                            .font(.system(size:10)).toggleStyle(.checkbox).disabled(model.busy)
                    }
                    Toggle("Zuordnung geprüft",isOn:Binding(get:{model.selected?.calibrated ?? false},set:{value in model.editSelected{$0.calibrated=value}}))
                        .font(.system(size:10)).toggleStyle(.checkbox)
                    Text("DreamView nutzt ein nicht öffentlich dokumentiertes Protokoll. Einzelfarbe ist der einfachere LAN-Modus.")
                        .font(.system(size:10)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                }.padding(.top,10)
            } label: { Text("Geräteoptionen").font(.system(size:11)).foregroundStyle(Palette.muted) }
        }
    }
    private func zoneControls(_ device: DeviceConfig) -> some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Eyebrow(text:"Zone \(model.selectedZone+1)"); Spacer(); Image(systemName:"viewfinder").foregroundStyle(Palette.muted) }
            if device.zones.indices.contains(model.selectedZone) {
                HStack(spacing:10) {
                    coordinate("X",keyPath:\.x)
                    coordinate("Y",keyPath:\.y)
                }
                HStack(spacing:10) {
                    coordinate("Breite",keyPath:\.width)
                    coordinate("Höhe",keyPath:\.height)
                }
            }
            Button { model.beginIdentify() } label: {
                HStack { Image(systemName:"lightbulb.max"); Text(model.testActive ? "Test läuft …":"Segment kurz testen"); Spacer() }
            }.buttonStyle(StudioButtonStyle()).disabled(model.busy)
            Text("Leuchtet kurz türkis. Danach werden die vorherigen Grundwerte zurückgesendet.")
                .font(.system(size:9)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
        }
    }
    private func coordinate(_ title: String,keyPath: WritableKeyPath<SampleZone,Double>) -> some View {
        HStack(spacing:4) {
            Text(title).font(.system(size:9)).foregroundStyle(Palette.muted)
            Spacer(minLength:0)
            TextField(title,value:Binding<Double>(get:{
                guard let d=model.selected,d.zones.indices.contains(model.selectedZone) else { return 0 }
                return d.zones[model.selectedZone][keyPath:keyPath]*100
            },set:{ value in
                guard let d=model.selected,d.zones.indices.contains(model.selectedZone) else { return }
                var zone=d.zones[model.selectedZone]; zone[keyPath:keyPath]=value/100; zone.clamp()
                model.setZone(zone,index:model.selectedZone)
            }),format:.number.precision(.fractionLength(1)))
            .font(.system(size:11,design:.monospaced)).textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width:40)
            Text("%").font(.system(size:9)).foregroundStyle(Palette.muted)
        }.padding(9).background(Palette.raised,in:RoundedRectangle(cornerRadius:6))
    }
    private var globalControls: some View {
        VStack(alignment:.leading,spacing:15) {
            Eyebrow(text:"Gesamtes Setup")
            slider("Master-Helligkeit",value:setting(\.masterGain),range:0...1,display:"\(Int(model.settings.masterGain*100)) %")
            slider("Weiche Übergänge",value:setting(\.smoothing),range:0...0.6,display:"\(Int(model.settings.smoothing*1000)) ms")
            slider("Sättigung",value:setting(\.saturation),range:0...2,display:String(format:"%.0f %%",model.settings.saturation*100))
            HStack {
                Text("Farbupdates").font(.system(size:11))
                Spacer()
                Picker("Farbupdates",selection:Binding(get:{model.settings.fps},set:{model.settings.fps=$0;model.changed()})) {
                    ForEach([10,15,20,25,30,40],id:\.self) { Text("\($0) fps").tag($0) }
                }.labelsHidden().frame(width:88).disabled(model.busy)
            }
            Toggle("Schwarze Filmbalken erkennen",isOn:Binding(get:{model.settings.cropBars},set:{model.settings.cropBars=$0;model.changed()}))
                .font(.system(size:10)).toggleStyle(.checkbox)
            Text("Beim Stoppen: Grundfarbe, Helligkeit und Ein/Aus zurücksetzen. Govee-Szenen können nicht rekonstruiert werden.")
                .font(.system(size:9)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
        }
    }
    private func setting(_ keyPath: WritableKeyPath<StudioSettings,Double>) -> Binding<Double> {
        Binding(get:{model.settings[keyPath:keyPath]},set:{model.settings[keyPath:keyPath]=$0;model.changed()})
    }
    private func slider(_ title: String,value: Binding<Double>,range: ClosedRange<Double>,display: String) -> some View {
        VStack(spacing:6) {
            HStack { Text(title).font(.system(size:11)); Spacer(); Text(display).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.muted) }
            Slider(value:value,in:range).controlSize(.mini).tint(Palette.mint)
        }
    }
}
