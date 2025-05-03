import Vapor
import Fluent

final class Establecimiento: Model, @unchecked Sendable {

    static let schema: String = "establecimientos"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "info")
    var info: String
    
    @Field(key: "photo")
    var photo: String
    
    @Field(key: "address")
    var address: String
    
    @Field(key: "country")
    var country: String

    @Field(key: "city")
    var city: String

    @Field(key: "zip_code")
    var zipCode: String
    
    @Field(key: "parqueadero")
    var parqueadero: Bool
    
    @Field(key: "vestidores")
    var vestidores: Bool
    
    @Field(key: "bar")
    var bar: Bool
    
    @Field(key: "cubierta")
    var cubierta: Bool
    
    @Field(key: "latitude")
    var latitude: Double

    @Field(key: "longitude")
    var longitude: Double
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Parent(key: "user_id")
    var user: User
    
    @Children(for: \.$establecimiento)
    var canchas: [Cancha]
    
    init() { }
    
    init(
        id: UUID? = nil,
        name: String,
        info: String,
        photo: String,
        address: String,
        country: String,
        city: String,
        zipCode: String,
        parqueadero: Bool,
        vestidores: Bool,
        bar: Bool,
        cubierta: Bool,
        latitude: Double,
        longitude: Double,
        userId: User.IDValue
    ) {
        self.id = id
        self.name = name
        self.info = info
        self.photo = photo
        self.address = address
        self.country = country
        self.city = city
        self.zipCode = zipCode
        self.parqueadero = parqueadero
        self.vestidores = vestidores
        self.bar = bar
        self.cubierta = cubierta
        self.latitude = latitude
        self.longitude = longitude
        self.$user.id = userId
    }

}
