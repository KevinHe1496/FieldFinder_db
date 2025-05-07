import Vapor
import Fluent

extension Cancha {
    
    struct Create: Content {
        let tipo: TipoCancha
        let modalidad: String
        let precio: Double
        let photo: String
        let establecimientoId: Establecimiento.IDValue
        
        func toModel() -> Cancha {
            Cancha(
                tipo: tipo,
                modalidad: modalidad,
                precio: precio,
                photo: photo,
                establecimientoId: establecimientoId
            )
        }
    }
    
    struct Public: Content {
        let id: UUID
        let tipo: TipoCancha
        let modalidad: String
        let precio: Double
        let fotos: [String]
        
    }
    
    func toPublic() -> Cancha.Public {
        Cancha
            .Public(
                id: id!,
                tipo: tipo,
                modalidad: modalidad,
                precio: precio,
                fotos: fotos.map { $0.url }
            )
    }
}
