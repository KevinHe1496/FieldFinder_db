import Vapor
import Fluent

/// Comando para importar establecimientos de fútbol desde Google Places a la base de datos.
///
/// Uso:
/// ```
/// swift run FieldFinder_db seed-canchas --dry-run          # solo muestra lo que encontraría
/// swift run FieldFinder_db seed-canchas                    # importa todas las zonas por defecto
/// swift run FieldFinder_db seed-canchas -q "canchas sinteticas Cumbaya"   # una búsqueda puntual
/// ```
///
/// Reglas:
/// - Cada búsqueda trae hasta 3 páginas (máx. 60 resultados por búsqueda, límite de Google).
/// - Se guarda el `place_id` de Google, así que correrlo varias veces no crea duplicados.
/// - Los datos que Google no da (servicios, teléfono, canchas, precio) se dejan vacíos/en false
///   en lugar de inventarlos. El dueño los completa al reclamar el establecimiento.
/// - No se crea ninguna cancha por defecto: un establecimiento importado aparece sin canchas
///   hasta que alguien las registre con datos reales.
struct SeedCanchasCommand: AsyncCommand {

    struct Signature: CommandSignature {
        @Option(name: "query", short: "q", help: "Búsqueda puntual. Si no se pasa, se usan las zonas por defecto de Quito y sus valles.")
        var query: String?

        @Option(name: "max-pages", help: "Páginas por búsqueda (1 a 3). Por defecto 3.")
        var maxPages: Int?

        @Flag(name: "dry-run", help: "No guarda nada; solo lista lo que se importaría.")
        var dryRun: Bool
    }

    var help: String {
        "Importa establecimientos de fútbol desde Google Places sin duplicar y sin inventar datos."
    }

    /// Zonas por defecto. Google limita cada búsqueda a 60 resultados, por eso se divide la ciudad.
    static let defaultQueries: [String] = [
        "canchas de futbol Quito norte",
        "canchas de futbol Quito centro",
        "canchas de futbol Quito sur",
        "canchas sinteticas Quito",
        "canchas de futbol Calderon Carapungo",
        "canchas de futbol Pomasqui San Antonio de Pichincha",
        "canchas de futbol Cumbaya Tumbaco",
        "canchas de futbol Sangolqui",
        "canchas de futbol Conocoto",
        "canchas de futbol San Rafael Capelo",
    ]

    func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application
        let db = app.db
        let console = context.console

        guard let apiKey = Environment.get("GOOGLE_API_KEY") else {
            console.error("❌ Falta GOOGLE_API_KEY en el archivo .env")
            return
        }

        let queries = signature.query.map { [$0] } ?? Self.defaultQueries
        let maxPages = min(max(signature.maxPages ?? 3, 1), 3)

        // place_id que ya existen en la base, para no duplicar.
        let existentes = try await Establecimiento.query(on: db)
            .filter(\.$googlePlaceId != nil)
            .all()
            .compactMap { $0.googlePlaceId }
        var vistos = Set(existentes)

        console.print("⚽ Seeding con Google Places — \(queries.count) búsqueda(s), \(maxPages) página(s) c/u\(signature.dryRun ? " [DRY RUN]" : "")")
        console.print("   Ya hay \(existentes.count) establecimiento(s) importados en la base.")

        var creados = 0
        var duplicados = 0
        var noOperativos = 0

        for query in queries {
            console.print("\n🔎 \(query)")
            let places = try await fetchAllPages(query: query, apiKey: apiKey, maxPages: maxPages, app: app, console: console)

            for place in places {
                if let status = place.business_status, status != "OPERATIONAL" {
                    noOperativos += 1
                    continue
                }
                guard !vistos.contains(place.place_id) else {
                    duplicados += 1
                    continue
                }
                vistos.insert(place.place_id)

                console.print("   + \(place.name) — \(place.formatted_address ?? "sin dirección")")

                guard !signature.dryRun else {
                    creados += 1
                    continue
                }

                let establecimiento = Establecimiento(
                    name: place.name,
                    info: "",
                    address: place.formatted_address ?? "",
                    address2: nil,
                    parqueadero: false,
                    vestidores: false,
                    bar: false,
                    banos: false,
                    duchas: false,
                    latitude: place.geometry.location.lat,
                    longitude: place.geometry.location.lng,
                    phone: "",
                    userId: nil,
                    googlePlaceId: place.place_id
                )
                try await establecimiento.save(on: db)
                creados += 1
            }
        }

        let verbo = signature.dryRun ? "se importarían" : "se insertaron"
        console.print("\n🎉 Listo: \(creados) \(verbo), \(duplicados) duplicado(s) omitido(s), \(noOperativos) no operativo(s) omitido(s).")
        if !signature.dryRun && creados > 0 {
            console.print("   Revisa la lista: Google a veces devuelve tiendas deportivas o escuelas que no son canchas.")
        }
    }

    /// Trae hasta `maxPages` páginas de una búsqueda de Google Places Text Search.
    private func fetchAllPages(
        query: String,
        apiKey: String,
        maxPages: Int,
        app: Application,
        console: any Console
    ) async throws -> [GooglePlace] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let baseURL = "https://maps.googleapis.com/maps/api/place/textsearch/json"

        var results: [GooglePlace] = []
        var url = "\(baseURL)?query=\(encodedQuery)&region=ec&language=es&key=\(apiKey)"

        for page in 1...maxPages {
            var data = try await app.client.get(URI(string: url)).content.decode(GooglePlacesResponse.self)

            // El next_page_token tarda unos segundos en activarse; si aún no está listo, Google
            // responde INVALID_REQUEST. Esperamos y reintentamos una vez.
            if page > 1 && data.status == "INVALID_REQUEST" {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                data = try await app.client.get(URI(string: url)).content.decode(GooglePlacesResponse.self)
            }

            switch data.status {
            case "OK":
                results.append(contentsOf: data.results)
                console.print("   página \(page): \(data.results.count) resultado(s)")
            case "ZERO_RESULTS":
                return results
            default:
                console.error("   ❌ Google respondió \(data.status)\(data.error_message.map { ": \($0)" } ?? "")")
                return results
            }

            guard let token = data.next_page_token, page < maxPages else { break }
            url = "\(baseURL)?pagetoken=\(token)&key=\(apiKey)"
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return results
    }
}

// MARK: - Estructuras de Google Places API
struct GooglePlacesResponse: Content {
    let results: [GooglePlace]
    let status: String
    let next_page_token: String?
    let error_message: String?
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
