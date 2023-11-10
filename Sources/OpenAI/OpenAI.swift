//
//  OpenAI.swift
//
//
//  Created by Sergii Kryvoblotskyi on 9/18/22.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class OpenAI: OpenAIProtocol {
    public struct Configuration {
        /// OpenAI API token. See https://platform.openai.com/docs/api-reference/authentication
        public let token: String
        
        /// Optional OpenAI organization identifier. See https://platform.openai.com/docs/api-reference/authentication
        public let organizationIdentifier: String?
        
        /// Optional Custom Headers to be sent with the request
        public let customHeaders: [String: String]
        
        /// Optional API Base URL, default https://api.openai.com
        public let baseURL: URL
        
        /// Optional Default request timeout
        public let timeoutInterval: TimeInterval
        
        /// Optional API Path configuration
        public let apiPath: APIPathConfiguration
        
        public init(token: String, organizationIdentifier: String? = nil, host: String = "api.openai.com", timeoutInterval: TimeInterval = 60.0) {
            self.token = token
            self.organizationIdentifier = organizationIdentifier
            self.timeoutInterval = timeoutInterval
            self.customHeaders = [:]
            self.apiPath = APIPathConfiguration()
            if let url = URL(string: "https://" + host) {
                self.baseURL = url
            } else {
                self.baseURL = URL(string: "https://api.openai.com")!
            }
        }
        
        public init(token: String, baseURL: URL = URL(string: "https://api.openai.com")!, apiPath: APIPathConfiguration = APIPathConfiguration(), customHeaders: [String: String] = [:], timeoutInterval: TimeInterval = 60.0) {
            self.token = token
            self.timeoutInterval = timeoutInterval
            self.customHeaders = customHeaders
            self.organizationIdentifier = nil
            self.apiPath = apiPath
            self.baseURL = baseURL
        }
    }
    
    private let session: URLSessionProtocol
    private var streamingSessions: [NSObject] = []
    
    public let configuration: Configuration

    public convenience init(apiToken: String) {
        self.init(configuration: Configuration(token: apiToken), session: URLSession.shared)
    }
    
    public convenience init(configuration: Configuration) {
        self.init(configuration: configuration, session: URLSession.shared)
    }

    init(configuration: Configuration, session: URLSessionProtocol) {
        self.configuration = configuration
        self.session = session
    }

    public convenience init(configuration: Configuration, session: URLSession = URLSession.shared) {
        self.init(configuration: configuration, session: session as URLSessionProtocol)
    }
    
    public func completions(query: CompletionsQuery, completion: @escaping (Result<CompletionsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<CompletionsResult>(body: query, url: buildURL(path: configuration.apiPath.completions)), completion: completion)
    }
    
    public func completionsStream(query: CompletionsQuery, onResult: @escaping (Result<CompletionsResult, Error>) -> Void, completion: ((Error?) -> Void)?) {
        performSteamingRequest(request: JSONRequest<CompletionsResult>(body: query.makeStreamable(), url: buildURL(path: configuration.apiPath.completions)), onResult: onResult, completion: completion)
    }
    
    public func images(query: ImagesQuery, completion: @escaping (Result<ImagesResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ImagesResult>(body: query, url: buildURL(path: configuration.apiPath.images)), completion: completion)
    }
    
    public func embeddings(query: EmbeddingsQuery, completion: @escaping (Result<EmbeddingsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<EmbeddingsResult>(body: query, url: buildURL(path: configuration.apiPath.embeddings)), completion: completion)
    }
    
    public func chats(query: ChatQuery, completion: @escaping (Result<ChatResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ChatResult>(body: query, url: buildURL(path: configuration.apiPath.chats)), completion: completion)
    }
    
    public func chatsStream(query: ChatQuery, onResult: @escaping (Result<ChatStreamResult, Error>) -> Void, completion: ((Error?) -> Void)?) {
        performSteamingRequest(request: JSONRequest<ChatResult>(body: query.makeStreamable(), url: buildURL(path: configuration.apiPath.chats)), onResult: onResult, completion: completion)
    }
    
    public func edits(query: EditsQuery, completion: @escaping (Result<EditsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<EditsResult>(body: query, url: buildURL(path: configuration.apiPath.edits)), completion: completion)
    }
    
    public func model(query: ModelQuery, completion: @escaping (Result<ModelResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ModelResult>(url: buildURL(path: configuration.apiPath.models.withPath(query.model)), method: "GET"), completion: completion)
    }
    
    public func models(completion: @escaping (Result<ModelsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ModelsResult>(url: buildURL(path: configuration.apiPath.models), method: "GET"), completion: completion)
    }
    
    public func moderations(query: ModerationsQuery, completion: @escaping (Result<ModerationsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ModerationsResult>(body: query, url: buildURL(path: configuration.apiPath.moderations)), completion: completion)
    }
    
    public func audioTranscriptions(query: AudioTranscriptionQuery, completion: @escaping (Result<AudioTranscriptionResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<AudioTranscriptionResult>(body: query, url: buildURL(path: configuration.apiPath.audioTranscriptions)), completion: completion)
    }
    
    public func audioTranslations(query: AudioTranslationQuery, completion: @escaping (Result<AudioTranslationResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<AudioTranslationResult>(body: query, url: buildURL(path: configuration.apiPath.audioTranslations)), completion: completion)
    }
    
    public func audioSpeech(query: AudioSpeechQuery, outputFileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        performDownloadRequest(request: JSONRequest<URL>(body: query, url: buildURL(path: configuration.apiPath.audioSpeech)), outputFileURL: outputFileURL, completion: completion)
    }
}

