import Vapor
import Queues

struct Email: Codable {
    let to: String
    let message: String
}

struct EmailJob: AsyncJob {
    
    typealias Payload = Email
 
    func dequeue(_ context: QueueContext, _ payload: Email) async throws {
        try await Task.sleep(for: .seconds(10))
        context.logger.info("Email sent to \(payload.to): \(payload.message)")
    }
    
    func error(_ context: QueueContext, _ error: any Error, _ payload: Email) async throws {
        return
    }
    
}

extension QueueName {
    
    static let email = QueueName(string: "email")
    static let notifications = QueueName(string: "notifications")
    static let backgroundTasks = QueueName(string: "background-tasks")
}
