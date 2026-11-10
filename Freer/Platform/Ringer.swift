import AudioToolbox

/// One ring of an incoming call or meeting — what `NSSound` does on the Mac.
///
/// A system alert sound rather than a bundled file: it follows the
/// ringer switch, vibrating when the phone is silenced, which is what a
/// person expects of something that rings.
enum Ringer {
    /// The three-note message tone. System sound IDs are stable but
    /// unnamed in the SDK.
    private static let tone: SystemSoundID = 1007

    static func ringOnce() {
        AudioServicesPlayAlertSound(tone)
    }
}
