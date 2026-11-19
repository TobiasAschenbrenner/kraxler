import Foundation

enum AccountPasswordPolicy {
    static let minimumLength = 15

    static func accepts(_ password: String) -> Bool {
        password.unicodeScalars.count >= minimumLength
    }
}
