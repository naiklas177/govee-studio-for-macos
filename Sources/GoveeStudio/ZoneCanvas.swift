import AppKit
import SwiftUI
import AmbienceCore

/// One native event surface rather than a SwiftUI gesture on every moving rectangle.
/// During a drag, AppKit owns transient geometry and SwiftUI never invalidates the
/// whole workspace for a pointer sample. Only the final position is published/saved.
struct ZoneCanvas: NSViewRepresentable {
    let deviceID: String
    let zones: [SampleZone]
    let selectedIndex: Int
    let crop: SampleZone
    let tint: Color
    let onSelect: (Int)->Void
    let onPreview: (SampleZone,Int)->Void
    let onCommit: (SampleZone,Int)->Void
    var onCommitMany: (([Int:SampleZone])->Void)? = nil

    func makeNSView(context: Context) -> ZoneCanvasView { ZoneCanvasView() }
    func updateNSView(_ view: ZoneCanvasView, context: Context) {
        view.configure(deviceID:deviceID,zones:zones,selectedIndex:selectedIndex,
                       crop:crop,tint:NSColor(tint),onSelect:onSelect,onPreview:onPreview,onCommit:onCommit,onCommitMany:onCommitMany)
    }
    static func dismantleNSView(_ view: ZoneCanvasView, coordinator: ()) { view.cancelDrag() }
}

