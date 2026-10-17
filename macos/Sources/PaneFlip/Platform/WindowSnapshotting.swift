import CoreGraphics

/// Takes a picture of windows, wherever they are (also behind other windows). Needs the Screen Recording permission.
protocol WindowSnapshotting {
    /// Gets ready for the next `snapshots` call (called when a pill appears), so that call is quick.
    func prepare()
    /// The pictures of `refs`, by window; a window that could not be captured is missing from the result.
    func snapshots(of refs: [WindowRef], completion: @escaping ([CGWindowID: WindowPicture]) -> Void)
}
