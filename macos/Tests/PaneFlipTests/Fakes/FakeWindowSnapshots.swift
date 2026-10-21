import CoreGraphics

/// Pictures for the windows it was told about; anything else cannot be captured. Answers when told to, so a test
/// decides when the capture "finishes".
final class FakeWindowSnapshots: WindowSnapshotting {
    var images: [CGWindowID: WindowPicture] = [:]
    var answersAtOnce = true
    private(set) var prepared = 0
    /// How many times pictures were asked for.
    private(set) var requests = 0

    func prepare() { prepared += 1 }
    private var waiting: [() -> Void] = []

    func snapshots(of refs: [WindowRef], completion: @escaping ([CGWindowID: WindowPicture]) -> Void) {
        requests += 1
        let result = images.filter { id, _ in refs.contains { $0.id == id } }
        if answersAtOnce { completion(result) } else { waiting.append { completion(result) } }
    }

    /// Answers what is waiting now (a request made by an answer waits for the next call).
    func answer() {
        let now = waiting
        waiting = []
        now.forEach { $0() }
    }

    static func picture() -> WindowPicture {
        let image = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        return WindowPicture(image: image, frame: CGRect(x: 0, y: 0, width: 100, height: 100), cornerRadius: 0)
    }
}
