import Foundation

public enum ExperienceMode: String, Codable, CaseIterable, Sendable {
    case ambience = "Ambilight", scenes = "Szenen", music = "Musik"
    public var icon: String { switch self { case .ambience: return "display"; case .scenes: return "sparkles"; case .music: return "waveform" } }
}
public enum LightScene: String, Codable, CaseIterable, Sendable {
    case neon = "Neon-Schlat", aurora = "Aurora", void = "Black Hole", ember = "Glutwerk", focus = "Deep Work", reactor = "Bassreaktor", meteor = "Meteor Shower", implosion = "Bass-Implosion", prism = "Prism Drift", lattice = "Neon Lattice", chrome = "Liquid Chrome"
    public var subtitle: String {
        switch self {
        case .prism: return "Klare Farbgruppen wandern wie ein leuchtendes Prisma."
        case .lattice: return "Gegenläufige Lichtlinien und dunkle Zwischenräume."
        case .chrome: return "Schillernde Farbbänder. Flüssig, tief und langsam."
        case .meteor: return "Leuchtköpfe mit langen Schweifen durch die Kanalfolge."
        case .implosion: return "Bassimpulse ziehen von außen zur Mitte."
        case .neon: return "Cyan trifft Magenta. Feierabend im Cyberkeller."
        case .aurora: return "Fließende Polarlichter. Nervensystem auf Urlaub."
        case .void: return "Violette Umlaufbahnen um einen dunklen Kern."
        case .ember: return "Glühende Kohlen. Langsam, warm, verdammt gemütlich."
        case .focus: return "Warmes Grundlicht. Der Kopf darf arbeiten."
        case .reactor: return "Bass im Fundament. Höhen ziehen Leuchtspuren."
        }
    }
    public var palette: [RGB] {
        switch self {
        case .prism: return [RGB(0,230,255),RGB(255,15,135),RGB(110,15,255)]
        case .lattice: return [RGB(125,255,0),RGB(0,200,245),RGB(255,30,85)]
        case .chrome: return [RGB(35,40,255),RGB(0,255,185),RGB(245,25,145)]
        case .meteor: return [RGB(30,200,255),RGB(220,80,255),RGB(200,245,255)]
        case .implosion: return [RGB(255,70,35),RGB(200,30,230),RGB(255,200,50)]
        case .neon: return [RGB(14,225,235),RGB(225,23,190),RGB(95,55,255)]
        case .aurora: return [RGB(20,235,145),RGB(24,125,225),RGB(155,60,240)]
        case .void: return [RGB(95,35,210),RGB(210,30,170),RGB(25,100,245)]
        case .ember: return [RGB(255,65,8),RGB(255,157,35),RGB(190,24,5)]
        case .focus: return [RGB(255,182,105),RGB(255,210,156),RGB(255,165,92)]
        case .reactor: return [RGB(185,245,20),RGB(20,205,230),RGB(235,35,90)]
        }
    }
}
public enum MusicPattern: String, Codable, CaseIterable, Sendable {
    case spectrum="Spektrum", pulse="Bass-Puls", chase="Beat Chase", wave="Basswelle", prism="Prism Drive", split="Split Reactor", glitter="Glitterstorm", liquid="Liquid Chrome"
    public var detail: String {
        switch self {
        case .prism:return "Drei Farbgruppen springen auf Impulse; Bass, Mitten und Höhen bleiben getrennt."
        case .split:return "Bass wächst von der Mitte nach außen; Höhen antworten vom Rand."
        case .glitter:return "Höhen setzen kurze Lichtpunkte, darunter rollen dunkle Basswolken."
        case .liquid:return "Weiche Farbbänder verformen sich mit Mitten und Bass."
        case .spectrum:return "Bass, Mitten und Höhen verteilen sich auf die Kanäle."
        case .pulse:return "Das ganze Setup atmet mit dem Bass."
        case .chase:return "Laufende Lichtköpfe reagieren auf die Musikenergie."
        case .wave:return "Bassanstiege starten eine wandernde Welle."
        }
    }
    public var icon: String {
        switch self { case .prism:return "hexagon.lefthalf.filled"; case .split:return "arrow.left.and.right"; case .glitter:return "sparkles"; case .liquid:return "water.waves"; case .spectrum:return "chart.bar.fill"; case .pulse:return "waveform.path"; case .chase:return "bolt.fill"; case .wave:return "dot.radiowaves.left.and.right" }
    }
}
public enum MusicColors: String, Codable, CaseIterable, Sendable {
    case neon="Neon", acid="Acid", fire="Feuer", ice="Eis", candy="Laser Candy", tokyo="Tokyo Drift", solar="Solar Flare", ultraviolet="Ultraviolet", emerald="Emerald", arcade="Sunset Arcade"
    public var palette: [RGB] {
        switch self {
        case .candy:return [RGB(255,5,115),RGB(0,235,255),RGB(145,20,255)]
        case .tokyo:return [RGB(255,20,55),RGB(55,15,255),RGB(0,245,195)]
        case .solar:return [RGB(255,25,5),RGB(255,195,0),RGB(255,0,100)]
        case .ultraviolet:return [RGB(60,0,255),RGB(200,0,255),RGB(0,150,255)]
        case .emerald:return [RGB(0,255,100),RGB(0,125,245),RGB(155,255,0)]
        case .arcade:return [RGB(255,100,0),RGB(245,0,105),RGB(75,0,255)]
        case .neon:return [RGB(20,225,255),RGB(240,30,190),RGB(100,45,255)]
        case .acid:return [RGB(190,255,15),RGB(10,200,170),RGB(245,70,30)]
        case .fire:return [RGB(255,55,5),RGB(255,175,20),RGB(240,25,90)]
        case .ice:return [RGB(20,95,255),RGB(50,230,255),RGB(175,210,255)]
        }
    }
}
public enum MusicColorFlow: String, Codable, CaseIterable, Sendable {
    case bands="Bandfarben", drift="Farbfluss", beat="Impulswechsel"
}
public struct MusicBeat: Sendable {
    public var index: Int
    public var age: Double
    public var strength: Double
    public init(index: Int=0,age: Double=100,strength: Double=0) { self.index=index; self.age=age; self.strength=strength }
}
/// Onsets, not a guessed BPM clock. Steady tones cannot retrigger indefinitely.
public struct MusicBeatTracker {
    private var average=0.0, previous=0.0
    private var lastTime: Double?
    private var onset: Double?
    private var index=0, strength=0.0
    public init() {}
    public mutating func update(audio: AudioLevels,time: Double,sensitivity: Double) -> MusicBeat {
        let raw=max(audio.bass,audio.transient*2)
        let value=raw.isFinite ? max(0,raw)*max(0.2,min(5,sensitivity)):0
        let dt=max(0,min(0.3,time-(lastTime ?? time-0.04)))
        if value > max(0.02,average*1.45),value > previous*1.15,time-(onset ?? -100) >= 0.18 {
            onset=time; index=(index+1)%1000000; strength=min(1,value*5)
        }
        average += (1-exp(-dt/0.3))*(value-average); previous=value; lastTime=time
        return MusicBeat(index:index,age:onset.map { max(0,time-$0) } ?? 100,strength:strength)
    }
}
public struct MusicAmbilight: Codable, Equatable, Sendable {
    public var enabled=false
    public var gain=0.35
    public var saturation=1.15
    public var smoothing=0.3
    public var cropBars=true
    public init() {}
}
public struct ShowSettings: Codable, Equatable, Sendable {
    public var mode: ExperienceMode = .scenes
    public var audioPattern: MusicPattern?
    public var audioColors: MusicColors?
    public var colorFlow: MusicColorFlow?
    public var musicColorFlow: MusicColorFlow { get { colorFlow ?? .bands } set { colorFlow=newValue } }
    public var musicPattern: MusicPattern { get { audioPattern ?? .spectrum } set { audioPattern=newValue } }
    public var musicColors: MusicColors { get { audioColors ?? .neon } set { audioColors=newValue } }
    public var scene: LightScene = .neon
    public var background = 0.12
    public var intensity = 0.7
    public var speed = 0.45
    public var sensitivity = 1.5
    public var decay = 0.22
    public var backgroundHue = 0.68
    public var musicColorSaturation: Double?
    public var musicSaturation: Double {
        get { musicColorSaturation ?? 1 }
        set { musicColorSaturation=newValue }
    }
    public var trailLength: Double?
    public var backwards: Bool?
    public var trail: Double { get { trailLength ?? 0.25 } set { trailLength=newValue } }
    public var reverseMotion: Bool { get { backwards ?? false } set { backwards=newValue } }
    public var ambilight: MusicAmbilight?
    public var musicBackground: MusicAmbilight {
        get { ambilight ?? MusicAmbilight() }
        set { ambilight=newValue }
    }
    /// Separate from screen sampling zones; opt-in experiments never rewrite Ambilight geometry.
    public var channelCounts: [String:Int] = [:]
    public init() {}
    public mutating func validate() {
        func safe(_ value: Double,_ fallback: Double,_ low: Double,_ high: Double) -> Double { max(low,min(high,value.isFinite ? value:fallback)) }
        background=safe(background,0.12,0,1); intensity=safe(intensity,0.7,0,4)
        speed=safe(speed,0.45,0.05,2); sensitivity=safe(sensitivity,1.5,0.2,5)
        decay=safe(decay,0.22,0.04,1.5); backgroundHue=safe(backgroundHue,0.68,0,1)
        if let trailLength { self.trailLength=safe(trailLength,0.25,0.05,0.8) }
        if let saturation=musicColorSaturation { musicColorSaturation=safe(saturation,1,0,2) }
        if var ambient=ambilight {
            ambient.gain=safe(ambient.gain,0.35,0,1)
            ambient.saturation=safe(ambient.saturation,1.15,0,2)
            ambient.smoothing=safe(ambient.smoothing,0.3,0,1.5)
            ambilight=ambient
        }
        channelCounts=channelCounts.mapValues { max(1,min(84,$0)) }
    }
    public func count(for device: DeviceConfig) -> Int {
        device.mode == .whole ? 1:max(1,min(84,channelCounts[device.id] ?? device.zones.count))
    }
}
public struct AudioLevels: Equatable, Sendable {
    public var bass=0.0, mid=0.0, high=0.0, level=0.0, transient=0.0
    public init(bass: Double=0,mid: Double=0,high: Double=0,level: Double=0,transient: Double=0) {
        self.bass=bass; self.mid=mid; self.high=high; self.level=level; self.transient=transient
    }
    public static let silent=AudioLevels()
}
/// Two low-pass crossovers; constant memory, no FFT allocation on the audio callback.
public struct AudioAnalyzer {
    private var low=0.0, upper=0.0, envelope=0.0
    public init() {}
    public mutating func process(_ samples: [Float],sampleRate: Double) -> AudioLevels {
        guard !samples.isEmpty,sampleRate > 0 else { return .silent }
        let a=1-exp(-2 * Double.pi*180/sampleRate), b=1-exp(-2 * Double.pi*2200/sampleRate)
        var bass=0.0,mid=0.0,high=0.0,total=0.0
        for sample in samples {
            let x=sample.isFinite ? Double(sample):0
            low += a*(x-low); upper += b*(x-upper)
            bass += low*low; mid += pow(upper-low,2); high += pow(x-upper,2); total += x*x
        }
        let n=Double(samples.count), rms=sqrt(total/n)
        let transient=max(0,rms-envelope*1.3)
        let blend=1-exp(-n/sampleRate/0.18)
        envelope += blend*(rms-envelope)
        return AudioLevels(bass:sqrt(bass/n),mid:sqrt(mid/n),high:sqrt(high/n),level:rms,transient:transient)
    }
}
public struct BassWaveTracker {
    private var average=0.0
    private var lastTime=0.0
    private var trigger: Double?
    private var strength=0.0
    public init() {}
    public mutating func update(bass: Double,time: Double) -> (age: Double,strength: Double)? {
        let value=bass.isFinite ? max(0,bass):0
        let dt=lastTime > 0 ? max(0,min(1,time-lastTime)):0.04
        if value > max(0.015,average*1.6), time-(trigger ?? -100) > 0.3 {
            trigger=time; strength=min(1,value*8)
        }
        average += (1-exp(-dt/0.25))*(value-average); lastTime=time
        guard let trigger else { return nil }
        return (max(0,time-trigger),strength)
    }
}
public enum ShowRenderer {
    /// Screen and music have independent envelopes. Screen blending preserves
    /// remaining channel headroom instead of washing bright backgrounds white.
    public static func composite(background: RGB,effect: RGB) -> RGB {
        func blend(_ b: Double,_ e: Double) -> Double {
            let base=max(0,min(255,b)), top=max(0,min(255,e))
            return base+top*(1-base/255)
        }
        return RGB(blend(background.r,effect.r),blend(background.g,effect.g),blend(background.b,effect.b))
    }