final class ZoneCanvasView: NSView {
    private var deviceID=""
    private var zones: [SampleZone]=[]
    private var selectedIndex=0
    private(set) var selection: Set<Int> = []
    private var origins: [Int:SampleZone] = [:]
    private var onCommitMany: (([Int:SampleZone])->Void)?
    private var crop=SampleZone(x:0,y:0,width:1,height:1)
    private var tint=NSColor.systemMint
    private var drag: ZoneDragSession?
    private var dragIndex: Int?
    private var dragCropRect: NSRect?
    private var lastPreview=0.0
    private var onSelect: (Int)->Void = { _ in }
    private var onPreview: (SampleZone,Int)->Void = { _,_ in }
    private var onCommit: (SampleZone,Int)->Void = { _,_ in }
    private var elements: [ZoneAccessibilityElement]=[]

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        wantsLayer=true
        setAccessibilityRole(.group)
        setAccessibilityLabel(tr("Bildschirmzonen"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(deviceID: String,zones incoming: [SampleZone],selectedIndex: Int,crop: SampleZone,tint: NSColor,
                   onSelect: @escaping (Int)->Void,onPreview: @escaping (SampleZone,Int)->Void,onCommit: @escaping (SampleZone,Int)->Void,onCommitMany: (([Int:SampleZone])->Void)? = nil) {
        if deviceID != self.deviceID || incoming.count != zones.count { cancelDrag(); selection=[selectedIndex] }
        else if drag == nil && selectedIndex != self.selectedIndex { selection=[selectedIndex] }
        self.onCommitMany=onCommitMany
        self.onSelect=onSelect; self.onPreview=onPreview; self.onCommit=onCommit
        var next=incoming
        // 5 Hz live-image updates and other UI refreshes must not snap the active
        // zone back to its last persisted position or steal the mouse selection.
        for i in origins.keys where next.indices.contains(i) { next[i]=zones[i] }
        let nextSelection=dragIndex ?? selectedIndex
        let changed=self.deviceID != deviceID || zones != next || self.selectedIndex != nextSelection || self.crop != crop || self.tint != tint
        self.deviceID=deviceID; self.zones=next; self.selectedIndex=nextSelection; self.crop=crop; self.tint=tint
        guard changed else { return }
        needsDisplay=true
        if drag == nil { rebuildAccessibility(); window?.invalidateCursorRects(for:self) }
    }
    private var pictureRect: NSRect {
        if let frozen=dragCropRect { return frozen }
        return NSRect(x:bounds.width*crop.x,y:bounds.height*crop.y,width:bounds.width*crop.width,height:bounds.height*crop.height)
    }
    private func rect(for zone: SampleZone) -> NSRect {
        let area=pictureRect
        return NSRect(x:area.minX+zone.x*area.width,y:area.minY+zone.y*area.height,width:zone.width*area.width,height:zone.height*area.height)
    }
    private func handle(for rect: NSRect) -> NSRect { NSRect(x:rect.maxX-11,y:rect.maxY-11,width:9,height:9) }

    override func draw(_ dirtyRect: NSRect) {
        for i in zones.indices where i != selectedIndex { drawZone(i,dirtyRect:dirtyRect) }
        if zones.indices.contains(selectedIndex) { drawZone(selectedIndex,dirtyRect:dirtyRect) }
    }
    private func drawZone(_ i: Int,dirtyRect: NSRect) {
        let box=rect(for:zones[i])
        guard box.insetBy(dx:-18,dy:-18).intersects(dirtyRect) else { return }
        let selected=selection.contains(i)
        let path=NSBezierPath(roundedRect:box.insetBy(dx:0.8,dy:0.8),xRadius:4,yRadius:4)
        tint.withAlphaComponent(selected ? 0.18:0.05).setFill(); path.fill()
        tint.withAlphaComponent(selected ? 0.95:0.42).setStroke()
        path.lineWidth=selected ? 1.6:0.7; path.stroke()
        let text="\(i+1)" as NSString
        let attrs: [NSAttributedString.Key:Any] = [
            .font:NSFont.monospacedDigitSystemFont(ofSize:9,weight:.semibold),
            .foregroundColor:selected ? NSColor(srgbRed:0.035,green:0.045,blue:0.07,alpha:1):tint
        ]
        let label=NSRect(x:box.minX+3,y:box.minY+3,width:text.size(withAttributes:attrs).width+6,height:15)
        (selected ? tint:NSColor.black.withAlphaComponent(0.75)).setFill()
        NSBezierPath(roundedRect:label,xRadius:3,yRadius:3).fill()
        text.draw(at:NSPoint(x:label.minX+3,y:label.minY+1),withAttributes:attrs)
        if selected && selection.count == 1 {
            tint.setFill()
            NSBezierPath(roundedRect:handle(for:box),xRadius:2,yRadius:2).fill()
        }
    }
    override func layout() {
        super.layout()
        needsDisplay=true
        if drag == nil { rebuildAccessibility() }
    }
    override func resetCursorRects() {
        for zone in zones {
            addCursorRect(rect(for:zone).insetBy(dx:-4,dy:-4).intersection(bounds),cursor:.openHand)
        }
        if selection.count == 1 && zones.indices.contains(selectedIndex) {
            addCursorRect(handle(for:rect(for:zones[selectedIndex])).insetBy(dx:-4,dy:-4).intersection(bounds),cursor:.crosshair)
        }
    }
    private func hitZone(_ point: NSPoint) -> Int? {
        // Exact interiors win over padded hit areas, keeping adjacent narrow strips selectable.
        if zones.indices.contains(selectedIndex), rect(for:zones[selectedIndex]).contains(point) { return selectedIndex }
        if let hit=zones.indices.reversed().first(where:{rect(for:zones[$0]).contains(point)}) { return hit }
        return zones.indices.min(by:{ distance(point,to:rect(for:zones[$0])) < distance(point,to:rect(for:zones[$1])) })
            .flatMap { distance(point,to:rect(for:zones[$0])) <= 6 ? $0:nil }
    }
    private func distance(_ point: NSPoint,to rect: NSRect) -> Double {
        hypot(max(rect.minX-point.x,0,point.x-rect.maxX),max(rect.minY-point.y,0,point.y-rect.maxY))
    }
    override func mouseDown(with event: NSEvent) {
        let point=convert(event.locationInWindow,from:nil)
        guard let index=hitZone(point) else { selection=[]; needsDisplay=true; return }
        window?.makeFirstResponder(self)
        if event.modifierFlags.contains(.control) || event.modifierFlags.contains(.command) {
            if selection.contains(index) { selection.remove(index) }
            else { selection.insert(index) }
            selectedIndex=index; onSelect(index)
            rebuildAccessibility(); needsDisplay=true; window?.invalidateCursorRects(for:self)
            return
        }
        if !selection.contains(index) { selection=[index] }
        let resize=selection.count == 1 && index == selectedIndex && handle(for:rect(for:zones[index])).insetBy(dx:-4,dy:-4).contains(point)
        let area=pictureRect
        dragCropRect=area; dragIndex=index; selectedIndex=index
        origins=Dictionary(uniqueKeysWithValues:selection.map { ($0,zones[$0]) })
        let minX=origins.values.map(\.x).min()!, minY=origins.values.map(\.y).min()!
        let maxX=origins.values.map { $0.x+$0.width }.max()!, maxY=origins.values.map { $0.y+$0.height }.max()!
        let anchor=origins.count == 1 ? zones[index]:SampleZone(x:minX,y:minY,width:maxX-minX,height:maxY-minY)
        drag=ZoneDragSession(zone:anchor,pointerX:point.x,pointerY:point.y,
                             canvasWidth:area.width,canvasHeight:area.height,operation:resize ? .resize:.move)
        lastPreview=0
        onSelect(index)
        needsDisplay=true
        (resize ? NSCursor.crosshair:NSCursor.closedHand).set()
    }
    override func mouseDragged(with event: NSEvent) {
        updateDrag(at:convert(event.locationInWindow,from:nil))
    }
    private func updateDrag(at point: NSPoint) {
        guard let drag, let i=dragIndex, zones.indices.contains(i) else { return }
        let next=drag.zone(pointerX:point.x,pointerY:point.y)
        let now=ProcessInfo.processInfo.systemUptime
        let preview=now-lastPreview >= 1.0/30
        for (index,origin) in origins {
            var updated=origin
            if origins.count == 1 { updated=next }
            else { updated.x += next.x-drag.origin.x; updated.y += next.y-drag.origin.y }
            let oldRect=rect(for:zones[index]); zones[index]=updated
            setNeedsDisplay(oldRect.union(rect(for:updated)).insetBy(dx:-18,dy:-18))
            if preview { onPreview(updated,index) }
        }
        if preview { lastPreview=now }
    }
    private func commit(_ changes: [Int:SampleZone]) {
        guard !changes.isEmpty else { return }
        if let onCommitMany { onCommitMany(changes) }
        else { for (i,z) in changes { onCommit(z,i) } }
    }
    override func mouseUp(with event: NSEvent) {
        guard drag != nil else { return }
        updateDrag(at:convert(event.locationInWindow,from:nil))
        var changes: [Int:SampleZone]=[:]
        for (i,origin) in origins {
            onPreview(zones[i],i)
            if zones[i] != origin { changes[i]=zones[i] }
        }
        drag=nil; dragIndex=nil; dragCropRect=nil; origins=[:]
        commit(changes)
        rebuildAccessibility(); window?.invalidateCursorRects(for:self); needsDisplay=true
        NSCursor.openHand.set()
    }
    func cancelDrag() {
        for (i,origin) in origins where zones.indices.contains(i) { zones[i]=origin; onPreview(origin,i) }
        drag=nil; dragIndex=nil; dragCropRect=nil; origins=[:]
        needsDisplay=true; window?.invalidateCursorRects(for:self)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancelDrag(); return }
        guard zones.indices.contains(selectedIndex), [123,124,125,126].contains(event.keyCode) else { super.keyDown(with:event); return }
        let step=event.modifierFlags.contains(.shift) ? 10.0:1.0
        guard !selection.isEmpty, drag == nil else { return }
        var dx=0.0, dy=0.0
        switch event.keyCode {
        case 123: dx = -step/max(1,pictureRect.width)
        case 124: dx = step/max(1,pictureRect.width)
        case 125: dy = step/max(1,pictureRect.height)
        default: dy = -step/max(1,pictureRect.height)
        }
        let chosen=selection.map { zones[$0] }
        dx=max(-chosen.map(\.x).min()!,min(dx,1-chosen.map { $0.x+$0.width }.max()!))
        dy=max(-chosen.map(\.y).min()!,min(dy,1-chosen.map { $0.y+$0.height }.max()!))
        var changes: [Int:SampleZone]=[:]
        for i in selection { zones[i].x += dx; zones[i].y += dy; changes[i]=zones[i] }
        commit(changes); rebuildAccessibility(); needsDisplay=true
    }
    fileprivate func selectForAccessibility(_ i: Int) -> Bool {
        guard zones.indices.contains(i) else { return false }
        selectedIndex=i; selection=[i]; onSelect(i); needsDisplay=true
        window?.makeFirstResponder(self)
        return true
    }
    private func rebuildAccessibility() {
        if elements.count != zones.count {
            elements=zones.indices.map { i in
                let e=ZoneAccessibilityElement()
                e.canvas=self; e.index=i
                e.setAccessibilityParent(self); e.setAccessibilityRole(.button); e.setAccessibilityEnabled(true)
                e.setAccessibilityLabel("Zone \(i+1)")
                return e
            }
            setAccessibilityChildren(elements)
        }
        for i in zones.indices {
            let box=convert(rect(for:zones[i]),to:nil)
            elements[i].setAccessibilityFrame(window?.convertToScreen(box) ?? box)
            elements[i].setAccessibilitySelected(selection.contains(i))
            elements[i].setAccessibilityValue(tr("X \(Int(zones[i].x*100)) Prozent, Y \(Int(zones[i].y*100)) Prozent"))
        }
    }
}

private final class ZoneAccessibilityElement: NSAccessibilityElement {
    weak var canvas: ZoneCanvasView?
    var index=0
    override func accessibilityPerformPress() -> Bool { canvas?.selectForAccessibility(index) ?? false }
}
