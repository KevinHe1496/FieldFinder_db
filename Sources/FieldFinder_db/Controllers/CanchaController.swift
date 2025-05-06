import Vapor
import Fluent

/// Controlador encargado de manejar las rutas relacionadas con canchas, como su creación.
struct CanchaController: RouteCollection {
    
    /// Registra las rutas bajo `/cancha` y asocia el endpoint de registro de cancha.
    func boot(routes: any RoutesBuilder) throws {
        routes.group("cancha") { builder in
            // Ruta POST /cancha/register para crear una nueva cancha
            builder.post("register", use: createCancha)
        }
    }
}

extension CanchaController {
    
    /// Crea una nueva cancha asociada a un establecimiento del usuario autenticado, validando propiedad y guardando la cancha.
    @Sendable
    func createCancha(req: Request) async throws -> HTTPStatus {
        do {
            // 1. Verifica el token del usuario autenticado
            let token = try req.auth.require(JWTToken.self)
            guard let userID = UUID(token.userID.value) else {
                throw Abort(.unauthorized, reason: "Token inválido")
            }
            
            // 2. Decodifica el cuerpo de la solicitud con el contenido enviado
            let create = try req.content.decode(Cancha.Create.self)
            print("Input recibido:", create)
            
            // 3. Verifica que el establecimiento exista y pertenezca al usuario autenticado
            guard let _ = try await Establecimiento.query(on: req.db)
                .filter(\.$id == create.establecimientoId)
                .filter(\.$user.$id == userID)
                .first() else {
                throw Abort(.unauthorized, reason: "No puedes registrar canchas en un establecimiento que no te pertenece.")
            }

            // 4. Crea una nueva instancia del modelo Cancha a partir del DTO
            let cancha = create.toModel()

            // 5. Guarda la cancha en la base de datos
            try await cancha.save(on: req.db)

            // 6. Devuelve un código HTTP 201 (Created)
            return .created

        } catch {
            // En caso de error, muestra información útil en la consola
            print("Error al crear la cancha: \(error.localizedDescription)")
            print("Error reflejado: \(String(reflecting: error))")
            print("Error detallado: \(error)")
            throw Abort(.internalServerError, reason: "No se pudo crear el cancha.")
        }
    }
}
