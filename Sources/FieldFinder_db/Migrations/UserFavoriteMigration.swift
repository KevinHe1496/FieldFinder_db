import Vapor
import Fluent

struct UserFavoriteMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(UserFavorite.schema)
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("establecimiento_id", .uuid, .required, .references("establecimientos", "id", onDelete: .cascade))
            .unique(on: "user_id", "establecimiento_id") // un mismo favorito no se repite
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(UserFavorite.schema).delete()
    }
}

