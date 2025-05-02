import Vapor

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.group("auth") { builder in
            builder.post("register", use: register)
            
            builder.group(User.authenticator(), User.guardMiddleware()) { builder in
                builder.post("login", use: login)
            }
            
            builder.group(JWTToken.authenticator(), JWTToken.guardMiddleware()) { builder in
                builder.post("refresh", use: refresh)
            }
        }
    }
}

extension AuthController {
    @Sendable
    func register(req: Request) async throws -> JWTToken.Public {
        // validamos los campos ingresados del usuario
        try User.Create.validate(content: req)
        // mandamos como json
        let create = try req.content.decode(User.Create.self)
        // contraseña hashed
        let hashedPassword = try await req.password.async.hash(create.password)
        // creamos el usuario
        let user = create.toModel(withHashedPassword: hashedPassword)
        // creamos en la base de datos
        try await user.create(on: req.db)
        // generamos los tokens
        return try await generateTokens(
            for: user.email,
            andId: user.requireID(),
            withRequest: req
        )
    }
    
    @Sendable
    func refresh(req: Request) async throws -> JWTToken.Public {
        let token = try req.auth.require(JWTToken.self)
        
        guard token.isRefresh.value else {
            throw Abort(.methodNotAllowed, reason: "Token must be refresh type.")
        }
        return try await generateTokens(
            for: token.username.value,
            andId: UUID(token.userID.value)!,
            withRequest: req
        )
    }
    
    @Sendable
    func login(req: Request) async throws -> JWTToken.Public {
        
        let user = try req.auth.require(User.self)
        
        return try await generateTokens(
            for: user.name,
            andId: user.requireID(),
            withRequest: req
        )
    }
    
    @Sendable
    private func generateTokens(
        for username: String,
        andId userId: UUID,
        withRequest req: Request
    ) async throws -> JWTToken.Public {
        let tokens = JWTToken.generateTokens(for: username, andId: userId)
        async let accessTokenSigned = req.jwt.sign(tokens.accessToken)
        async let refreshTokenSigned = req.jwt.sign(tokens.refreshToken)
        return try await JWTToken.Public(accessToken: accessTokenSigned, refreshToken: refreshTokenSigned)
    }
}
