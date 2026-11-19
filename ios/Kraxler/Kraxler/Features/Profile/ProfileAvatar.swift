import SwiftUI

struct ProfileAvatar: View {
    var data: Data?
    var photoURL: URL?
    var size: CGFloat = 58

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let photoURL, photoURL.scheme == "https" {
                AsyncImage(url: photoURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.46))
                .foregroundStyle(.secondary)
        }
    }
}
