import Vapor
import AWSS3
import AWSClientRuntime
import AWSSDKIdentity

extension Request {
    
    /// Sube un archivo a Amazon S3 y retorna la URL pública del archivo subido.
    /// - Parameters:
    ///   - file: El archivo recibido (ej. imagen) desde una petición multipart/form-data.
    ///   - bucket: Nombre del bucket de S3 (por defecto: "fieldfinder-uploads").
    ///   - folder: Carpeta interna del bucket donde se guardará el archivo.
    /// - Returns: La URL pública del archivo que fue subido.
    func uploadFileToS3(file: File, bucket: String = "fieldfinder-uploads", folder: String) async throws -> String {
        
        // 1. Se genera un nombre único usando UUID y se mantiene el nombre original del archivo.
        let filename = "\(UUID().uuidString)-\(file.filename)"
        
        // 2. Se define la "ruta" o clave completa del archivo dentro del bucket de S3.
        let key = "\(folder)/\(filename)"

        // 3. Se convierte el archivo recibido (tipo ByteBuffer) a tipo Data.
        var buffer = file.data
        guard let data = buffer.readData(length: buffer.readableBytes) else {
            throw Abort(.internalServerError, reason: "No se pudo leer el archivo.")
        }

        // 4. Se obtienen las credenciales desde las variables de entorno.
        guard
            let accessKey = Environment.get("AWS_ACCESS_KEY"),
            let secretKey = Environment.get("AWS_SECRET_KEY")
        else {
            throw Abort(.internalServerError, reason: "Faltan las credenciales de AWS.")
        }

        // 5. Se crean las credenciales de AWS usando los valores del .env
        let credentials = AWSCredentialIdentity(
            accessKey: accessKey,
            secret: secretKey
        )

        // 6. Se configura un resolvedor de identidad estática para autenticación con AWS.
        let identityResolver = try StaticAWSCredentialIdentityResolver(credentials)

        // 7. Se configura el cliente de AWS S3 con la región y las credenciales.
        let config = try await S3Client.S3ClientConfiguration(
            awsCredentialIdentityResolver: identityResolver,
            region: "us-east-2" // Región donde está tu bucket (Ohio)
        )

        // 8. Se crea una instancia del cliente de S3 con la configuración anterior.
        let s3Client = S3Client(config: config)

        // 9. Se define la solicitud para subir el archivo con acceso público.
        let input = PutObjectInput(
            body: .data(data), // El contenido del archivo.
            bucket: bucket,    // El bucket destino en S3.
            contentType: file.contentType?.description ?? "image/jpeg", // Tipo MIME del archivo.
            key: key           // Ruta o nombre del archivo dentro del bucket.
        )

        // 10. Se ejecuta la subida a S3.
        _ = try await s3Client.putObject(input: input)

        // 11. Se construye y devuelve la URL pública del archivo subido.
        return "https://\(bucket).s3.us-east-2.amazonaws.com/\(key)"
    }
}
