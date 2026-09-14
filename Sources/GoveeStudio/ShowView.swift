import SwiftUI
import AmbienceCore

struct ShowView: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject var live: LiveTelemetry
    var body: some View {
        HStack(alignment:.top,spacing:0) {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    HStack(alignment:.top) {
                        VStack(alignment:.leading,spacing:9) {
                            Eyebrow(text:"Desktop / Lichtlabor")
                            Text(model.show.mode == .ambience ? "Dein Bildschirm.\nEin ganzer Raum." : (model.show.mode == .music ? "Dein Sound.\nDein Licht.":(model.browseCloud ? "Originale.\nNeue Eskalation.":model.show.scene.rawValue + ".\nLicht mit Charakter.")))
                                .font(.system(size:36,weight:.semibold)).tracking(-1.4)
                            Text(model.show.mode == .ambience ? "Farben direkt vom Desktop. Dein Mapping wartet im Setup." : (model.show.mode == .music ? "Reaktion und Farben direkt auf deine Musik abstimmen.":(model.browseCloud ? "Die Govee-Bibliothek für deine Geräte.":model.show.scene.subtitle)))
                                .font(.system(size:12)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Text(model.show.mode == .music ? "AUDIO → LICHT" : "LOKALE LICHTSZENEN")
                            .font(.system(size:9,design:.monospaced)).tracking(1.2)
                            .foregroundStyle(Palette.mint).padding(10)
                            .background(Palette.mint.opacity(0.08),in:Capsule())
                    }
                    if let plan=model.activeRoom {
                        RoomOutputStatus(live:live,plan:plan)
                    } else if let scene=model.activeCloud {
                        VStack(alignment:.leading,spacing:10) {
                            Label("Govee-Effekt · Befehl bestätigt",systemImage:"cloud.fill").foregroundStyle(Palette.mint)
                            Text(scene.displayName).font(.system(size:22,weight:.semibold))
                            Text("Auf " + (model.devices.first(where:{$0.id == scene.device})?.name ?? scene.sku) + " · Die Animation wird vom Gerät dargestellt. Keine Live-Vorschau verfügbar.").font(.system(size:11)).foregroundStyle(Palette.muted)
                        }.frame(maxWidth:.infinity,alignment:.leading).padding(22).background(Palette.panel,in:RoundedRectangle(cornerRadius:14))
                    } else if (!model.browseCloud || model.show.mode != .scenes) && !(model.show.mode == .music && model.nativeMusic) {
                        LightStage(live:live).frame(height:model.show.mode == .music ? 180:240)
                    }
                    if model.show.mode == .music {
                        Picker("Musikquelle",selection:$model.nativeMusic) {
                            Text("Mac · Systemaudio").tag(false)
                            Text("Govee · Geräte-Musik").tag(true)
                        }.pickerStyle(.segmented)
                        if model.nativeMusic { NativeMusicView(library:model.cloud) }
                        else { MusicDeck(live:live) }
                    } else if model.show.mode == .scenes {
                        Picker("Szenenquelle",selection:$model.browseCloud) {
                            Text("Studio · Lokal").tag(false)
                            Text("Govee · Original & DIY").tag(true)
                        }.pickerStyle(.segmented)
                        if model.browseCloud { CloudLibraryView(library:model.cloud) } else {
                        HStack { Eyebrow(text:"Wähle deinen Zustand"); Spacer(); Text("LIVE WECHSELBAR").font(.system(size:8,design:.monospaced)).foregroundStyle(Palette.muted) }
                        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                            ForEach(LightScene.allCases,id:\.self) { scene in sceneCard(scene) }
                        }
                        }
                    } else {
                        HStack(spacing:18) {
                            Image(systemName:"viewfinder").font(.system(size:28)).foregroundStyle(Palette.mint)
                            VStack(alignment:.leading,spacing:5) {
                                Text("Dein Mapping bleibt dein Mapping.").font(.system(size:15,weight:.medium))
                                Text("Zonen verschieben, Geräte zuordnen und kalibrieren: alles im Setup-Tab.").font(.system(size:11)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Button("Setup öffnen") { model.setupTab=true }.buttonStyle(StudioButtonStyle())
                        }.padding(20).background(Palette.panel,in:RoundedRectangle(cornerRadius:12))
                    }
                }.padding(28)
            }
            Rectangle().fill(Palette.line).frame(width:1)
            if model.show.mode == .music && model.nativeMusic {
                RoomControlsView(library:model.cloud).frame(width:290)
            } else if model.activeCloud != nil || (model.show.mode == .scenes && model.browseCloud) {
                VStack(alignment:.leading,spacing:16) {
                    Eyebrow(text:"Govee / Geräte-Effekte")
                    Text("Der Effekt übernimmt.").font(.system(size:21,weight:.medium))
                    Text("Original- und DIY-Effekte besitzen ihre eigenen Farben und Abläufe. Unsere Regler für Musik und lokale Szenen wirken hier nicht.").font(.system(size:12)).foregroundStyle(Palette.muted)
                    Text("Pro Leuchte übernimmt genau eine Quelle. Im Raum-Mix können Govee-Gerätemusik und Ambilight auf verschiedenen Leuchten gleichzeitig laufen. Änderungen in der Zuordnung werden beim Start übernommen.").font(.system(size:11)).foregroundStyle(Palette.muted)
                    Spacer()
                }.padding(22).frame(width:290)
            } else { controls.frame(width:290) }
        }
    }
    private func sceneCard(_ scene: LightScene) -> some View {
        let selected=model.show.scene == scene
        return Button { model.chooseScene(scene) } label: {
            VStack(alignment:.leading,spacing:10) {
                HStack(spacing:5) {
                    ForEach(0..<3) { i in Capsule().fill(Palette.rgb(scene.palette[i])).frame(height:4) }
                }
                HStack { Text(scene.rawValue).font(.system(size:13,weight:.semibold)); Spacer(); if selected { Image(systemName:"checkmark.circle.fill").foregroundStyle(Palette.mint) } }
                Text(scene.subtitle).font(.system(size:10)).foregroundStyle(Palette.muted).lineLimit(2).frame(height:28,alignment:.topLeading)
            }.padding(14).background(selected ? Palette.purple.opacity(0.13):Palette.panel,in:RoundedRectangle(cornerRadius:12))
                .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(selected ? Palette.purple.opacity(0.7):Palette.line))
        }.buttonStyle(.plain)
    }
    private var controls: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                Eyebrow(text:"Regiepult")
                VStack(alignment:.leading,spacing:8) {
                    Text(model.show.mode == .music ? "Der Bass darf rein." : "Du hast den Regler.").font(.system(size:21,weight:.medium)).tracking(-0.5)
                    Text(model.show.mode == .music ? "Mac-Systemaudio · kein Mikrofon. Bass, Mitten und Höhen treiben unterschiedliche Kanäle." : "Lokale Ausgabe auf deinem gesamten aktivierten Setup.")
                        .font(.system(size:11)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                }
                slider("Master-Helligkeit",value:Binding(get:{model.settings.masterGain},set:{model.settings.masterGain=$0;model.changed()}),range:0...1,display:"\(Int(model.settings.masterGain*100)) %")
                if model.show.mode != .ambience {
                    ThinDivider()
                    if model.show.mode == .music {
                        Picker("Hintergrund",selection:Binding(get:{model.show.musicBackground.enabled},set:{model.show.musicBackground.enabled=$0;model.showChanged()})) {
                            Text("Farbe").tag(false)
                            Text("Ambilight").tag(true)
                        }.pickerStyle(.segmented).disabled(model.busy)
                        if model.busy { Text("Zum Wechsel der Hintergrundquelle kurz stoppen.").font(.system(size:9)).foregroundStyle(Palette.muted) }
                    }
                    if model.show.mode == .music && model.show.musicBackground.enabled {
                        Eyebrow(text:"Ambilight / Hintergrund")
                        Text(live.report.backgroundFrames > 0 ? "Bildschirmfarben empfangen":"Warte auf Bildschirmfarben").font(.system(size:9)).foregroundStyle(Palette.muted)
                        slider("Ambilight-Helligkeit",value:ambientSetting(\.gain),range:0...1,display:"\(Int(model.show.musicBackground.gain*100)) %")
                        slider("Ambilight-Sättigung",value:ambientSetting(\.saturation),range:0...2,display:"\(Int(model.show.musicBackground.saturation*100)) %")
                        slider("Ambilight-Glättung",value:ambientSetting(\.smoothing),range:0...1.5,display:"\(Int(model.show.musicBackground.smoothing*1000)) ms")
                        Toggle("Filmbalken ausblenden",isOn:Binding(get:{model.show.musicBackground.cropBars},set:{model.show.musicBackground.cropBars=$0;model.showChanged()})).font(.system(size:10))
                        Text("Bildschirm und Zonen aus Setup. Musik und Hintergrund werden separat geglättet.").font(.system(size:10)).foregroundStyle(Palette.muted)
                    } else {
                    slider("Grundhelligkeit",value:setting(\.background),range:0...1,display:"\(Int(model.show.background*100)) %")
                    slider("Hintergrundfarbe",value:setting(\.backgroundHue),range:0...1,display:"\(Int(model.show.backgroundHue*360))°")
                    LinearGradient(colors:[.red,.yellow,.green,.cyan,.blue,.purple,.red],startPoint:.leading,endPoint:.trailing).frame(height:4).clipShape(Capsule()).padding(.top,-17)
                    }
                    ThinDivider()
                    slider("Effektintensität",value:setting(\.intensity),range:0...4,display:"\(Int(model.show.intensity*100)) %")
                    slider("Bewegung",value:setting(\.speed),range:0.05...2,display:String(format:"%.2f ×",model.show.speed))
                    if (model.show.mode == .scenes && (model.show.scene == .meteor || model.show.scene == .implosion)) || (model.show.mode == .music && (model.show.musicPattern == .chase || model.show.musicPattern == .wave)) {
                        slider("Schweiflänge",value:setting(\.trail),range:0.05...0.8,display:"\(Int(model.show.trail*100)) %")
                        Toggle("Effektrichtung umkehren",isOn:Binding(get:{model.show.reverseMotion},set:{model.show.reverseMotion=$0;model.showChanged()})).font(.system(size:10))
                        Text("Bewegung folgt der Kanalfolge pro Gerät.").font(.system(size:10)).foregroundStyle(Palette.muted)
                    }
                }
                if model.show.mode == .music {
                    ThinDivider()
                    slider("Musik-Sättigung",value:setting(\.musicSaturation),range:0...2,display:"\(Int(model.show.musicSaturation*100)) %")
                    slider("Empfindlichkeit",value:setting(\.sensitivity),range:0.2...5,display:String(format:"%.1f ×",model.show.sensitivity))
                    slider("Nachglühen",value:setting(\.decay),range:0.04...1.5,display:"\(Int(model.show.decay*1000)) ms")
                    Text(model.show.musicBackground.enabled ? "Bei Stille läuft Ambilight weiter. Musik liegt darüber; Master und Gerätehelligkeit begrenzen die Gesamtausgabe.":"Bei Stille bleibt nur dein Grundlicht. Die Vorschau hört ebenfalls Systemaudio, sendet aber nichts an die Leuchten.").font(.system(size:10)).foregroundStyle(Palette.muted)
                }
                ThinDivider()
                HStack { Eyebrow(text:"Verbunden"); Spacer(); Text("\(model.onlineCount)/\(model.devices.count)").foregroundStyle(Palette.mint).monospacedDigit() }
                ForEach(model.devices) { device in
                    HStack { Circle().fill(model.isOnline(device) ? Palette.mint:Palette.muted).frame(width:5,height:5); Text(device.name).font(.system(size:11)); Spacer(); Text(device.enabled ? "AN":"AUS").font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.muted) }
                }
                Text("Stoppen setzt die gespeicherten Grundwerte deiner Leuchten zurück.").font(.system(size:10)).foregroundStyle(Palette.muted)
            }.padding(22)
        }.background(Palette.panel.opacity(0.45))
    }
    private func ambientSetting(_ key: WritableKeyPath<MusicAmbilight,Double>) -> Binding<Double> { Binding(get:{model.show.musicBackground[keyPath:key]},set:{model.show.musicBackground[keyPath:key]=$0;model.showChanged()}) }
    private func setting(_ key: WritableKeyPath<ShowSettings,Double>) -> Binding<Double> { Binding(get:{model.show[keyPath:key]},set:{model.show[keyPath:key]=$0;model.showChanged()}) }
    private func slider(_ title: String,value: Binding<Double>,range: ClosedRange<Double>,display: String) -> some View {
        VStack(spacing:9) {
            HStack { Text(title).font(.system(size:11,weight:.medium)); Spacer(); Text(display).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.mint) }
            Slider(value:value,in:range).tint(Palette.mint).controlSize(.small)
        }
    }
}

