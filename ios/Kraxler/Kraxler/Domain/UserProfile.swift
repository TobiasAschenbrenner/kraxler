import Foundation

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    var displayName: String?
    var avatarBase64: String?
    var usesDefaultAvatar: Bool
    var avatarURL: URL? = nil

    var avatarData: Data? {
        avatarBase64.flatMap { Data(base64Encoded: $0) }
    }

    func photoURL(providerURL: URL?) -> URL? {
        usesDefaultAvatar ? nil : avatarURL ?? providerURL
    }

    private enum CodingKeys: String, CodingKey {
        case displayName, avatarBase64, usesDefaultAvatar
        case avatarURL = "avatarUrl"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(avatarBase64, forKey: .avatarBase64)
        try container.encode(usesDefaultAvatar, forKey: .usesDefaultAvatar)
    }
}