    public static func hue(_ h: Double) -> RGB {
        let v=(h-floor(h))*6, f=v-floor(v)
        switch Int(v) {
        case 0:return RGB(255,255*f,0)
        case 1:return RGB(255*(1-f),255,0)
        case 2:return RGB(0,255,255*f)
        case 3:return RGB(0,255*(1-f),255)
        case 4:return RGB(255*f,0,255)
        default:return RGB(255,0,255*(1-f))
        }
    }
    public static func paletteColor(_ palette: [RGB],position: Double) -> RGB {
        guard !palette.isEmpty else { return .black }
        let p=(position.isFinite ? position:0)
        let scaled=(p-floor(p))*Double(palette.count)
        let index=Int(floor(scaled)), blend=scaled-floor(scaled)
        func hsv(_ color: RGB) -> (Double,Double,Double) {
            let r=color.r/255,g=color.g/255,b=color.b/255
            let high=max(r,g,b),low=min(r,g,b),delta=high-low
            var h=0.0
            if delta > 0 {
                if high == r { h=(g-b)/delta }
                else if high == g { h=2+(b-r)/delta }
                else { h=4+(r-g)/delta }
                h /= 6; h -= floor(h)
            }
            return (h,high == 0 ? 0:delta/high,high)
        }
        let a=hsv(palette[index]),b=hsv(palette[(index+1)%palette.count])
        var delta=b.0-a.0
        if delta > 0.5 { delta -= 1 }; if delta < -0.5 { delta += 1 }
        let hueColor=hue(a.0+delta*blend)
        let sat=a.1+(b.1-a.1)*blend, value=a.2+(b.2-a.2)*blend
        return RGB((255*(1-sat)+hueColor.r*sat)*value,(255*(1-sat)+hueColor.g*sat)*value,(255*(1-sat)+hueColor.b*sat)*value)
    }
    public static func colors(count: Int,time: Double,offset: Double,settings: ShowSettings,audio: AudioLevels = .silent,waveAge: Double? = nil,waveStrength: Double = 0,beat: MusicBeat = MusicBeat()) -> [RGB] {
        var settings=settings; settings.validate()
        let n=max(1,min(84,count)), t=(time.isFinite ? time:0)*settings.speed
        let palette=settings.mode == .music ? settings.musicColors.palette:settings.scene.palette
        let base=hue(settings.backgroundHue).adjusted(gain:settings.background,saturation:0.65,blackThreshold:0)
        let music=settings.mode == .music
        let sensitivity=settings.sensitivity
        func power(_ x: Double) -> Double { let x=x.isFinite ? x:0; return min(1,max(0,x-0.001)*sensitivity*4) }
        let bass=power(audio.bass),mid=power(audio.mid),high=power(audio.high),pulse=power(audio.transient)*0.5
        return (0..<n).map { i in
            let x=Double(i)/Double(max(1,n-1)), phase=x+offset
            var amount=1.0, mix=0.0
            switch settings.scene {
            case .prism:
                let step=Int(floor(t*0.7))
                mix=Double((i+step)%3)/2
                amount=0.35+0.65*pow(0.5+0.5*cos(t*1.1+Double(i%3)*2.094),2)
            case .lattice:
                let left=pow(0.5+0.5*sin(x*18-t*1.7),10)
                let right=pow(0.5+0.5*sin(x*18+t*1.3+2),10)
                amount=max(left,right); mix=left > right ? 0:1
            case .chrome:
                mix=0.5+0.5*sin(x*5-t*0.3+sin(x*8+t*0.4))
                amount=0.25+0.75*pow(0.5+0.5*sin(x*7-t*0.6),2)
            case .meteor:
                let position=settings.reverseMotion ? 1-x:x
                let head=(t*0.45+offset).truncatingRemainder(dividingBy:1.5)
                let distance=head-position
                amount=distance >= 0 ? exp(-distance/settings.trail):exp(-pow(distance/0.035,2))
                mix=0.5+0.5*sin(t*0.4+position*3)
            case .implosion:
                let age=music ? (waveAge ?? 100):((t/settings.speed).truncatingRemainder(dividingBy:3/settings.speed))
                let progress=age*settings.speed*0.8
                let radius=settings.reverseMotion ? progress:1-progress
                let distance=abs(abs(x-0.5)*2-radius)
                amount=progress <= 1.4 ? exp(-distance/max(0.025,settings.trail*0.35))*max(0,1-progress*0.6):0
                if music { amount *= waveStrength }
                mix=min(1,progress)
            case .neon: mix=0.5+0.5*sin(phase*7-t*0.8); amount=0.5+0.5*pow(0.5+0.5*sin(phase*12+t),2)
            case .aurora: mix=0.5+0.5*sin(phase*4+t*0.3); amount=0.3+0.7*(0.5+0.5*sin(phase*6-t*0.4))
            case .void: mix=0.5+0.5*sin(phase*5+t*0.4); amount=pow(0.5+0.5*cos(phase*8-t),6)
            case .ember: mix=0.5+0.5*sin(phase*13+t*0.4); amount=0.45+0.3*sin(phase*9+t*0.9)+0.15*sin(phase*21-t*1.3)
            case .focus: mix=0.35; amount=0.55
            case .reactor: mix=0.5+0.5*sin(phase*9-t); amount=0.25+0.75*pow(0.5+0.5*sin(phase*15-t*1.5),3)
            }
            if music {
                let position=settings.reverseMotion ? 1-x:x
                switch settings.musicPattern {
                case .prism:
                    let group=(i+beat.index)%3
                    amount=[bass,mid,high][group]*(0.65+0.35*exp(-beat.age*5))
                    mix=Double(group)/2
                case .split:
                    let radius=abs(position-0.5)*2
                    let low=max(0,min(1,(bass-radius)*Double(n)/2))
                    let top=max(0,min(1,(high-(1-radius))*Double(n)/2))
                    amount=max(low,top)*max(bass,high)
                    mix=low >= top ? 0:1
                case .glitter:
                    let tick=floor(t*9)
                    let hash=sin(Double(i)*127.1+tick*311.7+offset*19)*43758.5453
                    let random=hash-floor(hash)
                    let sparkle=random > 0.82 ? high*pow((random-0.82)/0.18,0.5):0
                    let cloud=bass*0.22*pow(0.5+0.5*sin(position*8-t),2)
                    amount=max(sparkle,cloud); mix=sparkle > cloud ? 1:0
                case .liquid:
                    let ribbon=0.5+0.5*sin(position*8-t*0.7+mid*3*sin(position*4+t*0.4))
                    amount=(bass*0.35+mid*0.5+high*0.15)*pow(ribbon,2)
                    mix=0.5+0.5*sin(position*4+t*0.25+bass*2)
                case .spectrum:
                    amount=x < 0.34 ? bass:(x < 0.67 ? mid:high)
                    mix=x
                case .pulse:
                    amount=min(1,bass+pulse)
                    mix=0.5+0.5*sin(t*0.2)
                case .chase:
                    let head=(t*0.45+offset).truncatingRemainder(dividingBy:1.5)
                    let distance=head-position
                    let envelope=distance >= 0 ? exp(-distance/settings.trail):exp(-pow(distance/0.035,2))
                    amount=envelope*min(1,bass*0.6+mid*0.4+high*0.3+pulse)
                    mix=position
                case .wave:
                    let progress=(waveAge ?? 100)*settings.speed*0.8
                    let radius=settings.reverseMotion ? progress:1-progress
                    let distance=abs(abs(x-0.5)*2-radius)
                    amount=progress <= 1.4 ? exp(-distance/max(0.025,settings.trail*0.35))*max(0,1-progress*0.6)*waveStrength:0
                    mix=min(1,progress)
                }
            }
            var effect=palette[0].mixed(with:palette[1],amount:mix).mixed(with:palette[2],amount:0.2*(0.5+0.5*sin(t*0.3+phase)))
            if music {
                var colorPosition=mix*0.6666667
                switch settings.musicColorFlow {
                case .bands: break
                case .drift: colorPosition += t*0.055
                case .beat: colorPosition += Double(beat.index%3)/3
                }
                // Saturated interpolation takes the short hue path instead of muddy RGB midpoints.
                effect=paletteColor(palette,position:colorPosition)
            } else if settings.scene == .prism {
                effect=palette[(i+Int(floor(t*0.7)))%3]
            } else if settings.scene == .chrome {
                effect=paletteColor(palette,position:mix*0.6666667)
            }
            let strength=max(0,min(1,amount*settings.intensity))
            return RGB(min(255,base.r+effect.r*strength*(1-settings.background)),min(255,base.g+effect.g*strength*(1-settings.background)),min(255,base.b+effect.b*strength*(1-settings.background)))
        }
    }
}
