//
//  AudioSpeechQuery.swift
//  
//
//  Created by Daniel Nguyen on 11/9/23.
//

import Foundation

public struct AudioSpeechQuery: Codable, Equatable {
    
    public let model: Model
    public let input: String
    public let voice: String
    public let responseFormat: String?
    public let speed: Double?
    
    private enum CodingKeys: String, CodingKey {
        case model
        case input
        case voice
        case responseFormat = "response_format"
        case speed
    }
    
    public init(model: Model, input: String, voice: String, responseFormat: String?, speed: Double?) {
        self.model = model
        self.input = input
        self.voice = voice
        self.responseFormat = responseFormat
        self.speed = speed
    }
}

extension AudioSpeechQuery: MultipartFormDataBodyEncodable {
    
    func encode(boundary: String) -> Data {
        let bodyBuilder = MultipartFormDataBodyBuilder(boundary: boundary, entries: [
            .string(paramName: "model", value: model),
            .string(paramName: "input", value: input),
            .string(paramName: "voice", value: voice),
            .string(paramName: "response_format", value: responseFormat),
            .string(paramName: "speed", value: speed)
        ])
        return bodyBuilder.build()
    }
}
