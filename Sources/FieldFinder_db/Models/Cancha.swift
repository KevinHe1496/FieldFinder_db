import Vapor
import Fluent

enum TipoCancha: String, Codable {
    case cesped
    case sintetico
}

final class Cancha: Model, @unchecked Sendable {
    
    static let schema: String = "canchas"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "tipo")
    var tipo: TipoCancha
    
    @Field(key: "modalidad")
    var modalidad: String
    
    @Field(key: "precio")
    var precio: Double
    
    @Parent(key: "establecimiento_id")
    var establecimiento: Establecimiento
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Children(for: \.$cancha)
    var fotos: [CanchaFoto]

    
    init() { }
    
    init(
        id: UUID? = nil,
        tipo: TipoCancha,
        modalidad: String,
        precio: Double,
        establecimientoId: Establecimiento.IDValue
    ) {
        self.id = id
        self.tipo = tipo
        self.modalidad = modalidad
        self.precio = precio
        self.$establecimiento.id = establecimientoId
    }
}
