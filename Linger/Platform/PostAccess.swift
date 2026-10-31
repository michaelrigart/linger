import CoreGraphics

enum PostAccess {
    static var isGranted: Bool { CGPreflightPostEventAccess() }

    static func request() {
        _ = CGRequestPostEventAccess()
    }
}
