//
//  AudioTranscriptionQuery.swift
//  
//
//  Created by Sergii Kryvoblotskyi on 02/04/2023.
//

import Foundation

public struct AudioTranscriptionQuery: Codable, Equatable {
    
    public enum ResponseFormat: String, Codable, Equatable, CaseIterable {
        case json
        case text
        case verboseJson = "verbose_json"
        case srt
        case vtt
    }
    
    public let file: Data
    public let fileType: Self.FileType
    public let fileName: String
    public let model: Model
    
    public let prompt: String?
    public let temperature: Double?
    public let language: String?
    public let responseFormat: Self.ResponseFormat?
    
    public init(file: Data, fileName: String, model: Model, prompt: String? = nil, temperature: Double? = nil, language: String? = nil) {
        self.file = file
        self.fileName = fileName
        self.model = model
        self.prompt = prompt
        self.temperature = temperature
        self.language = language
        self.fileType = .mp3
        self.responseFormat = .json

    }
    
    public init(file: Data, fileType: Self.FileType, model: Model, prompt: String? = nil, temperature: Double? = nil, language: String? = nil, responseFormat: Self.ResponseFormat? = nil) {
        self.file = file
        self.fileType = fileType
        self.model = model
        self.prompt = prompt
        self.temperature = temperature
        self.language = language
        self.fileName = fileType.fileName
        self.responseFormat = responseFormat
    }
    
    public enum FileType: String, Codable, Equatable, CaseIterable {
        case flac
        case mp3, mpga
        case mp4, m4a
        case mpeg
        case ogg
        case wav
        case webm
        
        var fileName: String { get {
            var fileName = "speech."
            switch self {
            case .mpga:
                fileName += Self.mp3.rawValue
            default:
                fileName += self.rawValue
            }
            
            return fileName
        }}
        
        var contentType: String { get {
            var contentType = "audio/"
            switch self {
            case .mpga:
                contentType += Self.mp3.rawValue
            default:
                contentType += self.rawValue
            }
            
            return contentType
        }}
    }
}

extension AudioTranscriptionQuery: MultipartFormDataBodyEncodable {
    
    func encode(boundary: String) -> Data {
        let bodyBuilder = MultipartFormDataBodyBuilder(boundary: boundary, entries: [
            .file(paramName: "file", fileName: fileName, fileData: file, contentType: "audio/mpeg"),
            .string(paramName: "model", value: model),
            .string(paramName: "prompt", value: prompt),
            .string(paramName: "temperature", value: temperature),
            .string(paramName: "language", value: language)
        ])
        return bodyBuilder.build()
    }
}
