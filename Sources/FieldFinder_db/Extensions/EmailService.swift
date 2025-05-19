//
//  EmailService.swift
//  FieldFinder_db
//
//  Created by Kevin Heredia on 18/5/25.
//

import Vapor

struct EmailService {
    static func sendRegistrationEmail(to email: String, name: String, on req: Request) async throws {
        let apiKey = Environment.get("SENDGRID_API_KEY") ?? ""
        let url = URI(string: "https://api.sendgrid.com/v3/mail/send")

        let payload: [String: Any] = [
            "personalizations": [[
                "to": [["email": email]],
                "subject": "¡Bienvenido a FieldFinder!"
            ]],
            "from": ["email": "kevin@ravecodesolutions.com"], // Usa tu correo verificado
            "content": [[
                "type": "text/plain",
                "value": "Hola \(name), gracias por registrarte en FieldFinder. Tu cuenta fue creada exitosamente."
            ]]
        ]

        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = try .init(data: JSONSerialization.data(withJSONObject: payload))

        let response = try await req.client.send(request)
        guard response.status == .accepted else {
            throw Abort(.internalServerError, reason: "Error al enviar el correo. Status: \(response.status)")
        }
    }
}
