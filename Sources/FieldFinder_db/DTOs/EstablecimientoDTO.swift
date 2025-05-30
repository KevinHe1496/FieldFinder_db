import Vapor

extension Establecimiento {
    
    struct Create: Content {
        let name: String
        let info: String
        let address: String
        let address2: String?
        let parqueadero: Bool
        let vestidores: Bool
        let bar: Bool
        let banos: Bool
        let duchas: Bool
        let latitude: Double
        let longitude: Double
        let phone: String
 
        func toModel(userId: UUID) -> Establecimiento {
            Establecimiento(
                name: name,
                info: info,
                address: address,
                address2: address2,
                parqueadero: parqueadero,
                vestidores: vestidores,
                bar: bar,
                banos: banos,
                duchas: duchas,
                latitude: latitude,
                longitude: longitude,
                phone: phone,
                userId: userId
            )
        }
    }
    struct Public: Content {
        let id: UUID
        let name: String
        let info: String
        let fotos: [String]
        let address: String
        let address2: String?
        let parquedero: Bool
        let vestidores: Bool
        let bar: Bool
        let banos: Bool
        let duchas: Bool
        let canchas: [Cancha.Public]
        let userName: String
        let userRol: RolUsuario
        let latitude: Double
        let longitude: Double
        let phone: String
        let isFavorite: Bool
    }
    
    struct List: Content {
        let id: UUID
    }
    
    func toList() -> Establecimiento.List {
        Establecimiento.List(id: id!)
    }
    
    struct Update: Content {
        let name: String
        let info: String
        let address: String
        let address2: String?
        let parqueadero: Bool
        let vestidores: Bool
        let bar: Bool
        let banos: Bool
        let duchas: Bool
        let latitude: Double
        let longitude: Double
        let phone: String
    }
    
    func toPublic(isFavorite: Bool = false) -> Establecimiento.Public {
        Establecimiento
            .Public(
                id: self.id!,
                name: self.name,
                info: self.info,
                fotos: self.fotos.map { $0.url },
                address: self.address,
                address2: self.address2,
                parquedero: self.parqueadero,
                vestidores: self.vestidores,
                bar: self.bar,
                banos: self.banos,
                duchas: self.duchas,
                canchas: self.canchas.map({ cancha in
                    cancha.toPublic()
                }),
                userName: self.user.name,
                userRol: self.user.rol,
                latitude: self.latitude,
                longitude: self.longitude,
                phone: self.phone,
                isFavorite: isFavorite
            )
        
    }
    
    struct FavoriteDTO: Content {
        let id: UUID
        let name: String
        let address: String
        let fotos: [String]
        let isFavorite: Bool
    }

    func toFavoriteDTO(isFavorite: Bool) -> FavoriteDTO {
        FavoriteDTO(
            id: self.id!,
            name: self.name,
            address: self.address,
            fotos: self.fotos.map { $0.url },
            isFavorite: isFavorite
        )
    }
}
