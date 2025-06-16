import NIOSSL
import Fluent
import FluentPostgresDriver
import QueuesRedisDriver
import Vapor
import JWT

public func configure(_ app: Application) async throws {
    // Middleware para archivos públicos
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Clave JWT
    guard let jwtKey = Environment.process.JWT_KEY else {
        fatalError("JWT_KEY not set")
    }

    // Configuración de Redis solo en desarrollo
    if app.environment == .development {
        try app.queues.use(.redis(url: "redis://localhost:6379"))
        app.queues.add(EmailJob())
        try app.queues.startInProcessJobs(on: .email)
    }

    // Configuración moderna de TLS
    var tlsConfig = TLSConfiguration.makeClientConfiguration()
    tlsConfig.certificateVerification = .none
    let nioTLS = try NIOSSLContext(configuration: tlsConfig)

    // Configuración moderna de la base de datos
    let dbConfig = SQLPostgresConfiguration(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5432,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .disable
    )
    
    app.databases.use(.postgres(configuration: dbConfig), as: .psql)

    // Seguridad
    app.passwords.use(.bcrypt)
    await app.jwt.keys.add(hmac: .init(stringLiteral: jwtKey), digestAlgorithm: .sha512)

    // Tamaño máximo de body
    app.routes.defaultMaxBodySize = "20mb"

    // Migraciones
    app.migrations.add(UserMigration())
    app.migrations.add(EstablecimientoMigration())
    app.migrations.add(EstablecimientoFotoMigration())
    app.migrations.add(CanchaMigration())
    app.migrations.add(CanchaFotoMigration())
    app.migrations.add(UserFavoriteMigration())
    
    if let port = Environment.get("PORT").flatMap(Int.init) {
        app.http.server.configuration.port = port
        app.http.server.configuration.hostname = "0.0.0.0"
    }

    // Ejecutar migraciones
    try await app.autoMigrate()

    // Rutas
    try routes(app)
}
