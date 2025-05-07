import Fluent

struct CanchaMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Cancha.schema)
            .id()
            .field("tipo", .string, .required)
            .field("modalidad", .string, .required)
            .field("precio", .double, .required)
            .field("created_at", .date)
            .field("updated_at", .date)
            .field("establecimiento_id", .uuid, .required, .references("establecimientos", "id"))
            .create()
        
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema(Cancha.schema).delete()
    }
}
