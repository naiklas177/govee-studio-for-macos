import Foundation

public enum ColorSampler {
    /// A fixed 8x8 grid per zone bounds work independently of display resolution.
    /// Source bytes are BGRA, rows run top to bottom (ScreenCaptureKit).
    public static func average(bytes: UnsafePointer<UInt8>, width: Int, height: Int, stride: Int, zone: SampleZone, crop: SampleZone = SampleZone(x:0,y:0,width:1,height:1)) -> RGB {
        guard width > 0, height > 0, stride >= width*4 else { return .black }
        var red=0, green=0, blue=0
        for row in 0..<8 {
            let v=crop.y+(zone.y+zone.height*(Double(row)+0.5)/8)*crop.height
            let y=max(0,min(height-1,Int(v*Double(height))))
            for col in 0..<8 {
                let u=crop.x+(zone.x+zone.width*(Double(col)+0.5)/8)*crop.width
                let x=max(0,min(width-1,Int(u*Double(width))))
                let p=y*stride+x*4
                blue += Int(bytes[p]); green += Int(bytes[p+1]); red += Int(bytes[p+2])
            }
        }
        return RGB(Double(red)/64,Double(green)/64,Double(blue)/64)
    }
    /// Conservative symmetric letterbox detection. Only removes pairs of dark rows;
    /// never crops beyond 20% and leaves a fully black frame unchanged.
    public static func activePicture(bytes: UnsafePointer<UInt8>, width: Int, height: Int, stride: Int) -> SampleZone {
        guard width > 0, height > 0 else { return SampleZone(x:0,y:0,width:1,height:1) }
        func dark(_ y: Int) -> Bool {
            for i in 0..<24 {
                let x=min(width-1,Int((Double(i)+0.5)*Double(width)/24))
                let p=y*stride+x*4
                if max(bytes[p],bytes[p+1],bytes[p+2]) > 5 { return false }
            }
            return true
        }
        var count=0
        let limit=height/5
        while count < limit && dark(count) && dark(height-count-1) { count += 1 }
        guard count > 1, count < limit else { return SampleZone(x:0,y:0,width:1,height:1) }
        return SampleZone(x:0,y:Double(count)/Double(height),width:1,height:Double(height-2*count)/Double(height))
    }
    public static func smoothingAlpha(delta: Double, timeConstant: Double) -> Double {
        timeConstant <= 0 ? 1 : 1-exp(-max(0,delta)/timeConstant)
    }
}
