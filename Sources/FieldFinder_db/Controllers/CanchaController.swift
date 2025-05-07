import Vapor
import Fluent

/// Controlador encargado de manejar las rutas relacionadas con canchas, como su creación.
struct CanchaController: RouteCollection {
    
    /// Registra las rutas bajo `/cancha` y asocia el endpoint de registro de cancha.
    func boot(routes: any RoutesBuilder) throws {
        routes.group("cancha") { builder in
            // Ruta POST /cancha/register para crear una nueva cancha
            builder.post("register", use: createCancha)
            builder.post(":canchaID", "fotos", use: uploadFotosCanchaHandler)

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
    
    @Sendable
    func uploadFotosCanchaHandler(req: Request) async throws -> HTTPStatus {
        
        // 1. Validar el token JWT del usuario autenticado
        let token = try req.auth.require(JWTToken.self)

        // 2. Obtener el UUID del usuario desde el token
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }

        // 3. Obtener el ID de la cancha desde los parámetros de la URL
        guard let canchaID = req.parameters.get("canchaID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID de la cancha inválido.")
        }
        
        // 4. Buscar la cancha por su ID
        guard let cancha = try await Cancha.find(canchaID, on: req.db) else {
            throw Abort(.notFound, reason: "Cancha no encontrada.")
        }

        // 5. Cargar el establecimiento al que pertenece la cancha
        try await cancha.$establecimiento.load(on: req.db)

        // 6. Verificar que el usuario autenticado sea dueño del establecimiento de esa cancha
        guard cancha.establecimiento.$user.id == userId else {
            throw Abort(.unauthorized, reason: "No puedes subir fotos a una cancha que no te pertenece.")
        }

        // 7. Estructura auxiliar para recibir múltiples archivos enviados como `multipart/form-data`
        struct FileUpload: Content {
            var files: [File] // clave en el form-data: files[]
        }

        // 8. Decodificar los archivos recibidos desde la petición HTTP
        let data = try req.content.decode(FileUpload.self)

        // 9. Iterar sobre los archivos recibidos
        for file in data.files {
            // 9.1 Guardar el archivo en S3  y obtener su URL pública
            let publicURL = try await req.uploadFileToS3(file: file, folder: "cancha") // 👈 sube a S3

            // 9.2 Crear una instancia de `CanchaFoto` asociada a la cancha
            let foto = CanchaFoto(url: publicURL, canchaID: canchaID)

            // 9.3 Guardar la foto en la base de datos
            try await foto.save(on: req.db)
        }

        // 10. Retornar HTTP 201 Created si todo salió bien
        return .created
    }

}
