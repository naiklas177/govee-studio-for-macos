import Foundation
import AmbienceCore

/// Serial mode activation. A rapid series of clicks coalesces before startup;
/// restoration always finishes before another output source may start.
@MainActor
final class ModeActivationQueue<Target> {
    private var worker: Task<Void,Never>?
    private var desired: Target?
    private var cancelling=false
    var changed: (Bool,Target?)->Void = { _,_ in }
    var interruptStart: ()->Void = {}
    var stopCurrent: () async ->Void = {}
    var start: (Target) async ->Void = {_ in}
    func request(_ mode: Target) {
        guard !cancelling else { return }
        desired=mode; changed(true,mode); interruptStart()
        guard worker == nil else { return }
        worker=Task { [weak self] in
            guard let self else { return }
            while self.desired != nil && !Task.isCancelled {
                await self.stopCurrent()
                guard !Task.isCancelled,let target=self.desired else { break }
                self.desired=nil
                await self.start(target)
            }
            self.worker=nil
            self.changed(false,nil)
        }
    }
    func cancelAndWait() async {
        cancelling=true; desired=nil
        let task=worker; task?.cancel(); interruptStart()
        await task?.value
        cancelling=false
    }
}
