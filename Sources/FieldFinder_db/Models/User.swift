import Vapor
import Fluent

enum RolUsuario: String, Codable {
    case jugador
    case dueno
}

final class User: Model, @unchecked Sendable {
    
    static let schema: String = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password")
    var password: String
    
    @Field(key: "rol")
    var rol: RolUsuario
    
    @Field(key: "is_admin")
    var isAdmin: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @OptionalChild(for: \Establecimiento.$user)
    var establecimiento: Establecimiento?
    
    @Siblings(through: UserFavorite.self, from: \.$user, to: \.$establecimiento)
    var favoritos: [Establecimiento]
    
    init() {}
    
    init(id: UUID? = nil, name: String, email: String, password: String, rol: RolUsuario, isAdmin: Bool = false) {
        self.id = id
        self.name = name
        self.email = email
        self.password = password
        self.rol = rol
        self.isAdmin = isAdmin
    }
}


extension User: ModelAuthenticatable {
    static var usernameKey: KeyPath<User, Field<String>> {
        \User.$email
        
    }
    
    static var passwordHashKey: KeyPath<User, Field<String>> {
        \User.$password
    }

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
    
}
