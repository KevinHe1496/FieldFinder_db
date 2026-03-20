import Vapor
import Fluent

final class UserFavorite: Model, @unchecked Sendable {
    static let schema = "user_favorites"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "establecimiento_id")
    var establecimiento: Establecimiento
    
    init() { }
    
    init(id: UUID? = nil, userID: User.IDValue, establecimientoID: Establecimiento.IDValue) {
        self.id = id
        self.$user.id = userID
        self.$establecimiento.id = establecimientoID
    }
}
