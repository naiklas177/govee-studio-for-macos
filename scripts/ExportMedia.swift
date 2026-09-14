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
        for clip in ["prism-drift","music-reactor"] {
            let host=NSHostingView(rootView:StudioView().environmentObject(model).environment(\.colorScheme,.dark))
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1440,height:980),styleMask:[.borderless],backing:.buffered,defer:false)
            window.contentView=host;host.frame=NSRect(x:0,y:0,width:1440,height:980)
            model.show.mode = clip == "prism-drift" ? .scenes:.music
            for frame in 0..<288 {
                let t=Double(frame)/24
                let section=min(3,Int(t/3))
                model.show.scene=[LightScene.neon,.meteor,.prism,.chrome][section]
                model.show.musicPattern=[MusicPattern.spectrum,.pulse,.prism,.glitter][section]
                model.show.musicColors=[MusicColors.neon,.fire,.neon,.ice][section]
                model.show.intensity=0.9+0.7*(0.5+0.5*sin(t*0.7))
                model.show.speed=0.7
                let audio=AudioLevels(bass:pow(max(0,sin(t*Double.pi*3)),4),mid:0.35+0.25*sin(t*4),high:pow(max(0,sin(t*11)),4),level:0.5)
                var colors:[String:[RGB]]=[:]
                for (i,d) in model.devices.enumerated() { colors[d.id]=ShowRenderer.colors(count:d.zones.count,time:t,offset:Double(i)*0.17,settings:model.show,audio:audio) }
                model.live.report=FrameReport(image:nil,colors:colors,fps:0,workMS:0,crop:SampleZone(x:0,y:0,width:1,height:1),audio:audio,audioReceiving:false)
                model.notice=clip == "prism-drift" ? "SCRIPTED APP DEMO · local scenes · synthetic channels · no hardware output":"SCRIPTED APP DEMO · synthetic audio levels · no recording or hardware output"
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until:Date().addingTimeInterval(0.02))
                host.layoutSubtreeIfNeeded()
                guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1440,pixelsHigh:980,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0) else { fatalError("Frame allocation failed") }
                bitmap.size=host.bounds.size
                host.cacheDisplay(in:host.bounds,to:bitmap)
                guard let data=bitmap.representation(using:.png,properties:[:]) else { fatalError("Frame encoding failed") }
                try data.write(to:URL(fileURLWithPath:String(format:".local/media-frames/%@-%03d.png",clip,frame)))
            }
        }
    }
}
