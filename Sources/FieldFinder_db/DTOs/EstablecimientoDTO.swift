import Vapor

extension Establecimiento {
    
    struct Create: Content {
        let name: String
        let info: String
        let photo: String
        let address: String
        let country: String
        let city: String
        let zipCode: String
        let parqueadero: Bool
        let vestidores: Bool
        let bar: Bool
        let cubierta: Bool
        let latitude: Double
        let longitude: Double
        let phone: String
 
        func toModel(userId: UUID) -> Establecimiento {
            Establecimiento(
                name: name,
                info: info,
                photo: photo,
                address: address,
                country: country,
                city: city,
                zipCode: zipCode,
                parqueadero: parqueadero,
                vestidores: vestidores,
                bar: bar,
                cubierta: cubierta,
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
        let photo: String
        let address: String
        let country: String
        let city: String
        let zipCode: String
        let parquedero: Bool
        let vestidores: Bool
        let bar: Bool
        let cubierta: Bool
        let canchas: [Cancha.Public]
        let userName: String
        let userRol: RolUsuario
        let phone: String
    }
    
    func toPublic() -> Establecimiento.Public {
        Establecimiento
            .Public(
                id: self.id!,
                name: self.name,
                info: self.info,
                photo: self.photo,
                address: self.address,
                country: self.country,
                city: self.city,
                zipCode: self.zipCode,
                parquedero: self.parqueadero,
                vestidores: self.vestidores,
                bar: self.bar,
                cubierta: self.cubierta,
                canchas: self.canchas.map({ cancha in
                    cancha.toPublic()
                }),
                userName: self.user.name,
                userRol: self.user.rol,
                phone: self.phone
            )
        
    }
}
