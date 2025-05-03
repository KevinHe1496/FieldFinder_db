import Vapor
import Fluent

struct EstablecimientoController: RouteCollection {
    
    func boot(routes: any RoutesBuilder) throws {
        routes.group("establecimiento") { builder in
            builder.grouped(RoleMiddleware(requiredRole: .dueno)).post("register",use: crearEstablecimiento)
            builder.grouped(AdminMiddleware()).get("getEstablecimientos", use: getAllEstablisments)
        }
    }
}

extension EstablecimientoController {
    
    @Sendable
    func crearEstablecimiento(req: Request) async throws -> HTTPStatus {
        do {
            // Decodificamos el cuerpo de la solicitud como `Establecimiento.Create`
            let create = try req.content.decode(Establecimiento.Create.self)
            print("Input recibido:", create)
            // Creamos un nuevo establecimiento usando los datos decodificados
            let establecimiento = create.toModel()
            
            // Guardamos el nuevo establecimiento en la base de datos
            try await establecimiento.save(on: req.db)
            
            // Retornamos un status 201 (creado)
            return .created
        } catch {
            // Si ocurre un error, lo capturamos y lo mostramos
            print("Error al crear el establecimiento: \(error.localizedDescription)")
            throw Abort(.internalServerError, reason: "No se pudo crear el establecimiento.")
        }
    }

    @Sendable
    // Esta función obtiene todos los establecimientos de la base de datos, junto con sus canchas relacionadas.
    func getAllEstablisments(req: Request) async throws -> [Establecimiento.Public] {
        
        // Realiza una consulta a la base de datos para obtener todos los establecimientos,
        // con las relacion de las canchas
        let establecimientos = try await Establecimiento.query(on: req.db)
            .with(\.$canchas) // Carga también las canchas asociadas a cada establecimiento.
            .all()            // Ejecuta la consulta y devuelve todos los resultados.

        // Transforma cada establecimiento en su versión pública usando el método toPublic().
        // Esto sirve para devolver solo la información necesaria y segura para el cliente.
        return establecimientos.map { establecimiento in
            establecimiento.toPublic()
        }
    }

}
