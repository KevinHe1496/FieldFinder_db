import Vapor

/// Controlador encargado de gestionar la autenticación de usuarios, incluyendo registro, login y renovación de tokens JWT.
struct AuthController: RouteCollection {
    
    /// Define las rutas relacionadas con la autenticación y las agrupa bajo `/auth`.
    func boot(routes: any RoutesBuilder) throws {
        routes.group("auth") { builder in
            // Ruta para registrar un nuevo usuario
            builder.post("register", use: register)
            
            // Rutas protegidas por autenticación básica (email y contraseña)
            builder.group(User.authenticator(), User.guardMiddleware()) { builder in
                builder.post("login", use: login)
            }
            
            // Rutas protegidas por autenticación JWT (usando token)
            builder.group(JWTToken.authenticator(), JWTToken.guardMiddleware()) { builder in
                builder.post("refresh", use: refresh)
            }
        }
    }
}

extension AuthController {
    
    /// Registra un nuevo usuario, encripta su contraseña, guarda en la base de datos y devuelve los tokens de acceso y refresco.
    @Sendable
    func register(req: Request) async throws -> JWTToken.Public {
        // Validamos los datos recibidos según el modelo User.Create
        try User.Create.validate(content: req)
        
        // Decodificamos el JSON recibido
        let create = try req.content.decode(User.Create.self)
        
        // Encriptamos la contraseña antes de guardarla
        let hashedPassword = try await req.password.async.hash(create.password)
        
        // Creamos el modelo de usuario listo para guardar
        let user = create.toModel(withHashedPassword: hashedPassword)
        
        // Guardamos el usuario en la base de datos
        try await user.create(on: req.db)
        
        // Generamos y devolvemos los tokens JWT
        return try await generateTokens(
            for: user.email,
            andId: user.requireID(),
            withRequest: req
        )
    }
    
    /// Renueva los tokens JWT usando un token de tipo "refresh".
    @Sendable
    func refresh(req: Request) async throws -> JWTToken.Public {
        // Extraemos el token del request
        let token = try req.auth.require(JWTToken.self)
        
        // Validamos que sea un token de refresco
        guard token.isRefresh.value else {
            throw Abort(.methodNotAllowed, reason: "Token must be refresh type.")
        }
        
        // Generamos nuevos tokens con los datos del token actual
        return try await generateTokens(
            for: token.username.value,
            andId: UUID(token.userID.value)!,
            withRequest: req
        )
    }
    
    /// Inicia sesión con email y contraseña válidos, y genera tokens JWT.
    @Sendable
    func login(req: Request) async throws -> JWTToken.Public {
        // Autentica al usuario (ya hecho por el middleware)
        let user = try req.auth.require(User.self)
        
        // Genera y devuelve los tokens JWT
        return try await generateTokens(
            for: user.name,
            andId: user.requireID(),
            withRequest: req
        )
    }
    
    /// Función auxiliar privada que genera tokens JWT firmados (access y refresh).
    @Sendable
    private func generateTokens(
        for username: String,
        andId userId: UUID,
        withRequest req: Request
    ) async throws -> JWTToken.Public {
        // Generamos los tokens sin firmar
        let tokens = JWTToken.generateTokens(for: username, andId: userId)
        
        // Los firmamos de forma asíncrona
        async let accessTokenSigned = req.jwt.sign(tokens.accessToken)
        async let refreshTokenSigned = req.jwt.sign(tokens.refreshToken)
        
        // Devolvemos ambos tokens firmados en su versión pública
        return try await JWTToken.Public(
            accessToken: accessTokenSigned,
            refreshToken: refreshTokenSigned
        )
    }
}
