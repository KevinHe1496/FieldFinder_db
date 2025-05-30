import Fluent

struct EstablecimientoMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Establecimiento.schema)
            .id()
            .field("name", .string, .required)
            .field("info", .string, .required)
            .field("address2", .string)
            .field("address", .string, .required)
            .field("parqueadero", .bool, .required)
            .field("vestidores", .bool, .required)
            .field("bar", .bool, .required)
            .field("banos", .bool, .required)
            .field("duchas", .bool, .required)
            .field("longitude", .double, .required)
            .field("latitude", .double, .required)
            .field("phone", .string, .required)
            .field("created_at", .date)
            .field("updated_at", .date)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema(Establecimiento.schema).delete()
    }
}
