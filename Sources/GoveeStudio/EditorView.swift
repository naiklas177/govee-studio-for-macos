import SwiftUI
import AmbienceCore

struct EditorView: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject var live: LiveTelemetry
    var tint: Color { Palette.device(model.devices.firstIndex(where:{$0.id == model.selectedID}) ?? 0) }
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:8) {
                    Eyebrow(text:"01 / Zonen-Editor")
                    Text("Licht folgt deinem Bildschirm.").font(.system(size:24,weight:.medium)).tracking(-0.65)
                    Text("Zieh jedes Segment dorthin, wo es seine Farbe aufnehmen soll.")
                        .font(.system(size:11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength:4)
            }.padding(.top,27).padding(.bottom,24)
            HStack {
                Image(systemName:"display").foregroundStyle(Palette.muted)
                Picker("Bildschirm",selection:$model.displayID) {
                    ForEach(model.displays) { display in Text(display.name).tag(display.id) }
                }.labelsHidden().pickerStyle(.menu).frame(maxWidth:220).disabled(model.busy)
                Spacer()
                Text(live.frame == nil ? "KEINE AUFNAHME":"LIVE-VORSCHAU · 5 HZ")
                    .font(.system(size:8,weight:.medium,design:.monospaced)).tracking(0.5).foregroundStyle(Palette.muted)
            }.padding(.bottom,12)
            stage
                .frame(maxWidth:.infinity,maxHeight:.infinity)
            HStack(spacing:8) {
                Image(systemName:"cursorarrow.motionlines").foregroundStyle(tint)
                Text("Strg/⌘ + Klick: Mehrfachauswahl · Ziehen · Pfeiltasten").font(.system(size:10)).foregroundStyle(Palette.muted)
                Spacer()
                Text("\(model.selectedZone+1) / \(model.selected?.zones.count ?? 0)").font(.system(size:10,design:.monospaced)).foregroundStyle(tint)
            }.padding(.top,12).padding(.bottom,22)
            mappingTools
            ThinDivider().padding(.vertical,20)
            paletteStrip
            metrics.padding(.top,20).padding(.bottom,22)
        }.padding(.horizontal,26)
    }
    private var stage: some View {
        GeometryReader { proxy in
            let width=min(proxy.size.width,proxy.size.height*model.aspect)
            let height=width/model.aspect
            ZStack {
                RoundedRectangle(cornerRadius:15).fill(Palette.panel)
                ZStack {
                    if let image=live.frame {
                        Image(decorative:image,scale:1).resizable().interpolation(.medium)
                    } else { AmbientPlaceholder() }
                    if let device=model.selected {
                        let crop=live.frame == nil ? SampleZone(x:0,y:0,width:1,height:1):live.crop
                        ZoneCanvas(deviceID:device.id,
                                   zones:Array(device.zones.prefix(device.mode == .whole ? 1:84)),
                                   selectedIndex:model.selectedZone,crop:crop,tint:tint,
                                   onSelect:{model.selectedZone=$0},
                                   onPreview:{model.previewZone($0,index:$1,deviceID:device.id)},
                                   onCommit:{model.commitZone($0,index:$1,deviceID:device.id)},
                                   onCommitMany:{model.commitZones($0,deviceID:device.id)})
                            .frame(width:width,height:height)

                    }
                }.clipShape(RoundedRectangle(cornerRadius:15))
                RoundedRectangle(cornerRadius:15).strokeBorder(Color.white.opacity(0.14),lineWidth:1).allowsHitTesting(false)
            }.frame(width:width,height:height)
                .shadow(color:Palette.purple.opacity(0.07),radius:24,y:8)
                .position(x:proxy.size.width/2,y:proxy.size.height/2)
        }
    }
    private var mappingTools: some View {
        HStack(spacing:8) {
            Text("ANORDNEN").font(.system(size:9,weight:.semibold,design:.monospaced)).tracking(1).foregroundStyle(Palette.muted)
            Spacer(minLength:0)
            ForEach(MappingPreset.allCases,id:\.self) { preset in
                Button(preset.rawValue) { model.map(preset) }
                    .buttonStyle(.plain).font(.system(size:10,weight:.medium)).padding(.horizontal,9).padding(.vertical,7)
                    .background(Palette.raised,in:RoundedRectangle(cornerRadius:6))
                    .disabled(model.selected == nil)
            }
        }
    }
    private var paletteStrip: some View {
        VStack(alignment:.leading,spacing:11) {
            HStack {
                Eyebrow(text:"Segmentfarben")
                Spacer()
                Text(model.running ? "LIVE":"START FÜR LIVE-FARBEN").font(.system(size:8,design:.monospaced)).foregroundStyle(Palette.muted)
            }
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:6) {
                    if let device=model.selected {
                        ForEach(0..<(device.mode == .whole ? 1:device.zones.count),id:\.self) { i in
                            Button { model.selectedZone=i } label: {
                                VStack(spacing:6) {
                                    RoundedRectangle(cornerRadius:5)
                                        .fill(segmentColor(device:device,index:i)).frame(width:30,height:24)
                                        .overlay(RoundedRectangle(cornerRadius:5).strokeBorder(model.selectedZone == i ? tint:Palette.line,lineWidth:model.selectedZone == i ? 2:1))
                                    Text(String(format:"%02d",i+1)).font(.system(size:8,design:.monospaced)).foregroundStyle(model.selectedZone == i ? tint:Palette.muted)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    private func segmentColor(device: DeviceConfig,index: Int) -> Color {
        guard model.running, let colors=live.colors[device.id],colors.indices.contains(index) else { return Palette.raised }
        return Palette.rgb(colors[index])
    }
    private var metrics: some View {
        HStack(spacing:0) {
            metric("BILDRATE",value:model.running ? String(format:"%.1f",live.fps):"—",unit:"fps")
            Spacer()
            metric("VERARBEITUNG",value:model.running ? String(format:"%.2f",live.workMS):"—",unit:"ms / Frame")
            Spacer()
            metric("AKTIVE ZONEN",value:"\(model.segmentCount)",unit:"gesamt")
        }.padding(16).background(Palette.panel,in:RoundedRectangle(cornerRadius:11))
    }
    private func metric(_ label: String,value: String,unit: String) -> some View {
        VStack(alignment:.leading,spacing:6) {
            Text(label).font(.system(size:8,weight:.medium,design:.monospaced)).tracking(0.8).foregroundStyle(Palette.muted)
            HStack(alignment:.firstTextBaseline,spacing:5) {
                Text(value).font(.system(size:19,weight:.medium,design:.monospaced)).foregroundStyle(Palette.text)
                Text(unit).font(.system(size:8)).foregroundStyle(Palette.muted)
            }
        }
    }
}

struct AmbientPlaceholder: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors:[Color(red:0.04,green:0.07,blue:0.13),Color(red:0.14,green:0.08,blue:0.24),Color(red:0.03,green:0.15,blue:0.20)],startPoint:.topLeading,endPoint:.bottomTrailing)
                Ellipse().fill(Palette.purple.opacity(0.55)).frame(width:g.size.width*0.65,height:g.size.height*0.3).blur(radius:35).rotationEffect(.degrees(-28)).offset(x:-g.size.width*0.15,y:-g.size.height*0.05)
                Ellipse().fill(Palette.mint.opacity(0.4)).frame(width:g.size.width*0.58,height:g.size.height*0.22).blur(radius:30).rotationEffect(.degrees(-28)).offset(x:g.size.width*0.18,y:g.size.height*0.13)
                Canvas { context,size in
                    for i in 0..<12 {
                        var path=Path()
                        let base=size.height*(0.25+Double(i)*0.04)
                        path.move(to:CGPoint(x:-30,y:base+size.height*0.4))
                        path.addCurve(to:CGPoint(x:size.width+30,y:base-size.height*0.3),control1:CGPoint(x:size.width*0.3,y:base-size.height*0.35),control2:CGPoint(x:size.width*0.65,y:base+size.height*0.4))
                        context.stroke(path,with:.color(.white.opacity(0.035)),lineWidth:1)
                    }
                }
                VStack(spacing:9) {
                    Image(systemName:"display").font(.system(size:27,weight:.ultraLight))
                    Text("Dein Bildschirm wird zur Lichtquelle.").font(.system(size:12,weight:.medium))
                    Text("Vorschau starten, um Farben live zu sehen.").font(.system(size:10)).foregroundStyle(.white.opacity(0.4))
                }.foregroundStyle(.white.opacity(0.6)).allowsHitTesting(false)
            }
        }
    }
}
