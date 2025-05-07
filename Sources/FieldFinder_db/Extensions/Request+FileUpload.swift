import Vapor

extension Request {
    /// Guarda un archivo `File` en la carpeta pública especificada y retorna la URL pública relativa.
    func saveUploadedFile(_ file: File, in folder: String = "uploads") async throws -> String {
        let saveFolder = self.application.directory.publicDirectory + folder + "/"
        try FileManager.default.createDirectory(atPath: saveFolder, withIntermediateDirectories: true)

        let filename = "\(UUID().uuidString)-\(file.filename)"
        let path = saveFolder + filename
        try await self.fileio.writeFile(file.data, at: path)

        return "/\(folder)/\(filename)"
    }
}

