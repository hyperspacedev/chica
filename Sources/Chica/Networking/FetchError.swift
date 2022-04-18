//
//  FetchError.swift
//  Chica
//
//  Created by Alex Modroño Vara on 18/7/21.
//
import Foundation

/// Represents an error that might be returned when doing a HTTP request.
///
/// Inspired in NetworkError by **Thomas Ricouard** in https://github.com/Dimillian/RedditOS
public enum FetchError: Error {

    case unknown(data: Data)
    case unknownError(error: Error)
    case serverError(statusCode: Int, data: Data)
    case clientError(statusCode: Int, data: Data)
    case message(reason: String, data: Data)
    case parseError(reason: Error)
    
    static private let decoder = JSONDecoder()
    
    static func processResponse(data: Data, response: URLResponse) throws -> Data {

        //  First, we try to convert the httpResponse to HTTPURLResponse
        //  if it fails, it means the http error is unknown, hence, we return it as .unknown
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.unknown(data: data)
        }

        //  Really straight-forward: if the error is 404, we already know what it means...
        if (httpResponse.statusCode == 404) {
            throw FetchError.message(reason: "Resource not found", data: data)
        }

        if 200 ... 299 ~= httpResponse.statusCode {

            return data

        } else {

            var error: FetchError

            defer {
                Chica.logger.error("An error ocurred: \(error)")
            }

            if 500 ... 599 ~= httpResponse.statusCode {
                error = FetchError.serverError(statusCode: httpResponse.statusCode, data: data)
            } else if 400 ... 499 ~= httpResponse.statusCode {
                error = FetchError.clientError(statusCode: httpResponse.statusCode, data: data)
            } else {
                error = FetchError.unknown(data: data)
            }

            throw error

        }
    }
}

extension FetchError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknownError(let error):
            return "An unknown error ocurred: \(error)."
        case .serverError(let statusCode, let data):
            return "A server-side error with code \(statusCode) ocurred: \(String(bytes: data, encoding: .utf8) ?? "")."
        case .clientError(let statusCode, let data):
            return "A client-side error with code \(statusCode) ocurred: \(String(bytes: data, encoding: .utf8) ?? "")."
        default:
            return "An error ocurred."
        }
    }
}
