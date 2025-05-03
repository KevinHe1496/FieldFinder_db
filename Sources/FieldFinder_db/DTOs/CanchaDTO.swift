import Vapor
import Fluent

extension Cancha {
    
    struct Create: Content {
        let tipo: TipoCancha
        let modalidad: String
        let precio: Double
        let photo: String
        let establecimiento: Establecimiento.IDValue
        
        func toModel() -> Cancha {
            Cancha(
                tipo: tipo,
                modalidad: modalidad,
                precio: precio,
                photo: photo,
                establecimientoId: establecimiento
            )
        }
    }
    
    struct Public: Content {
        let id: UUID
        let tipo: TipoCancha
        let modalidad: String
        let precio: Double
        let photo: String
    }
    
    func toPublic() -> Cancha.Public {
        Cancha
            .Public(
                id: id!,
                tipo: tipo,
                modalidad: modalidad,
                precio: precio,
                photo: photo
            )
    }
}
