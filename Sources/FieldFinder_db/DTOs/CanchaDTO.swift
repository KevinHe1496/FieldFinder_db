import Vapor
import Fluent

extension Cancha {
    
    struct Create: Content {
        let tipo: TipoCancha
        let modalidad: String
        let precio: Double
        let iluminada: Bool
        let cubierta: Bool
        let establecimientoID: UUID
        
        func toModel() -> Cancha {
            Cancha(
                tipo: tipo,
                modalidad: modalidad,
                precio: precio,
                iluminada: iluminada,
                cubierta: cubierta,
                establecimientoId: establecimientoID
            )
        }
    }
    
    struct Public: Content {
        let id: UUID
        let tipo: String
        let modalidad: String
        let precio: Double
        let iluminada: Bool
        let cubierta: Bool
        let fotos: [String]
        
    }
    
    func toPublic() -> Cancha.Public {
        Cancha
            .Public(
                id: id!,
                tipo: tipo.displayName,
                modalidad: modalidad,
                precio: precio,
                iluminada: iluminada,
                cubierta: cubierta,
                fotos: fotos.map { $0.url }
            )
    }
    
    struct List: Content {
        let id: UUID
    }
    
    func toList() -> Cancha.List {
        Cancha.List(id: id!)
    }
    
    struct Update: Content {
        let tipo: TipoCancha
        let modalidad: String
        let precio: Double
        let iluminada: Bool
        let cubierta: Bool
    }
}
