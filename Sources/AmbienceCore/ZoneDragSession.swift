import Foundation

/// All motion is measured against the mouse-down point in the stationary canvas,
/// never against the moving zone or its most recently clamped position.
public struct ZoneDragSession: Sendable {
    public enum Operation: Sendable { case move, resize }
    public let origin: SampleZone
    private let startX: Double
    private let startY: Double
    private let canvasWidth: Double
    private let canvasHeight: Double
    private let operation: Operation

    public init(zone: SampleZone, pointerX: Double, pointerY: Double,
                canvasWidth: Double, canvasHeight: Double, operation: Operation) {
        self.origin=zone; self.startX=pointerX; self.startY=pointerY
        self.canvasWidth=max(1,canvasWidth); self.canvasHeight=max(1,canvasHeight)
        self.operation=operation
    }
    public func zone(pointerX: Double, pointerY: Double) -> SampleZone {
        let dx=(pointerX-startX)/canvasWidth
        let dy=(pointerY-startY)/canvasHeight
        guard dx.isFinite, dy.isFinite else { return origin }
        var result=origin
        switch operation {
        case .move:
            result.x += dx; result.y += dy
        case .resize:
            // Clamp dimensions before SampleZone.clamp, so resizing never moves the anchor.
            result.width=max(0.015,min(1-origin.x,origin.width+dx))
            result.height=max(0.015,min(1-origin.y,origin.height+dy))
        }
        result.clamp()
        return result
    }
}
