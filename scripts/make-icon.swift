import AppKit
let size=1024
let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
let ctx=NSGraphicsContext(bitmapImageRep:rep)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=ctx
let rect=NSRect(x:65,y:65,width:894,height:894)
let bg=NSBezierPath(roundedRect:rect,xRadius:200,yRadius:200)
NSGradient(starting:NSColor(srgbRed:0.09,green:0.12,blue:0.19,alpha:1),ending:NSColor(srgbRed:0.025,green:0.04,blue:0.07,alpha:1))!.draw(in:bg,angle:-70)
let hex=NSBezierPath()
for i in 0..<6 {
 let a=Double(i)*Double.pi/3+Double.pi/2
 let point=NSPoint(x:512+cos(a)*290,y:512+sin(a)*290)
 if i == 0 { hex.move(to:point) } else { hex.line(to:point) }
}
hex.close(); hex.lineWidth=22; hex.lineJoinStyle = .round
NSColor(srgbRed:0.46,green:0.94,blue:0.82,alpha:0.20).setStroke(); hex.stroke()
let wave=NSBezierPath(); wave.move(to:NSPoint(x:267,y:480))
wave.curve(to:NSPoint(x:409,y:500),controlPoint1:NSPoint(x:340,y:480),controlPoint2:NSPoint(x:357,y:680))
wave.curve(to:NSPoint(x:558,y:495),controlPoint1:NSPoint(x:460,y:310),controlPoint2:NSPoint(x:506,y:680))
wave.curve(to:NSPoint(x:754,y:540),controlPoint1:NSPoint(x:622,y:300),controlPoint2:NSPoint(x:671,y:540))
wave.lineWidth=43; wave.lineCapStyle = .round
NSColor(srgbRed:0.38,green:0.96,blue:0.79,alpha:1).setStroke(); wave.stroke()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:".build/icon.png"))
