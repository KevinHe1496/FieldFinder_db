import Vapor
import Fluent

final class EstablecimientoFoto: Model, Content, @unchecked Sendable {
    static let schema: String = "establecimiento_fotos"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "url")
    var url: String
    
    @Parent(key: "establecimiento_id")
    var establecimiento: Establecimiento
    
    init() { }
    
    init(id: UUID? = nil, url: String, establecimientoID: Establecimiento.IDValue) {
        self.id = id
        self.url = url
        self.$establecimiento.id = establecimientoID
    }
}
