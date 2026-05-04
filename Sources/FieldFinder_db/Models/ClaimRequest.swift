import Vapor
import Fluent

/// Estados posibles de una solicitud de reclamación.
enum ClaimStatus: String, Codable {
    case pendiente   // Enviada, esperando revisión
    case aprobada    // Aprobada: el usuario se convierte en dueño del establecimiento
    case rechazada   // Rechazada por el administrador
}

/// Relación del reclamante con el establecimiento.
enum RelacionConEstablecimiento: String, Codable {
    case propietario
    case administrador
    case representante
}

/// Modelo que representa la solicitud formal de un usuario para reclamar la propiedad de un establecimiento.
/// Un establecimiento puede tener múltiples solicitudes (de distintos usuarios), pero solo una puede aprobarse.
final class ClaimRequest: Model, @unchecked Sendable {

    static let schema = "claim_requests"

    @ID(key: .id)
    var id: UUID?

    /// Usuario que envía la solicitud
    @Parent(key: "user_id")
    var user: User

    /// Establecimiento que se desea reclamar
    @Parent(key: "establecimiento_id")
    var establecimiento: Establecimiento

    /// Teléfono de contacto proporcionado por el reclamante
    @Field(key: "telefono_contacto")
    var telefonoContacto: String

    /// Mensaje explicando por qué el usuario es el dueño legítimo
    @Field(key: "mensaje")
    var mensaje: String

    /// Número de cédula o RIF del negocio para verificación
    @Field(key: "documento_identidad")
    var documentoIdentidad: String

    /// Relación del reclamante con el establecimiento
    @Field(key: "relacion_con_establecimiento")
    var relacionConEstablecimiento: RelacionConEstablecimiento

    /// URL de redes sociales del negocio (opcional)
    @OptionalField(key: "redes_sociales")
    var redesSociales: String?

    /// Estado actual de la solicitud
    @Field(key: "status")
    var status: ClaimStatus

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        establecimientoID: UUID,
        telefonoContacto: String,
        mensaje: String,
        documentoIdentidad: String,
        relacionConEstablecimiento: RelacionConEstablecimiento,
        redesSociales: String? = nil,
        status: ClaimStatus = .pendiente
    ) {
        self.id = id
        self.$user.id = userID
        self.$establecimiento.id = establecimientoID
        self.telefonoContacto = telefonoContacto
        self.mensaje = mensaje
        self.documentoIdentidad = documentoIdentidad
        self.relacionConEstablecimiento = relacionConEstablecimiento
        self.redesSociales = redesSociales
        self.status = status
    }
}
