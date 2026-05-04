import Fluent

/// Agrega los campos de verificación de identidad a la tabla `claim_requests`.
struct ClaimRequestAddFieldsMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ClaimRequest.schema)
            .field("documento_identidad", .string, .required, .sql(.default("")))
            .field("relacion_con_establecimiento", .string, .required, .sql(.default("propietario")))
            .field("redes_sociales", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ClaimRequest.schema)
            .deleteField("documento_identidad")
            .deleteField("relacion_con_establecimiento")
            .deleteField("redes_sociales")
            .update()
    }
}
