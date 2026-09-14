import SwiftUI
import AmbienceCore

enum Palette {
    static let background=Color(red:0.035,green:0.045,blue:0.07)
    static let panel=Color(red:0.058,green:0.073,blue:0.105)
    static let raised=Color(red:0.088,green:0.105,blue:0.145)
    static let line=Color.white.opacity(0.08)
    static let muted=Color(red:0.49,green:0.55,blue:0.66)
    static let text=Color(red:0.90,green:0.93,blue:0.98)
    static let mint=Color(red:0.38,green:0.96,blue:0.79)
    static let purple=Color(red:0.66,green:0.49,blue:1)
    static func device(_ index: Int) -> Color { [purple,Color(red:0.96,green:0.55,blue:0.69),mint,Color(red:0.39,green:0.72,blue:1)][abs(index)%4] }
    static func rgb(_ rgb: RGB) -> Color { let b=rgb.bytes; return Color(red:Double(b[0])/255,green:Double(b[1])/255,blue:Double(b[2])/255) }
}
struct ThinDivider: View { var body: some View { Rectangle().fill(Palette.line).frame(height:1) } }
struct Eyebrow: View {
    let text: String
    var body: some View { Text(verbatim:tr(text).uppercased()).font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(1.7).foregroundStyle(Palette.muted) }
}
struct StudioButtonStyle: ButtonStyle {
    var prominent=false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size:12,weight:.semibold))
            .padding(.horizontal,14).padding(.vertical,10)
            .foregroundStyle(prominent ? Palette.background : Palette.text)
            .background(prominent ? Palette.mint.opacity(configuration.isPressed ? 0.7:1) : Palette.raised.opacity(configuration.isPressed ? 0.5:1),in:RoundedRectangle(cornerRadius:9))
            .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(prominent ? Color.clear:Palette.line))
    }
}
struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            for i in 0..<6 {
                let angle=Double(i)*Double.pi/3-Double.pi/2
                let point=CGPoint(x:rect.midX+cos(angle)*rect.width/2,y:rect.midY+sin(angle)*rect.height/2)
                if i == 0 { p.move(to:point) } else { p.addLine(to:point) }
            }
            p.closeSubpath()
        }
    }
}
