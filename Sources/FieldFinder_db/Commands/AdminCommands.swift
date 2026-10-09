import Vapor
import Fluent

// Comandos de administración para correr en producción con:
//   fly ssh console -C "./FieldFinder_db <comando> --env production"
//
//   claims                         Solicitudes pendientes (con --todas: todas)
//   claim-aprobar <id>             Aprueba una solicitud
//   claim-rechazar <id>            Rechaza una solicitud
//   establecimientos               Lista establecimientos (--buscar, --sin-dueno, --manuales, --lejos)
//   establecimiento-borrar <ids>   Borra uno o varios (separados por coma). Sin --si solo muestra qué borraría.

// MARK: - claims

struct ListClaimsCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Flag(name: "todas", help: "Muestra también las aprobadas y rechazadas.")
        var all: Bool
    }

    var help: String { "Lista las solicitudes de reclamo (por defecto solo las pendientes)." }

    func run(using context: CommandContext, signature: Signature) async throws {
        let db = context.application.db
        let console = context.console

        var query = ClaimRequest.query(on: db)
            .with(\.$user)
            .with(\.$establecimiento)
            .sort(\.$createdAt, .ascending)
        if !signature.all {
            query = query.filter(\.$status == .pendiente)
        }
        let claims = try await query.all()

        guard !claims.isEmpty else {
            console.print(signature.all ? "No hay solicitudes." : "✅ No hay solicitudes pendientes.")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateFormatter.timeZone = TimeZone(identifier: "America/Guayaquil")

        console.print("\(claims.count) solicitud(es)\(signature.all ? "" : " pendiente(s)"):\n")
        for claim in claims {
            let fecha = claim.createdAt.map { dateFormatter.string(from: $0) } ?? "-"
            console.print("[\(claim.status.rawValue.uppercased())] \(fecha)")
            console.print("  ID solicitud:    \(claim.id?.uuidString ?? "-")")
            console.print("  Establecimiento: \(claim.establecimiento.name)")
            console.print("                   \(claim.establecimiento.address)")
            console.print("  Usuario:         \(claim.user.name) <\(claim.user.email)>")
            console.print("  Relación:        \(claim.relacionConEstablecimiento.rawValue)")
            console.print("  Teléfono:        \(claim.telefonoContacto)")
            console.print("  Cédula/RUC:      \(claim.documentoIdentidad)")
            if let redes = claim.redesSociales, !redes.isEmpty {
                console.print("  Redes:           \(redes)")
            }
            console.print("  Mensaje:         \(claim.mensaje)")
            console.print("")
        }

        if !signature.all {
            console.print("Para aprobar:  ./FieldFinder_db claim-aprobar <ID solicitud> --env production")
            console.print("Para rechazar: ./FieldFinder_db claim-rechazar <ID solicitud> --env production")
        }
    }

}

// MARK: - claim-aprobar / claim-rechazar

struct ApproveClaimCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "id", help: "ID de la solicitud (lo muestra el comando claims).")
        var id: String
    }

    var help: String { "Aprueba una solicitud: el usuario pasa a ser dueño del establecimiento." }

    func run(using context: CommandContext, signature: Signature) async throws {
        guard let claimID = UUID(uuidString: signature.id.trimmingCharacters(in: .whitespaces)) else {
            context.console.error("❌ ID inválido: \(signature.id)")
            return
        }
        do {
            let claim = try await ClaimReview.approve(claimID: claimID, on: context.application.db)
            context.console.print("✅ Aprobada. \(claim.user.name) <\(claim.user.email)> ahora es dueño de \"\(claim.establecimiento.name)\".")
            context.console.print("   Las demás solicitudes pendientes para ese establecimiento se rechazaron.")
        } catch let abort as Abort {
            context.console.error("❌ \(abort.reason)")
        }
    }
}

struct RejectClaimCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "id", help: "ID de la solicitud (lo muestra el comando claims).")
        var id: String
    }

    var help: String { "Rechaza una solicitud de reclamo." }

    func run(using context: CommandContext, signature: Signature) async throws {
        guard let claimID = UUID(uuidString: signature.id.trimmingCharacters(in: .whitespaces)) else {
            context.console.error("❌ ID inválido: \(signature.id)")
            return
        }
        do {
            let claim = try await ClaimReview.reject(claimID: claimID, on: context.application.db)
            context.console.print("✅ Rechazada la solicitud de \(claim.user.name) para \"\(claim.establecimiento.name)\".")
        } catch let abort as Abort {
            context.console.error("❌ \(abort.reason)")
        }
    }
}

