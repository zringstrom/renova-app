import Foundation

/// Remembers which HR chest strap was used last, so a future session can go
/// straight for it instead of racing whichever compatible device happens to
/// advertise first when more than one is in range.
enum LastDeviceStore {
    private static let idKey = "lastHRDeviceID"
    private static let nameKey = "lastHRDeviceName"

    static var lastDeviceID: UUID? {
        UserDefaults.standard.string(forKey: idKey).flatMap(UUID.init)
    }

    static var lastDeviceName: String? {
        UserDefaults.standard.string(forKey: nameKey)
    }

    static func remember(id: UUID, name: String) {
        UserDefaults.standard.set(id.uuidString, forKey: idKey)
        UserDefaults.standard.set(name, forKey: nameKey)
    }

    /// Clears the remembered device only if it's the one being forgotten —
    /// used when a device we'd saved turns out to be a watch (rejected via
    /// Body Sensor Location) so a bad memory doesn't stick around forever.
    static func forget(ifMatches id: UUID) {
        guard lastDeviceID == id else { return }
        UserDefaults.standard.removeObject(forKey: idKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
    }
}
