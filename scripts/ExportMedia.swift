// Compile only with MEDIA_EXPORT. Renders the real SwiftUI views and local engine offline.
import SwiftUI
import AppKit
import AmbienceCore

@main
struct ExportMedia {
    @MainActor static func write<V: View>(_ view: V,to path: String,width: CGFloat,height: CGFloat) throws {
        let renderer=ImageRenderer(content:view.frame(width:width,height:height).environment(\.colorScheme,.dark))
        renderer.scale=1
        guard let image=renderer.cgImage,let data=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]) else { fatalError("Render failed") }
        try data.write(to:URL(fileURLWithPath:path))
    }
    @MainActor static func screenshot<V: View>(_ view: V,to path:String) throws {
        let host=NSHostingView(rootView:view.environment(\.colorScheme,.dark))
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1440,height:980),styleMask:[.borderless],backing:.buffered,defer:false)
        window.contentView=host
        host.frame=NSRect(x:0,y:0,width:1440,height:980)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until:Date().addingTimeInterval(0.25))
        host.layoutSubtreeIfNeeded()
        guard let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds) else { fatalError("Screenshot allocation failed") }
        host.cacheDisplay(in:host.bounds,to:bitmap)
        guard let data=bitmap.representation(using:.png,properties:[:]) else { fatalError("Screenshot encoding failed") }
        try data.write(to:URL(fileURLWithPath:path))
    }
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let model=StudioModel()
        model.devices=[DeviceConfig(id:"demo-panels",ip:"127.0.0.1",sku:"H606A"),DeviceConfig(id:"demo-strip",ip:"127.0.0.2",sku:"H61A0")]
        model.devices[0].name="Demo panels";model.devices[1].name="Demo strip"
        model.notice="Offline demo · synthetic data · no hardware output"
        model.runState = .preview
        model.show.intensity=1.5;model.show.speed=0.7
        for (name,mode) in [("scenes",ExperienceMode.scenes),("music",.music),("ambilight",.ambience)] {
            model.show.mode=mode;model.show.scene = .prism;model.show.musicPattern = .prism;model.show.musicColors = .neon
            var colors:[String:[RGB]]=[:]
            for (i,d) in model.devices.enumerated() { colors[d.id]=ShowRenderer.colors(count:d.zones.count,time:2,offset:Double(i)*0.17,settings:model.show,audio:AudioLevels(bass:0.6,mid:0.4,high:0.7,level:0.5)) }
            model.live.report=FrameReport(image:nil,colors:colors,fps:0,workMS:0,crop:SampleZone(x:0,y:0,width:1,height:1),audio:AudioLevels(bass:0.6,mid:0.4,high:0.7,level:0.5),audioReceiving:false)
            try screenshot(StudioView().environmentObject(model),to:"docs/media/\(name).png")
        }
        for mode in ["prism-drift","music-reactor"] {
            var settings=ShowSettings();settings.mode = mode == "prism-drift" ? .scenes:.music
            settings.scene = .prism;settings.musicPattern = .prism;settings.musicColors = .neon
            settings.intensity=1.8;settings.speed=0.9;settings.background=0.06
            for frame in 0..<72 {
                let t=Double(frame)/12
                let pulse=pow(max(0,sin(t*Double.pi*3)),4)
                let audio=AudioLevels(bass:pulse,mid:0.25+0.2*sin(t*4),high:pow(max(0,sin(t*13)),6),level:0.5,transient:pulse)
                let rows=(0..<3).map { ShowRenderer.colors(count:24,time:t,offset:Double($0)*0.17,settings:settings,audio:audio) }
                try write(EffectDemo(title:mode == "prism-drift" ? "Prism Drift":"Prism Drive",subtitle:mode == "prism-drift" ? "LOCAL SCENE ENGINE":"SYNTHETIC AUDIO REACTION",rows:rows,audio:settings.mode == .music ? audio:nil),to:String(format:".local/media-frames/%@-%03d.png",mode,frame),width:960,height:540)
            }
        }
    }
}
struct EffectDemo: View {
    let title:String
    let subtitle:String
    let rows:[[RGB]]
    let audio:AudioLevels?
    var body: some View {
        VStack(alignment:.leading,spacing:24) {
            HStack { Text("GOVEE STUDIO").tracking(3);Spacer();Text("Created by Naiklas") }.font(.system(size:12,weight:.medium,design:.monospaced)).foregroundStyle(Palette.mint)
            HStack(alignment:.bottom) { VStack(alignment:.leading,spacing:8) { Text(title).font(.system(size:44,weight:.semibold));Text(subtitle).font(.system(size:12,design:.monospaced)).foregroundStyle(Palette.muted) };Spacer() }
            VStack(spacing:18) {
                ForEach(0..<rows.count,id:\.self) { row in
                    HStack(spacing:5) { ForEach(0..<rows[row].count,id:\.self) { i in RoundedRectangle(cornerRadius:5).fill(Palette.rgb(rows[row][i])).frame(height:52) } }
                }
            }.padding(24).background(Palette.panel,in:RoundedRectangle(cornerRadius:18))
            if let audio {
                HStack(spacing:24) { meter("BASS",audio.bass);meter("MIDS",audio.mid);meter("HIGHS",audio.high) }
            }
            Spacer(minLength:0)
            Text("OFFLINE ENGINE DEMO · SYNTHETIC CHANNELS · NO HARDWARE FOOTAGE · NO AUDIO TRACK").font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.muted)
        }.padding(40).foregroundStyle(Palette.text).background(Palette.background)
    }
    func meter(_ name:String,_ value:Double) -> some View {
        VStack(alignment:.leading,spacing:5) { Text(name).font(.system(size:10,design:.monospaced));GeometryReader { g in RoundedRectangle(cornerRadius:3).fill(Palette.mint).frame(width:g.size.width*max(0,min(1,value))) }.frame(height:5) }.foregroundStyle(Palette.muted)
    }
}