// MARK: - establecimientos

struct ListEstablishmentsCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "buscar", short: "b", help: "Filtra por texto en el nombre (no distingue mayúsculas).")
        var search: String?

        @Flag(name: "sin-dueno", help: "Solo los que no tienen dueño.")
        var withoutOwner: Bool

        @Flag(name: "manuales", help: "Solo los creados a mano (no importados de Google).")
        var manualOnly: Bool

        @Flag(name: "lejos", help: "Solo los que están a más de 45 km de Quito.")
        var farOnly: Bool
    }

    var help: String { "Lista establecimientos con su ID, dueño, origen y distancia a Quito." }

    func run(using context: CommandContext, signature: Signature) async throws {
        let db = context.application.db
        let console = context.console

        var query = Establecimiento.query(on: db)
            .with(\.$user)
            .with(\.$canchas)
            .sort(\.$name, .ascending)
        if signature.withoutOwner {
            query = query.filter(\.$user.$id == nil)
        }
        if signature.manualOnly {
            query = query.filter(\.$googlePlaceId == nil)
        }

        var establishments = try await query.all()

        if let search = signature.search?.lowercased(), !search.isEmpty {
            establishments = establishments.filter { $0.name.lowercased().contains(search) }
        }
        if signature.farOnly {
            establishments = establishments.filter { Self.distanceToQuito($0) > SeedCanchasCommand.radioMaxKm }
        }

        guard !establishments.isEmpty else {
            console.print("No se encontraron establecimientos con esos filtros.")
            return
        }

        for est in establishments {
            let owner = est.user.map { "\($0.name) <\($0.email)>" } ?? "(sin dueño)"
            let origin = est.googlePlaceId == nil ? "manual" : "google"
            let km = Int(Self.distanceToQuito(est).rounded())
            console.print("\(est.id?.uuidString ?? "-")  \(est.name)")
            console.print("    dueño: \(owner) · origen: \(origin) · canchas: \(est.canchas.count) · a \(km) km de Quito")
        }
        console.print("\nTotal: \(establishments.count)")
    }

    static func distanceToQuito(_ est: Establecimiento) -> Double {
        haversineDistance(
            lat1: SeedCanchasCommand.quitoLat, lon1: SeedCanchasCommand.quitoLng,
            lat2: est.latitude, lon2: est.longitude
        )
    }
}

// MARK: - establecimiento-borrar

struct DeleteEstablishmentsCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "ids", help: "Uno o varios IDs separados por coma.")
        var ids: String

        @Flag(name: "si", help: "Confirma el borrado. Sin esta opción solo muestra lo que se borraría.")
        var confirm: Bool
    }

    var help: String {
        "Borra establecimientos junto con sus canchas, fotos, favoritos y solicitudes. Usa --si para confirmar."
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let db = context.application.db
        let console = context.console

        let rawIDs = signature.ids
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var ids: [UUID] = []
        for raw in rawIDs {
            guard let id = UUID(uuidString: raw) else {
                console.error("❌ ID inválido: \(raw). No se borró nada.")
                return
            }
            ids.append(id)
        }
        guard !ids.isEmpty else {
            console.error("❌ No se pasaron IDs.")
            return
        }

        let establishments = try await Establecimiento.query(on: db)
            .filter(\.$id ~~ ids)
            .with(\.$user)
            .with(\.$canchas)
            .all()

        let foundIDs = Set(establishments.compactMap(\.id))
        for missing in ids where !foundIDs.contains(missing) {
            console.warning("⚠️  No existe: \(missing.uuidString)")
        }
        guard !establishments.isEmpty else { return }

        console.print(signature.confirm ? "Borrando:" : "Se borrarían (agrega --si para confirmar):")
        for est in establishments {
            let owner = est.user.map { "dueño: \($0.name)" } ?? "sin dueño"
            console.print("  - \(est.name) (\(owner), \(est.canchas.count) cancha(s))")
        }

        guard signature.confirm else { return }

        // Las canchas, fotos, favoritos y solicitudes tienen ON DELETE CASCADE en la base de datos.
        try await db.transaction { tx in
            for est in establishments {
                try await est.delete(on: tx)
            }
        }
        console.print("✅ Borrados: \(establishments.count)")
    }
}
