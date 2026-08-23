import Foundation

nonisolated enum OriginValidator {
    static func validate(_ rawValue: String) throws -> URL {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, var components = URLComponents(string: value) else {
            throw APIError.invalidOrigin("Enter your QuickMail server URL.")
        }

        guard components.user == nil, components.password == nil else {
            throw APIError.invalidOrigin("The server URL cannot contain credentials.")
        }
        guard components.query == nil, components.fragment == nil else {
            throw APIError.invalidOrigin("Use only the QuickMail server origin, without a query or fragment.")
        }
        guard components.path.isEmpty || components.path == "/" else {
            throw APIError.invalidOrigin("Use only the QuickMail server origin, without a path.")
        }
        guard let host = components.host, !host.isEmpty else {
            throw APIError.invalidOrigin("The server URL must include a host.")
        }

        let scheme = components.scheme?.lowercased()
        #if DEBUG
        let isLocalHTTP = scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host.lowercased())
        #else
        let isLocalHTTP = false
        #endif
        guard scheme == "https" || isLocalHTTP else {
            throw APIError.invalidOrigin("QuickMail requires a secure HTTPS server URL.")
        }

        components.scheme = scheme
        components.host = host.lowercased()
        components.path = ""
        guard let url = components.url, url.absoluteURL == url else {
            throw APIError.invalidOrigin("The QuickMail server URL is invalid.")
        }
        return url
    }
}
