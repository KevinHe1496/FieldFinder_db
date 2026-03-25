import Vapor
import Fluent

/// Comando para importar canchas desde Google Places a la base de datos.
struct SeedCanchasCommand: AsyncCommand {
    
    struct Signature: CommandSignature { }
    
    var help: String {
        "Descarga canchas de fútbol desde Google Places y las guarda en la base de datos."
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application
        let db = app.db
        
        context.console.print("⚽ Iniciando el seeding con Google Places...")
        
        // 1. Verificar el Usuario del Sistema
        let adminEmail = "admin@fieldfinder.com"
        var systemUser = try await User.query(on: db).filter(\.$email == adminEmail).first()
        
        if systemUser == nil {
            let hashedPassword = try Bcrypt.hash("AdminSeguro123!")
            systemUser = User(
                name: "Field Finder Admin",
                email: adminEmail,
                password: hashedPassword,
                rol: .dueno,
                isAdmin: true
            )
            try await systemUser!.save(on: db)
        }
        
        guard let userId = systemUser?.id else {
            context.console.error("No se pudo obtener el ID del usuario.")
            return
        }
        
        // 2. Traer la llave de Google desde el archivo .env
        guard let apiKey = Environment.get("GOOGLE_API_KEY") else {
            context.console.error("❌ Faltó poner GOOGLE_API_KEY en tu archivo .env")
            return
        }
        
        // 3. Configurar la búsqueda de Google
        // Pon el nombre de tu ciudad y país real.
        let searchQuery = "canchas de futbol sinteticas y estadios en Quito, Ecuador"
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        
        let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(encodedQuery)&key=\(apiKey)"
        
        // 4. Hacer la petición a Google
        context.console.print("🌍 Consultando Google Places API...")
        let response = try await app.client.get(URI(string: urlString))
        
        // 5. Decodificar la respuesta
        let googleData = try response.content.decode(GooglePlacesResponse.self)
        
        guard googleData.status == "OK" else {
            context.console.error("❌ Error de Google o sin resultados: \(googleData.status)")
            return
        }
        
        context.console.print("✅ Se encontraron \(googleData.results.count) lugares en Google.")
        
        // 6. Guardar en tu base de datos
        var creados = 0
        for place in googleData.results {
            
            // Si el lugar no está en funcionamiento, lo saltamos (opcional)
            if place.business_status != "OPERATIONAL" && place.business_status != nil { continue }
            
            let name = place.name
            let address = place.formatted_address ?? "Dirección no registrada"
            let lat = place.geometry.location.lat
            let lon = place.geometry.location.lng
            
            // Crear el Establecimiento
            let establecimiento = Establecimiento(
                name: name,
                info: "Calificación Google: \(place.rating ?? 0.0) ⭐️",
                address: address,
                address2: nil,
                parqueadero: true,
                vestidores: false,
                bar: false,
                banos: true,
                duchas: false,
                latitude: lat,
                longitude: lon,
                phone: "Actualizar luego", // Google Text Search no da teléfonos directamente
                userId: userId
            )
            
            try await establecimiento.save(on: db)
            
            // Crear la Cancha asociada
            let cancha = Cancha(
                tipo: .cesped, // Ajusta a tu enum real
                modalidad: "11v11",
                precio: 0.0,
                iluminada: true,
                cubierta: false,
                establecimientoId: establecimiento.id!
            )
            
            try await cancha.save(on: db)
            creados += 1
        }
        
        context.console.print("🎉 ¡Seeding completado! Se insertaron \(creados) establecimientos con datos de Google.")
    }
}

// MARK: - Estructuras de Google Places API
struct GooglePlacesResponse: Content {
    let results: [GooglePlace]
    let status: String
}

struct GooglePlace: Content {
    let place_id: String
    let name: String
    let formatted_address: String?
    let geometry: GoogleGeometry
    let rating: Double?
    let business_status: String?
}

struct GoogleGeometry: Content {
    let location: GoogleLocation
}

struct GoogleLocation: Content {
    let lat: Double
    let lng: Double
}
