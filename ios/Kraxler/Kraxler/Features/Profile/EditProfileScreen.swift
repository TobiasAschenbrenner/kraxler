import ImageIO
import PhotosUI
import SwiftUI

struct EditProfileScreen: View {
    let account: AuthenticatedAccount?
    let apiClient: APIClient
    let onSave: (UserProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var avatarData: Data?
    @State private var usesDefaultAvatar: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSaving = false
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?

    init(
        profile: UserProfile?,
        account: AuthenticatedAccount?,
        apiClient: APIClient,
        onSave: @escaping (UserProfile) -> Void
    ) {
        self.account = account
        self.apiClient = apiClient
        self.onSave = onSave
        _displayName = State(initialValue: profile?.displayName ?? account?.displayName ?? "")
        _avatarData = State(initialValue: profile?.avatarData)
        _usesDefaultAvatar = State(initialValue: profile?.usesDefaultAvatar ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 14) {
                        ProfileAvatar(
                            data: avatarData,
                            photoURL: usesDefaultAvatar ? nil : account?.photoURL,
                            size: 88
                        )
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Change photo")
                        }
                        .disabled(isSaving || isLoadingPhoto)
                        .accessibilityIdentifier("profile-change-photo")

                        if avatarData != nil || (!usesDefaultAvatar && account?.photoURL != nil) {
                            Button("Remove photo", role: .destructive) {
                                avatarData = nil
                                usesDefaultAvatar = true
                                selectedPhoto = nil
                            }
                            .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .listRowBackground(KraxlerDesign.sectionBackground)

                Section("Name") {
                    TextField("Name", text: $displayName)
                        .textContentType(.name)
                        .accessibilityIdentifier("profile-name-field")
                }
                .listRowBackground(KraxlerDesign.sectionBackground)

                Section("Email") {
                    Text(account?.email ?? "Not available")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(KraxlerDesign.sectionBackground)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KraxlerScreenBackground())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || isLoadingPhoto || trimmedName.isEmpty || trimmedName.count > 80)
                        .accessibilityIdentifier("profile-save")
                }
            }
            .task(id: selectedPhoto) {
                await loadPhoto()
            }
        }
        .tint(KraxlerDesign.accent)
    }

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let profile = try await apiClient.updateUserProfile(UserProfile(
                displayName: trimmedName,
                avatarBase64: avatarData?.base64EncodedString(),
                usesDefaultAvatar: usesDefaultAvatar
            ))
            onSave(profile)
            dismiss()
        } catch {
            errorMessage = "Couldn’t save profile. Try again."
        }
    }

    private func loadPhoto() async {
        guard let selectedPhoto else { return }
        isLoadingPhoto = true
        errorMessage = nil
        defer { isLoadingPhoto = false }
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                  !Task.isCancelled,
                  let resized = ProfilePhoto.jpegThumbnail(from: data)
            else {
                if !Task.isCancelled { errorMessage = "Choose another photo." }
                return
            }
            avatarData = resized
            usesDefaultAvatar = false
        } catch {
            if !Task.isCancelled { errorMessage = "Couldn’t load photo." }
        }
    }
}

enum ProfilePhoto {
    static func jpegThumbnail(from data: Data) -> Data? {
        guard data.count <= 20_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 256,
              ] as CFDictionary)
        else { return nil }

        let image = UIImage(cgImage: thumbnail)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format)
        let square = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            let scale = max(256 / image.size.width, 256 / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (256 - size.width) / 2, y: (256 - size.height) / 2,
                                 width: size.width, height: size.height))
        }
        for quality in [0.85, 0.65, 0.45, 0.25] {
            if let jpeg = square.jpegData(compressionQuality: quality), jpeg.count <= 49_152 {
                return jpeg
            }
        }
        return nil
    }
}
