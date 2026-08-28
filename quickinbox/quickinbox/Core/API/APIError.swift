import Foundation

nonisolated enum APIError: LocalizedError, Equatable, Sendable {
    case invalidOrigin(String)
    case invalidPairingPayload
    case invalidRequest
    case invalidResponse
    case unauthorized
    case forbidden(String)
    case notFound(String)
    case rateLimited(retryAfter: TimeInterval?)
    case server(status: Int, message: String)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidOrigin(let message): message
        case .invalidPairingPayload: "This QuickInbox pairing code is not supported."
        case .invalidRequest: "The request could not be created."
        case .invalidResponse: "The server returned an invalid response."
        case .unauthorized: "Your QuickInbox session is no longer valid."
        case .forbidden(let message), .notFound(let message): message
        case .rateLimited(let delay):
            if let delay { "Too many attempts. Try again in \(Int(delay.rounded(.up))) seconds." }
            else { "Too many attempts. Try again later." }
        case .server(_, let message): message
        case .transport(let message): message
        case .decoding: "QuickInbox returned data this app could not read."
        }
    }
}
