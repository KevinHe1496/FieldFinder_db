import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
     app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    guard let jwtKey = Environment.process.JWT_KEY else { fatalError("JWT_KEY not found")}

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

    //Set password
    app.passwords.use(.bcrypt)
    
    //Configure JWT
    let hmacKey = HMACKey(stringLiteral: jwtKey)
    await app.jwt.keys.add(hmac: hmacKey, digestAlgorithm: .sha512)
    
    app.routes.defaultMaxBodySize = "20mb"
    app.migrations.add(UserMigration())
    app.migrations.add(EstablecimientoMigration())
    app.migrations.add(EstablecimientoFotoMigration())
    app.migrations.add(CanchaMigration())
    app.migrations.add(CanchaFotoMigration())
    app.migrations.add(UserFavoriteMigration())

    if [.development, .testing].contains(app.environment) {
        try await app.autoMigrate()
    }

    // register routes
    try routes(app)
}
