import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Kraxler

extension KraxlerTests {
    @Test
    func profilePhotosAreSquareAndBoundedAndStripTheOriginalMetadata() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 320)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 320))
        }
        let originalData = try #require(image.pngData())
        let thumbnail = try #require(ProfilePhoto.jpegThumbnail(from: originalData))
        let decoded = try #require(UIImage(data: thumbnail))
        #expect(decoded.size == CGSize(width: 256, height: 256))
        #expect(thumbnail.count <= 49_152)
        #expect(ProfilePhoto.jpegThumbnail(from: Data("not a photo".utf8)) == nil)
    }

    @Test
    func loadsCloudinaryAvatarAndKeepsProviderAndDefaultFallbacks() throws {
        let cloudinary = try #require(URL(string: "https://res.cloudinary.com/kraxler/image/upload/avatar.jpg"))
        let provider = try #require(URL(string: "https://example.com/google-photo.jpg"))
        let json = Data("""
            {"displayName":"Tobias","avatarBase64":null,"avatarUrl":"\(cloudinary.absoluteString)","usesDefaultAvatar":false}
            """.utf8)
        var profile = try JSONDecoder().decode(UserProfile.self, from: json)
        #expect(profile.avatarURL == cloudinary)
        #expect(profile.photoURL(providerURL: provider) == cloudinary)
        profile.usesDefaultAvatar = true
        #expect(profile.photoURL(providerURL: provider) == nil)
        profile.usesDefaultAvatar = false
        profile.avatarURL = nil
        #expect(profile.photoURL(providerURL: provider) == provider)

        let oldResponse = Data("""
            {"displayName":"Tobias","avatarBase64":null,"usesDefaultAvatar":false}
            """.utf8)
        #expect(try JSONDecoder().decode(UserProfile.self, from: oldResponse).avatarURL == nil)
    }

    @Test
    func doesNotResubmitCloudinaryURLsAsProfileUpdateAuthority() throws {
        let profile = UserProfile(displayName: "Tobias", avatarBase64: nil, usesDefaultAvatar: false,
                                  avatarURL: URL(string: "https://res.cloudinary.com/kraxler/avatar.jpg"))
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
        #expect(json["avatarUrl"] == nil)
        #expect(json["avatarBase64"] is NSNull)
    }

    @Test
    func sendsExplicitNullWhenRemovingTheProfilePhoto() async throws {
        let client = makeClient(authTokenProvider: { "test-token" }) { request in
            #expect(request.url?.path == "/api/v1/me/profile")
            #expect(request.httpMethod == "PUT")
            let body = try #require(Self.bodyData(from: request))
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["avatarBase64"] is NSNull)
            #expect(json["displayName"] as? String == "Tobias")
            return Self.response(for: request, body: """
                {"data":{"displayName":"Tobias","avatarBase64":null,"usesDefaultAvatar":true}}
                """)
        }
        let result = try await client.updateUserProfile(UserProfile(
            displayName: "Tobias", avatarBase64: nil, usesDefaultAvatar: true
        ))
        #expect(result.displayName == "Tobias")
        #expect(result.usesDefaultAvatar)
    }

}