struct MusicDeck: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject var live: LiveTelemetry
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack { Eyebrow(text:"Audio / Reaktion"); Spacer(); Text("LIVE EINSTELLBAR").font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.mint) }
            Text("Mac-Reaktionen laufen über Panel- und Strip-Kanäle. Einzelne Hexagon-Teilflächen sind hier noch nicht frei adressierbar.").font(.system(size:10)).foregroundStyle(Palette.muted)
            HStack(alignment:.top,spacing:24) {
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:8) {
                    ForEach(MusicPattern.allCases,id:\.self) { pattern in
                        Button { model.show.musicPattern=pattern;model.showChanged(); if model.activeCloud != nil { model.activateMode(.music) } } label: {
                            HStack(spacing:12) {
                                Image(systemName:pattern.icon).frame(width:22).foregroundStyle(Palette.mint)
                                VStack(alignment:.leading,spacing:4) {
                                    Text(pattern.rawValue).font(.system(size:12,weight:.semibold))
                                    Text(pattern.detail).font(.system(size:10)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                                }
                                Spacer()
                                Image(systemName:model.show.musicPattern == pattern ? "largecircle.fill.circle":"circle").foregroundStyle(Palette.mint)
                            }.frame(minHeight:84,alignment:.leading).padding(11).background(model.show.musicPattern == pattern ? Palette.mint.opacity(0.08):Palette.raised.opacity(0.3),in:RoundedRectangle(cornerRadius:8))
                        }.buttonStyle(.plain)
                    }
                }.frame(maxWidth:.infinity)
                VStack(alignment:.leading,spacing:20) {
                    AudioMeter(live:live)
                    Eyebrow(text:"Musikfarben")
                    Picker("Farbverhalten",selection:Binding(get:{model.show.musicColorFlow},set:{model.show.musicColorFlow=$0;model.showChanged()})) {
                        ForEach(MusicColorFlow.allCases,id:\.self) { flow in Text(flow.rawValue).tag(flow) }
                    }.labelsHidden().accessibilityLabel("Farbverhalten")
                    if model.show.musicSaturation < 0.5 {
                        Button("Satte Farben aktivieren") { model.show.musicSaturation=1.1;model.showChanged() }.buttonStyle(StudioButtonStyle())
                        Text("Aktuell \(Int(model.show.musicSaturation*100)) % Sättigung – Farben sind fast weiß.").font(.system(size:9)).foregroundStyle(Palette.muted)
                    }
                    ForEach(MusicColors.allCases,id:\.self) { colors in
                        Button { model.show.musicColors=colors;model.showChanged() } label: {
                            HStack(spacing:6) {
                                ForEach(0..<3) { i in Circle().fill(Palette.rgb(colors.palette[i])).frame(width:13,height:13) }
                                Text(colors.rawValue).font(.system(size:11)).padding(.leading,4)
                                Spacer()
                                if model.show.musicColors == colors { Image(systemName:"checkmark").foregroundStyle(Palette.mint) }
                            }
                        }.buttonStyle(.plain)
                    }
                }.frame(width:190)
            }
        }.padding(20).background(Palette.panel,in:RoundedRectangle(cornerRadius:14))
    }
}

