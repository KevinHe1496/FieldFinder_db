import Vapor
import Fluent

extension User {
    // Lo que se necesita para crear el usuario
    struct Create: Content {
        let name: String
        let email: String
        let password: String
        let rol: RolUsuario
        
        func toModel(withHashedPassword hashedPassword: String) -> User {
            User(
                name: name,
                email: email,
                password: hashedPassword,
                rol: rol
            )
        }
    }
    
    // Información pública que se le devolvera al usuario
    struct Public: Content {
        let id: UUID
        let name: String
        let email: String
        let rol: RolUsuario
    }
    
    func toPublic() -> User.Public {
        User
            .Public(
                id: id!,
                name: name,
                email: email,
                rol: rol
            )
    }
    
    struct Update: Content {
        let name: String
        let password: String
    }
    
    func toUpdate() -> User.Update {
        User.Update(name: name, password: password)
    }
}

// Validamos los campos solo cuando se crea
extension User.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: .count(2...50), required: true)
        validations.add("email", as: String.self, is: .email, required: true)
        validations.add("password", as: String.self, is: .count(6...24) && .alphanumeric, required: true)
    }
}


extension User.Update: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: .count(2...50), required: true)
        validations.add("password", as: String.self, is: .count(6...24) && .alphanumeric, required: true)
    }
}
