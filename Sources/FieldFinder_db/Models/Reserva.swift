import Vapor
import Fluent

enum EstadoPago: String, Codable {
    case pendiente
    case pagado
}

final class Reserva: Model, @unchecked Sendable {
    
    static let schema: String = "reservas"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "cancha_id")
    var cancha: Cancha
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "fecha")
    var fecha: Date
    
    @Field(key: "hora")
    var hora: String
    
    @Field(key: "estado_pago")
    var estadoPago: EstadoPago
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        canchaId: Cancha.IDValue,
        userId: User.IDValue,
        fecha: Date,
        hora: String,
        estadoPago: EstadoPago
    ) {
        self.id = id
        self.$cancha.id = canchaId
        self.$user.id = userId
        self.fecha = fecha
        self.hora = hora
        self.estadoPago = estadoPago
    }
}
