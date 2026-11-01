import OSLog

enum Log {
    static let engine = Logger(subsystem: "com.michaelrigart.linger", category: "engine")
    static let probe = Logger(subsystem: "com.michaelrigart.linger", category: "probe")
}
