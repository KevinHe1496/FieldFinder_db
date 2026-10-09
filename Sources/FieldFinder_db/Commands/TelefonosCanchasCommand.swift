import Vapor
import Fluent

/// Completa el teléfono de los establecimientos importados de Google que lo tienen vacío.
///
/// `seed-canchas` usa Text Search, que no devuelve teléfonos. Este comando pide a Google
/// Place Details solo el teléfono de cada `google_place_id`. Con el teléfono, la app muestra
/// "Llamar" y, si es celular (09…), el botón de WhatsApp.
///
/// Uso:
/// ```
/// swift run FieldFinder_db telefonos-canchas --dry-run    # muestra lo que guardaría
/// swift run FieldFinder_db telefonos-canchas              # guarda los teléfonos
/// swift run FieldFinder_db telefonos-canchas --limite 10  # prueba con pocos
/// ```
///
/// Solo toca establecimientos sin dueño y con teléfono vacío: nunca pisa lo que escribió un dueño.
/// Costo: una llamada a Place Details por establecimiento (campos de contacto).
struct TelefonosCanchasCommand: AsyncCommand {

    struct Signature: CommandSignature {
        @Flag(name: "dry-run", help: "No guarda nada; solo lista los teléfonos encontrados.")
        var dryRun: Bool

        @Option(name: "limite", help: "Máximo de establecimientos a consultar.")
        var limite: Int?
    }

    var help: String {
        "Trae de Google Places el teléfono de los establecimientos importados que no lo tienen."
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application
        let console = context.console

        guard let apiKey = Environment.get("GOOGLE_API_KEY") else {
            console.error("❌ Falta GOOGLE_API_KEY")
            return
        }

        var pendientes = try await Establecimiento.query(on: app.db)
            .filter(\.$googlePlaceId != nil)
            .filter(\.$user.$id == nil)
            .filter(\.$phone == "")
            .sort(\.$name)
            .all()
        if let limite = signature.limite, limite > 0 {
            pendientes = Array(pendientes.prefix(limite))
        }

        console.print("📞 \(pendientes.count) establecimiento(s) sin teléfono\(signature.dryRun ? " [DRY RUN]" : "")")

        var conCelular = 0
        var conFijo = 0
        var sinTelefono = 0
        var errores = 0

        for establecimiento in pendientes {
            guard let placeID = establecimiento.googlePlaceId,
                  let encoded = placeID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }

            let url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=\(encoded)&fields=formatted_phone_number,international_phone_number&language=es&key=\(apiKey)"

            let respuesta: GooglePlaceDetailsResponse
            do {
                respuesta = try await app.client.get(URI(string: url)).content.decode(GooglePlaceDetailsResponse.self)
            } catch {
                errores += 1
                console.error("   ❌ \(establecimiento.name): \(error)")
                continue
            }

            guard respuesta.status == "OK" else {
                errores += 1
                console.error("   ❌ \(establecimiento.name): Google respondió \(respuesta.status)\(respuesta.error_message.map { " — \($0)" } ?? "")")
                if respuesta.status == "REQUEST_DENIED" || respuesta.status == "OVER_QUERY_LIMIT" { break }
                continue
            }

            guard let telefono = Self.mejorTelefono(respuesta.result) else {
                sinTelefono += 1
                console.print("   · \(establecimiento.name): Google no tiene teléfono")
                continue
            }

            let esCelular = Self.esCelularEcuador(telefono)
            if esCelular { conCelular += 1 } else { conFijo += 1 }
            console.print("   + \(establecimiento.name): \(telefono)\(esCelular ? " (celular, WhatsApp)" : " (fijo)")")

            if !signature.dryRun {
                establecimiento.phone = telefono
                try await establecimiento.save(on: app.db)
            }

            // Pausa corta para no saturar la API.
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let verbo = signature.dryRun ? "se guardarían" : "guardados"
        console.print("\n🎉 Listo: \(conCelular + conFijo) teléfono(s) \(verbo) — \(conCelular) celular(es) con WhatsApp, \(conFijo) fijo(s). \(sinTelefono) sin teléfono en Google, \(errores) error(es).")
    }

    /// Prefiere el formato local ("099 123 4567"); si no hay, el internacional.
    static func mejorTelefono(_ result: GooglePlaceDetails?) -> String? {
        let candidatos = [result?.formatted_phone_number, result?.international_phone_number]
        return candidatos
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    /// Celular de Ecuador: 09XXXXXXXX o +593 9XXXXXXXX (10 o 12 dígitos).
    static func esCelularEcuador(_ telefono: String) -> Bool {
        let digitos = telefono.filter(\.isNumber)
        return (digitos.hasPrefix("09") && digitos.count == 10)
            || (digitos.hasPrefix("5939") && digitos.count == 12)
    }
}

struct GooglePlaceDetailsResponse: Content {
    let status: String
    let result: GooglePlaceDetails?
    let error_message: String?
}

struct GooglePlaceDetails: Content {
    let formatted_phone_number: String?
    let international_phone_number: String?
}
