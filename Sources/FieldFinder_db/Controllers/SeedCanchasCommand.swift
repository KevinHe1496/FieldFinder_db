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

        // 1. Traer la llave de Google desde el archivo .env
        guard let apiKey = Environment.get("GOOGLE_API_KEY") else {
            context.console.error("❌ Faltó poner GOOGLE_API_KEY en tu archivo .env")
            return
        }

        // 2. Configurar la búsqueda de Google (ajusta la ciudad según necesites)
        let searchQuery = "canchas de futbol sinteticas y estadios en Quito, Ecuador"
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

        let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(encodedQuery)&key=\(apiKey)"

        // 3. Hacer la petición a Google
        context.console.print("🌍 Consultando Google Places API...")
        let response = try await app.client.get(URI(string: urlString))

        // 4. Decodificar la respuesta
        let googleData = try response.content.decode(GooglePlacesResponse.self)

        guard googleData.status == "OK" else {
            context.console.error("❌ Error de Google o sin resultados: \(googleData.status)")
            return
        }

        context.console.print("✅ Se encontraron \(googleData.results.count) lugares en Google.")

        // 5. Guardar en la base de datos sin asignar dueño (user_id = nil)
        // El dueño real de cada establecimiento deberá reclamarlo después desde la app.
        var creados = 0
        for place in googleData.results {

            // Saltar lugares no operativos
            if place.business_status != "OPERATIONAL" && place.business_status != nil { continue }

            // Crear el Establecimiento sin dueño
            let establecimiento = Establecimiento(
                name: place.name,
                info: "Calificación Google: \(place.rating ?? 0.0) ⭐️",
                address: place.formatted_address ?? "Dirección no registrada",
                address2: nil,
                parqueadero: true,
                vestidores: false,
                bar: false,
                banos: true,
                duchas: false,
                latitude: place.geometry.location.lat,
                longitude: place.geometry.location.lng,
                phone: "Por actualizar"
            )
            try await establecimiento.save(on: db)

            // Crear una cancha por defecto asociada al establecimiento
            let cancha = Cancha(
                tipo: .cesped,
                modalidad: "11v11",
                precio: 0.0,
                iluminada: true,
                cubierta: false,
                establecimientoId: establecimiento.id!
            )
            try await cancha.save(on: db)

            creados += 1
        }

        context.console.print("🎉 ¡Seeding completado! Se insertaron \(creados) establecimientos listos para ser reclamados.")
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
