import Vapor
import Fluent

final class Pago: Model, @unchecked Sendable {
    
    static let schema = "pagos"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "reserva_id")
    var reserva: Reserva

    @Field(key: "monto")
    var monto: Double

    @Field(key: "estado")
    var estado: String // "pagado", "pendiente", "fallido"

    @Field(key: "metodo")
    var metodo: String // "stripe", "paypal", etc.

    @Field(key: "transaccion_id")
    var transaccionID: String

    @Timestamp(key: "creado_en", on: .create)
    var creadoEn: Date?

    init() { }

    init(id: UUID? = nil, reservaID: UUID, monto: Double, estado: String, metodo: String, transaccionID: String) {
        self.id = id
        self.$reserva.id = reservaID
        self.monto = monto
        self.estado = estado
        self.metodo = metodo
        self.transaccionID = transaccionID
    }
}

