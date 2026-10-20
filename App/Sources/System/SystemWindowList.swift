import CoreGraphics

/// Asks the window server where windows are, with `CGWindowListCopyWindowInfo` (ADR-0006).
///
/// The window server answers even while the window's app is busy, and only the window's number,
/// owner, layer and bounds are read: no window titles, so no Screen Recording permission is needed.
@MainActor
struct SystemWindowList: WindowListing {
    func window(at point: CGPoint, excluding ownPID: pid_t) -> ListedWindow? {
        ListedWindow.frontmost(
            in: Self.list([.optionOnScreenOnly, .excludeDesktopElements], relativeTo: kCGNullWindowID),
            at: point,
            excluding: ownPID
        )
    }

    func bounds(of id: CGWindowID) -> CGRect? {
        Self.list(.optionIncludingWindow, relativeTo: id).first { $0.id == id }?.bounds
    }

    private static func list(_ options: CGWindowListOption, relativeTo id: CGWindowID) -> [ListedWindow] {
        guard let info = CGWindowListCopyWindowInfo(options, id) as? [[String: Any]] else { return [] }
        return info.compactMap(ListedWindow.init(info:))
    }
}
