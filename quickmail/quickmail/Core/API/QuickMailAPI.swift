import Foundation

actor QuickMailAPI {
    private let session: URLSession
    private var credential: Credential?

    init(credential: Credential? = nil, session: URLSession = .shared) {
        self.credential = credential
        self.session = session
    }

    var currentCredential: Credential? { credential }

    func install(_ credential: Credential) {
        self.credential = credential
    }

    func clearCredential() {
        credential = nil
    }

    func pair(origin rawOrigin: String, code: String, deviceName: String) async throws -> Credential {
        let origin = try OriginValidator.validate(rawOrigin)
        guard code.count == 22,
              code.unicodeScalars.allSatisfy({
                  CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-"
              }) else {
            throw APIError.invalidPairingPayload
        }

        let body = try APIDateCoding.encoder().encode(
            PairingRequest(code: code, deviceName: String(deviceName.prefix(64)))
        )
        let response: PairingResponse = try await request(
            origin: origin,
            path: ["api", "auth", "pair"],
            method: "POST",
            body: body,
            authenticated: false
        )
        guard !response.token.isEmpty, response.expiresAt > Date() else {
            throw APIError.invalidResponse
        }
        return Credential(origin: origin, token: response.token, expiresAt: response.expiresAt)
    }

    func currentUser() async throws -> User {
        let response: CurrentUserResponse = try await authenticatedRequest(
            path: ["api", "auth", "me"]
        )
        return response.user
    }

    func listThreads(
        mailbox: MailboxKind = .inbox,
        page: Int = 1,
        filters requestedFilters: MailboxFilters? = nil
    ) async throws -> MailboxPage {
        let filters = requestedFilters ?? MailboxFilters()
        var query = [
            URLQueryItem(name: "view", value: mailbox.rawValue),
            URLQueryItem(name: "page", value: String(max(1, page)))
        ]
        if !filters.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "q", value: filters.query))
        }
        if filters.unreadOnly { query.append(URLQueryItem(name: "unread", value: "1")) }
        if filters.starredOnly { query.append(URLQueryItem(name: "starred", value: "1")) }
        if filters.attachmentsOnly { query.append(URLQueryItem(name: "attachments", value: "1")) }
        if let domainID = filters.domainID { query.append(URLQueryItem(name: "domain", value: domainID)) }

        return try await authenticatedRequest(path: ["api", "mail"], query: query)
    }

    func thread(id: String) async throws -> ThreadDetail {
        try await authenticatedRequest(path: ["api", "mail", id])
    }

    func send(_ message: ComposeMessage) async throws -> SendMessageResponse {
        try await authenticatedRequest(
            path: ["api", "mail"],
            method: "POST",
            body: try APIDateCoding.encoder().encode(message)
        )
    }

    func reply(to id: String, message: ReplyMessage) async throws -> SendMessageResponse {
        try await authenticatedRequest(
            path: ["api", "mail", id],
            method: "POST",
            body: try APIDateCoding.encoder().encode(message)
        )
    }

    @discardableResult
    func updateThread(id: String, flags: ThreadFlags) async throws -> MutationResponse {
        try await authenticatedRequest(
            path: ["api", "mail", id],
            method: "PATCH",
            body: try APIDateCoding.encoder().encode(flags)
        )
    }

    func perform(_ action: MailAction, ids: [String] = []) async throws -> MailActionResponse {
        struct Body: Encodable { let action: MailAction; let ids: [String] }
        return try await authenticatedRequest(
            path: ["api", "mail", "actions"],
            method: "POST",
            body: try APIDateCoding.encoder().encode(Body(action: action, ids: ids))
        )
    }

    @discardableResult
    func deletePermanently(id: String) async throws -> MutationResponse {
        try await authenticatedRequest(path: ["api", "mail", id], method: "DELETE")
    }

    func addresses() async throws -> [MailAddress] {
        let response: AddressesResponse = try await authenticatedRequest(path: ["api", "addresses"])
        return response.addresses
    }

    func updateSignature(_ signature: String) async throws -> String {
        let response: SignatureResponse = try await authenticatedRequest(
            path: ["api", "settings", "signature"],
            method: "PATCH",
            body: try APIDateCoding.encoder().encode(SignatureUpdateRequest(signature: signature))
        )
        return response.signature
    }

    func signature() async throws -> String {
        let response: SignatureValueResponse = try await authenticatedRequest(
            path: ["api", "settings", "signature"]
        )
        return response.signature
    }

    func devices() async throws -> [DeviceSession] {
        let response: DevicesResponse = try await authenticatedRequest(path: ["api", "devices"])
        return response.devices
    }

    @discardableResult
    func revokeDevice(id: String) async throws -> MutationResponse {
        try await authenticatedRequest(path: ["api", "devices", id], method: "DELETE")
    }

    /// Revokes this mobile session when the server can identify it, then always clears local credentials.
    /// If revocation fails, the error is returned after local secure storage is wiped.
    func logout(credentialStore: CredentialStore, revokeCurrentDevice: Bool = true) async throws {
        var revocationError: Error?
        if revokeCurrentDevice, credential != nil {
            do {
                let _: MutationResponse = try await authenticatedRequest(
                    path: ["api", "auth", "session"],
                    method: "DELETE"
                )
            } catch {
                revocationError = error
            }
        }

        credential = nil
        try await credentialStore.delete()
        if let revocationError { throw revocationError }
    }

    func downloadAttachment(
        emailID: String,
        attachment: EmailAttachment,
        directory: URL = FileManager.default.temporaryDirectory
    ) async throws -> DownloadedAttachment {
        let request = try makeRequest(
            origin: try authenticatedOrigin(),
            path: ["api", "mail", emailID, "attachments", attachment.id],
            query: [URLQueryItem(name: "download", value: "1")],
            method: "GET",
            body: nil,
            authenticated: true
        )

        do {
            let (temporaryURL, response) = try await session.download(for: request)
            let http = try validate(response: response, data: nil)
            let filename = safeFilename(
                contentDispositionFilename(http.value(forHTTPHeaderField: "Content-Disposition"))
                    ?? attachment.filename
            )
            let destination = directory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
                .appendingPathComponent(filename, isDirectory: false)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return DownloadedAttachment(
                fileURL: destination,
                filename: filename,
                contentType: http.mimeType ?? attachment.contentType
            )
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func authenticatedRequest<Response: Decodable>(
        path: [String],
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Response {
        try await request(
            origin: try authenticatedOrigin(),
            path: path,
            query: query,
            method: method,
            body: body,
            authenticated: true
        )
    }

    private func request<Response: Decodable>(
        origin: URL,
        path: [String],
        query: [URLQueryItem] = [],
        method: String,
        body: Data?,
        authenticated: Bool
    ) async throws -> Response {
        let urlRequest = try makeRequest(
            origin: origin,
            path: path,
            query: query,
            method: method,
            body: body,
            authenticated: authenticated
        )
        do {
            let (data, response) = try await session.data(for: urlRequest)
            _ = try validate(response: response, data: data)
            do {
                return try APIDateCoding.decoder().decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func makeRequest(
        origin: URL,
        path: [String],
        query: [URLQueryItem],
        method: String,
        body: Data?,
        authenticated: Bool
    ) throws -> URLRequest {
        var url = origin
        for component in path { url.append(path: component) }
        if !query.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidRequest
            }
            components.queryItems = query
            guard let queryURL = components.url else { throw APIError.invalidRequest }
            url = queryURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if authenticated {
            guard let credential, !credential.isExpired else { throw APIError.unauthorized }
            request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func authenticatedOrigin() throws -> URL {
        guard let credential, !credential.isExpired else { throw APIError.unauthorized }
        return credential.origin
    }

    private func validate(response: URLResponse, data: Data?) throws -> HTTPURLResponse {
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            let message = data.flatMap(serverMessage(from:)) ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            switch response.statusCode {
            case 401: throw APIError.unauthorized
            case 403: throw APIError.forbidden(message)
            case 404: throw APIError.notFound(message)
            case 429:
                throw APIError.rateLimited(
                    retryAfter: response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                )
            default: throw APIError.server(status: response.statusCode, message: message)
            }
        }
        return response
    }

    private func serverMessage(from data: Data) -> String? {
        struct ErrorBody: Decodable { let error: String }
        return try? JSONDecoder().decode(ErrorBody.self, from: data).error
    }

    private func contentDispositionFilename(_ value: String?) -> String? {
        guard let value,
              let range = value.range(of: #"filename="([^"]+)""#, options: .regularExpression) else {
            return nil
        }
        let match = String(value[range])
        let encoded = match.dropFirst("filename=\"".count).dropLast()
        return String(encoded).removingPercentEncoding ?? String(encoded)
    }

    private func safeFilename(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "\\", with: "/")
        let filename = (normalized as NSString).lastPathComponent
        return filename.isEmpty || filename == "." || filename == ".." ? "attachment" : filename
    }
}
