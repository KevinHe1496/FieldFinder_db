import Vapor

//MARK: DTO específico para enviar la localización del consumidor desde el frontend a la BBDD para que filtre los restaurantes de su zona
struct LocationDTO: Content {
    let latitude: Double
    let longitude: Double
}

