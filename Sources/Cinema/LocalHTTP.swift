import Foundation

struct LocalRequest: Sendable {
    var method: String
    var path: String
    var headers: [String: String]
    var body: Data
}
enum LocalResponse: Sendable {
    case data(Data, mime: String = "application/json", status: String = "200 OK")
    case file(URL, mime: String = "video/x-matroska")
    static func json<T: Encodable>(_ value: T, status: String = "200 OK") -> LocalResponse {
        do { return .data(try JSONEncoder().encode(value), status: status) }
        catch { return .error("Não foi possível gerar a resposta.", status: "500 Internal Server Error") }
    }
    static func error(_ text: String, status: String = "400 Bad Request") -> LocalResponse { .json(["error": text], status: status) }
}
