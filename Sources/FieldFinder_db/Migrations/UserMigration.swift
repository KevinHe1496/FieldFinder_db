import Vapor
import Fluent

struct UserMigration: AsyncMigration {
    
    func prepare(on database: any Database) async throws {
        try await database
            .schema(User.schema)
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("password", .string, .required)
            .field("rol", .string, .required)
            .field("is_admin", .bool, .required)
            .field("created_at", .date)
            .field("updated_at", .date)
            .unique(on: "email")
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema(User.schema).delete()
    }
}
