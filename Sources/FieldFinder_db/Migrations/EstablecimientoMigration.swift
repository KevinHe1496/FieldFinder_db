import Fluent

struct EstablecimientoMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Establecimiento.schema)
            .id()
            .field("name", .string, .required)
            .field("info", .string, .required)
            .field("photo", .string, .required)
            .field("country", .string, .required)
            .field("city", .string, .required)
            .field("address", .string, .required)
            .field("zip_code", .string, .required)
            .field("parqueadero", .bool, .required)
            .field("vestidores", .bool, .required)
            .field("bar", .bool, .required)
            .field("cubierta", .bool, .required)
            .field("longitude", .double, .required)
            .field("latitude", .double, .required)
            .field("phone", .string, .required)
            .field("created_at", .date)
            .field("updated_at", .date)
            .field("user_id", .uuid, .required, .references("users", "id"))
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema(Establecimiento.schema).delete()
    }
}
