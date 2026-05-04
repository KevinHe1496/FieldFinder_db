import Vapor

extension ClaimRequest {

    /// Datos que el usuario envía al momento de reclamar un establecimiento.
    struct Create: Content {
        let telefonoContacto: String
        let mensaje: String
        let documentoIdentidad: String
        let relacionConEstablecimiento: RelacionConEstablecimiento
        let redesSociales: String?
    }

    /// Representación pública de una solicitud de reclamación.
    struct Public: Content {
        let id: UUID
        let userID: UUID
        let userName: String
        let userEmail: String
        let establecimientoID: UUID
        let establecimientoNombre: String
        let telefonoContacto: String
        let mensaje: String
        let documentoIdentidad: String
        let relacionConEstablecimiento: RelacionConEstablecimiento
        let redesSociales: String?
        let status: ClaimStatus
        let createdAt: Date?
    }

    /// Convierte el modelo a su representación pública.
    /// Requiere que las relaciones `user` y `establecimiento` estén cargadas.
    func toPublic() -> ClaimRequest.Public {
        ClaimRequest.Public(
            id: self.id!,
            userID: self.$user.id,
            userName: self.user.name,
            userEmail: self.user.email,
            establecimientoID: self.$establecimiento.id,
            establecimientoNombre: self.establecimiento.name,
            telefonoContacto: self.telefonoContacto,
            mensaje: self.mensaje,
            documentoIdentidad: self.documentoIdentidad,
            relacionConEstablecimiento: self.relacionConEstablecimiento,
            redesSociales: self.redesSociales,
            status: self.status,
            createdAt: self.createdAt
        )
    }
}