extension OpenAI {
    func performRequest<ResultType: Codable>(request: any URLRequestBuildable, completion: @escaping (Result<ResultType, Error>) -> Void) {
        do {
            let request = try request.build(token: configuration.token, organizationIdentifier: configuration.organizationIdentifier, timeoutInterval: configuration.timeoutInterval, customHeaders: configuration.customHeaders)
            let task = session.dataTask(with: request) { data, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(OpenAIError.emptyData))
                    return
                }

                var apiError: Error?
                do {
                    let decoded = try JSONDecoder().decode(ResultType.self, from: data)
                    completion(.success(decoded))
                } catch {
                    apiError = error
                }

                if let apiError = apiError {
                    do {
                        let decoded = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                        completion(.failure(decoded))
                    } catch {
                        completion(.failure(apiError))
                    }
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    func performSteamingRequest<ResultType: Codable>(request: any URLRequestBuildable, onResult: @escaping (Result<ResultType, Error>) -> Void, completion: ((Error?) -> Void)?) {
        do {
            let request = try request.build(token: configuration.token, organizationIdentifier: configuration.organizationIdentifier, timeoutInterval: configuration.timeoutInterval, customHeaders: configuration.customHeaders)
            let session = StreamingSession<ResultType>(urlRequest: request)
            session.onReceiveContent = { _, object in
                onResult(.success(object))
            }
            session.onProcessingError = { _, error in
                onResult(.failure(error))
            }
            session.onComplete = { [weak self] object, error in
                self?.streamingSessions.removeAll(where: { $0 == object })
                completion?(error)
            }
            session.perform()
            streamingSessions.append(session)
        } catch {
            completion?(error)
        }
    }
    
    func performDownloadRequest(request: any URLRequestBuildable, outputFileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            let request = try request.build(token: configuration.token, organizationIdentifier: configuration.organizationIdentifier, timeoutInterval: configuration.timeoutInterval, customHeaders: configuration.customHeaders)
            let task = session.downloadTask(with: request) { url, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let url else {
                    completion(.failure(OpenAIError.emptyData))
                    return
                }
                
                // this tmp url might be deleted, so we move it to another place
                let fileManager = FileManager.default
                       
                do {
                    // If file exists at newURL, remove it (optional)
                    if fileManager.fileExists(atPath: outputFileURL.path) {
                        try fileManager.removeItem(at: outputFileURL)
                    }
                           
                    try fileManager.moveItem(at: url, to: outputFileURL)
                    completion(.success(outputFileURL))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
}

extension OpenAI {
    func buildURL(path: String) -> URL {
        let urlString = configuration.baseURL.absoluteString.appending(path)
        return URL(string: urlString)!
    }
}

typealias APIPath = String
extension APIPath {
    func withPath(_ path: String) -> String {
        self + "/" + path
    }
}

public struct APIPathConfiguration {
    let completions: APIPath
    let images: APIPath
    let embeddings: APIPath
    let chats: APIPath
    let edits: APIPath
    let models: APIPath
    let moderations: APIPath
    
    let audioTranscriptions: APIPath
    let audioTranslations: APIPath
    let audioSpeech: APIPath
    
    public init(completions: String = "/v1/completions", images: String = "/v1/images/generations", embeddings: String = "/v1/embeddings", chats: String = "/v1/chat/completions", edits: String = "/v1/edits", models: String = "/v1/models", moderations: String = "/v1/moderations", audioTranscriptions: String = "/v1/audio/transcriptions", audioTranslations: String = "/v1/audio/translations", audioSpeech: String = "/v1/audio/speech") {
        self.completions = completions
        self.images = images
        self.embeddings = embeddings
        self.chats = chats
        self.edits = edits
        self.models = models
        self.moderations = moderations
        self.audioTranscriptions = audioTranscriptions
        self.audioTranslations = audioTranslations
        self.audioSpeech = audioSpeech
    }
}
