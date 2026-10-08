import Fluent

/// Agrega `google_place_id` a `establecimientos` para que el seed de Google Places no cree duplicados.
/// Es opcional: los establecimientos creados a mano o por dueños lo dejan en NULL.
struct EstablecimientoGooglePlaceIDMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Establecimiento.schema)
            .field("google_place_id", .string)
            .unique(on: "google_place_id")
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Establecimiento.schema)
            .deleteUnique(on: "google_place_id")
            .deleteField("google_place_id")
            .update()
    }
}
