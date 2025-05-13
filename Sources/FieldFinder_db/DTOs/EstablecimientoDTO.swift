import Vapor

extension Establecimiento {
    
    struct Create: Content {
        let name: String
        let info: String
        let address: String
        let country: String
        let city: String
        let zipCode: String
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
                country: country,
                city: city,
                zipCode: zipCode,
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
        let country: String
        let city: String
        let zipCode: String
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
    }
    
    struct Update: Content {
        let name: String
        let info: String
        let address: String
        let country: String
        let city: String
        let zipCode: String
        let parqueadero: Bool
        let vestidores: Bool
        let bar: Bool
        let banos: Bool
        let duchas: Bool
        let latitude: Double
        let longitude: Double
        let phone: String
    }
    
    func toPublic() -> Establecimiento.Public {
        Establecimiento
            .Public(
                id: self.id!,
                name: self.name,
                info: self.info,
                fotos: self.fotos.map { $0.url },
                address: self.address,
                country: self.country,
                city: self.city,
                zipCode: self.zipCode,
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
                phone: self.phone
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
