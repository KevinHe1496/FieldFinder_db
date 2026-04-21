import Vapor

extension ClaimRequest {

    /// Datos que el usuario envía al momento de reclamar un establecimiento.
    struct Create: Content {
        /// Teléfono donde el administrador puede contactar al reclamante para verificar identidad.
        let telefonoContacto: String
        /// Mensaje libre explicando por qué el usuario es el dueño legítimo del establecimiento.
        let mensaje: String
    }

    /// Representación pública de una solicitud de reclamación.
    /// Devuelta en las respuestas de la API (tanto al usuario como al administrador).
    struct Public: Content {
        let id: UUID
        let userID: UUID
        let userName: String
        let userEmail: String
        let establecimientoID: UUID
        let establecimientoNombre: String
        let telefonoContacto: String
        let mensaje: String
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
            status: self.status,
            createdAt: self.createdAt
        )
    }
}
