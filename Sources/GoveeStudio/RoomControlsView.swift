import SwiftUI
import AmbienceCore

struct RoomControlsView: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject var library: CloudLibrary
    private var usesScreen: Bool { model.devices.contains { $0.enabled && library.room.role($0) == .ambilight } }
    private var brightness: Double { library.room.musicBrightness ?? Double(model.devices.compactMap { model.states[$0.ip]?.brightness }.first ?? 65) }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                Eyebrow(text:"Raum / Regiepult")
                Text("Dein Raum. Dein Pegel.").font(.system(size:21,weight:.medium))
                control("Musik-Helligkeit",value:Binding(get:{brightness},set:{library.room.musicBrightness=$0}),range:1...100,label:library.room.musicBrightness == nil ? "Gerätewerte":"\(Int(brightness)) %")
                Text("Lichtintensität der Govee-Musikgeräte. Kein zusätzliches Grundlicht in Musikpausen.").font(.system(size:10)).foregroundStyle(Palette.muted)
                control("Musik-Empfindlichkeit",value:$library.room.sensitivity,range:0...100,label:"\(Int(library.room.sensitivity)) %")
                ThinDivider()
                Eyebrow(text:"Farbschema")
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:8) {
                    ForEach(RoomColorScheme.allCases,id:\.self) { scheme in
                        Button { library.room.colorScheme=scheme } label: {
                            VStack(alignment:.leading,spacing:8) {
                                HStack(spacing:4) {
                                    ForEach(Array(scheme.palette.enumerated()),id:\.offset) { _,color in Circle().fill(Palette.rgb(color)).frame(width:9,height:9) }
                                    if scheme == .custom { Image(systemName:"slider.horizontal.3").foregroundStyle(Palette.mint) }
                                }.frame(height:10)
                                Text(scheme.rawValue).font(.system(size:10,weight:.medium))
                            }.frame(maxWidth:.infinity,alignment:.leading).padding(10).background(library.room.colorScheme == scheme ? Palette.mint.opacity(0.15):Palette.raised,in:RoundedRectangle(cornerRadius:8))
                        }.buttonStyle(.plain).accessibilityLabel("Raum-Farbschema \(scheme.rawValue)")
                    }
                }
                Text(library.room.colorScheme == .automatic ? "Govee bestimmt die Farben seiner internen Animation.":"Eine feste Farbe je Musikgerät, als abgestimmtes Schema im Raum verteilt. Die Animation bleibt beim Gerät.").font(.system(size:10)).foregroundStyle(Palette.muted)
                if library.room.colorScheme == .custom {
                    control("Eigene Musikfarbe",value:$library.room.hue,range:0...1,label:"\(Int(library.room.hue*360))°")
                    LinearGradient(colors:[.red,.yellow,.green,.cyan,.blue,.purple,.red],startPoint:.leading,endPoint:.trailing).frame(height:4).clipShape(Capsule())
                }
                if usesScreen {
                    ThinDivider();Eyebrow(text:"Ambilight / Grundlicht")
                    control("Helligkeit",value:$library.room.ambientGain,range:0...1,label:"\(Int(library.room.ambientGain*100)) %")
                    control("Sättigung",value:Binding(get:{library.room.ambientSaturation ?? model.settings.saturation},set:{library.room.ambientSaturation=$0}),range:0...2,label:"\(Int((library.room.ambientSaturation ?? model.settings.saturation)*100)) %")
                    control("Glättung",value:Binding(get:{library.room.ambientSmoothing ?? model.settings.smoothing},set:{library.room.ambientSmoothing=$0}),range:0...1.5,label:"\(Int((library.room.ambientSmoothing ?? model.settings.smoothing)*1000)) ms")
                    Text("Nur für die als Ambilight zugeordneten Leuchten.").font(.system(size:10)).foregroundStyle(Palette.muted)
                }
                ThinDivider()
                Button(model.roomApplying ? "Wird übernommen …":"Regler übernehmen") { model.applyRoomControls() }.buttonStyle(StudioButtonStyle(prominent:true)).disabled(model.activeRoom == nil || model.roomApplying || model.switchingMode)
                Text("Während der Ausgabe ohne kompletten Neustart. Neue Gerätezuordnung: Raum-Musik starten.").font(.system(size:10)).foregroundStyle(Palette.muted)
                Text("Geschwindigkeit und Nachleuchten steuert der Govee-Modus selbst. Separate Regler dafür oder für ein Musik-Mindestlicht bietet diese API nicht.").font(.system(size:10)).foregroundStyle(Palette.muted)
            }.padding(22)
        }.background(Palette.panel.opacity(0.45))
    }
    private func control(_ title: String,value: Binding<Double>,range: ClosedRange<Double>,label: String) -> some View {
        VStack(spacing:9) {
            HStack { Text(title).font(.system(size:11,weight:.medium)); Spacer(); Text(label).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.mint) }
            Slider(value:value,in:range).tint(Palette.mint).controlSize(.small)
        }
    }
}
