import Foundation

enum AppLinks {
    static let privacyPolicy = httpsURL("https://quickmail.quivren.com/privacy")
    static let issueTracker = httpsURL("https://github.com/anuzsubedi/quickmail-ios/issues")
    static let supportEmail = mailtoURL("mailto:quickmail-support@quivren.com")

    private static func httpsURL(_ value: String) -> URL {
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              let url = components.url else {
            preconditionFailure("Invalid HTTPS app link: \(value)")
        }
        return url
    }

    private static func mailtoURL(_ value: String) -> URL {
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "mailto",
              components.host == nil,
              components.path.contains("@"),
              let url = components.url else {
            preconditionFailure("Invalid mail app link: \(value)")
        }
        return url
    }
}