struct AudioMeter: View {
    @ObservedObject var live: LiveTelemetry
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Eyebrow(text:live.report.audioReceiving ? "Systemaudio empfangen":"Warte auf Systemaudio")
            HStack(alignment:.bottom,spacing:8) {
                bar("BASS",level:live.report.audio.bass,color:Palette.purple)
                bar("MITTEN",level:live.report.audio.mid,color:Palette.mint)
                bar("HÖHEN",level:live.report.audio.high,color:.pink)
            }
        }
    }
    private func bar(_ title: String,level: Double,color: Color) -> some View {
        VStack(spacing:7) {
            GeometryReader { g in
                ZStack(alignment:.bottom) {
                    RoundedRectangle(cornerRadius:4).fill(Palette.raised)
                    RoundedRectangle(cornerRadius:4).fill(color).frame(height:max(2,g.size.height*min(1,level*8)))
                }
            }.frame(height:44)
            Text(title).font(.system(size:8,design:.monospaced)).foregroundStyle(Palette.muted)
            Text(level > 0.00001 ? String(format:"%.0f dB",20*log10(level)):"−∞ dB").font(.system(size:8,design:.monospaced)).foregroundStyle(Palette.muted)
        }
    }
}

struct LightStage: View {
    @EnvironmentObject var model: StudioModel
    @ObservedObject var live: LiveTelemetry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval:0.05,paused:reduceMotion || model.running)) { context in
            VStack(alignment:.leading,spacing:14) {
                HStack {
                    Eyebrow(text:model.running ? (model.runState == .preview ? "Berechnete Farben / keine Lichtausgabe":"Ausgabefarben / Kanalvorschau"):"Look-Vorschau / keine Lichtausgabe")
                    Spacer()
                    Text(model.running ? String(format:"%.1f FPS",live.fps):"READY").font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.mint)
                }
                Canvas { canvas,size in
                    let devices=model.devices.filter(\.enabled)
                    let rows=max(1,devices.count), rowHeight=(size.height-12)/Double(rows)
                    for (index,device) in devices.enumerated() {
                        let count=model.show.mode == .ambience ? device.zones.count:model.show.count(for:device)
                        let time=reduceMotion ? 0:context.date.timeIntervalSinceReferenceDate
                        let fallback=model.show.mode == .ambience ? Array(repeating:RGB(35,60,75),count:count):ShowRenderer.colors(count:count,time:time,offset:Double(index)*0.17,settings:model.show)
                        let colors=model.running ? (live.colors[device.id] ?? fallback):fallback
                        let label=Text(device.name).font(.system(size:10,weight:.medium)).foregroundColor(Palette.muted)
                        canvas.draw(label,at:CGPoint(x:0,y:Double(index)*rowHeight+rowHeight/2),anchor:.leading)
                        let start=125.0, usable=max(1,size.width-start), width=usable/Double(max(1,colors.count))
                        for (i,rgb) in colors.enumerated() {
                            let rect=CGRect(x:start+Double(i)*width,y:Double(index)*rowHeight+7,width:max(2,width-4),height:max(10,rowHeight-14))
                            let path=device.isHex ? Hexagon().path(in:rect):Path(roundedRect:rect,cornerRadius:4)
                            canvas.fill(path,with:.color(Palette.rgb(rgb)))
                            canvas.stroke(path,with:.color(.white.opacity(0.12)),lineWidth:0.6)
                        }
                    }
                    if devices.isEmpty { canvas.draw(Text("Dein Licht wartet im Setup.").foregroundColor(Palette.muted),at:CGPoint(x:size.width/2,y:size.height/2)) }
                }
            }.padding(20)
                .background(LinearGradient(colors:[Palette.purple.opacity(0.12),Palette.panel,Palette.mint.opacity(0.05)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:18))
                .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(Palette.line))
        }
    }
}

