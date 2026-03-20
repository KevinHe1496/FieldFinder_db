import Vapor
import Fluent

final class CanchaFoto: Model, Content, @unchecked Sendable {
    static let schema = "cancha_fotos"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "url")
    var url: String
    
    @Parent(key: "cancha_id")
    var cancha: Cancha
    
    init() {}
    
    init(id: UUID? = nil, url: String, canchaID: Cancha.IDValue) {
        self.id = id
        self.url = url
        self.$cancha.id = canchaID
    }
}
