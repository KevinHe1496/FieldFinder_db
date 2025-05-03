import Vapor
import Fluent

struct CanchaController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.group("cancha") { builder in
            builder.post("register", use: createCancha)
        }
    }
}

extension CanchaController {
    @Sendable
    func createCancha(req: Request) async throws -> HTTPStatus {
        do {
            let create = try req.content.decode(Cancha.Create.self)
            print("Input recibido:", create)
            guard let _ = try await Establecimiento.find(create.establecimiento, on: req.db) else {
                throw Abort(.badRequest, reason: "El establecimiento con ese ID no existe.")
            }

            let cancha = create.toModel()
            
            try await cancha.save(on: req.db)
            
            return .created
        } catch {
            // Si ocurre un error, lo capturamos y lo mostramos
            print("Error al crear la cancha: \(error.localizedDescription)")
            print("Error reflejado: \(String(reflecting: error))")
            print("Error detallado: \(error)")
            throw Abort(.internalServerError, reason: "No se pudo crear el cancha.")
        }
    }
}