struct ChannelLab: View {
    @EnvironmentObject var model: StudioModel
    var body: some View {
        if let device=model.selected,device.isHex {
            VStack(alignment:.leading,spacing:12) {
                Eyebrow(text:"Hexagon / Kanal-Labor")
                Text("Flächen & Linien erkunden").font(.system(size:14,weight:.medium))
                Text("Experimentelle Kanalzahl für Szenen und Musik. Die Zuordnung zu Teilflächen ist noch nicht bestätigt; mehr Kanäle bedeuten nicht automatisch mehr adressierbare LEDs.")
                    .font(.system(size:10)).foregroundStyle(Palette.muted)
                Stepper(value:Binding(get:{model.show.count(for:device)},set:{model.show.channelCounts[device.id]=$0;model.probeChannel=min(model.probeChannel,$0-1);model.showChanged()}),in:1...84) {
                    Text("\(model.show.count(for:device)) Show-Kanäle").font(.system(size:11))
                }.disabled(model.busy)
                Stepper(value:$model.probeChannel,in:0...max(0,model.show.count(for:device)-1)) { Text("Testkanal \(model.probeChannel+1)").font(.system(size:11)) }.disabled(model.busy)
                Button("Kanal 1,5 Sekunden markieren") { model.beginChannelProbe() }.buttonStyle(StudioButtonStyle()).disabled(model.busy)
                Text("Türkis auf dunklem Grund, danach Wiederherstellung. Ambilight-Zonen bleiben unverändert.").font(.system(size:9)).foregroundStyle(Palette.muted)
                Button("Show-Kanalzahl zurücksetzen") { model.show.channelCounts.removeValue(forKey:device.id);model.probeChannel=0;model.showChanged() }.buttonStyle(.plain).font(.system(size:10)).foregroundStyle(Palette.mint).disabled(model.busy)
            }
        }
    }
}
