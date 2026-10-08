import Foundation

/// Use the installed app's resources first; Bundle.module is only for swift run.
enum Localization {
    static let bundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("iClip_iClip.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
}
