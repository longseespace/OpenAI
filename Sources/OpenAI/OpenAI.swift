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
    private var streamingSessions = ArrayWithThreadSafety<NSObject>()
    
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

    // UPDATES FROM 11-06-23
    public func threadsAddMessage(threadId: String, query: MessageQuery, completion: @escaping (Result<ThreadAddMessageResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ThreadsMessagesResult>(body: query, url: buildRunsURL(path: .threadsMessages, threadId: threadId)), completion: completion)
    }

    public func threadsMessages(threadId: String, before: String? = nil, completion: @escaping (Result<ThreadsMessagesResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ThreadsMessagesResult>(body: nil, url: buildRunsURL(path: .threadsMessages, threadId: threadId, before: before), method: "GET"), completion: completion)
    }

    public func runRetrieve(threadId: String, runId: String, completion: @escaping (Result<RunResult, Error>) -> Void) {
        performRequest(request: JSONRequest<RunResult>(body: nil, url: buildRunRetrieveURL(path: .runRetrieve, threadId: threadId, runId: runId), method: "GET"), completion: completion)
    }

    public func runRetrieveSteps(threadId: String, runId: String, before: String? = nil, completion: @escaping (Result<RunRetrieveStepsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<RunRetrieveStepsResult>(body: nil, url: buildRunRetrieveURL(path: .runRetrieveSteps, threadId: threadId, runId: runId, before: before), method: "GET"), completion: completion)
    }
    
    public func runSubmitToolOutputs(threadId: String, runId: String, query: RunToolOutputsQuery, completion: @escaping (Result<RunResult, Error>) -> Void) {
        performRequest(request: JSONRequest<RunResult>(body: query, url: buildURL(path: .runSubmitToolOutputs(threadId: threadId, runId: runId)), method: "POST"), completion: completion)
    }

    public func runs(threadId: String, query: RunsQuery, completion: @escaping (Result<RunResult, Error>) -> Void) {
        performRequest(request: JSONRequest<RunResult>(body: query, url: buildRunsURL(path: .runs, threadId: threadId)), completion: completion)
    }

    public func threads(query: ThreadsQuery, completion: @escaping (Result<ThreadsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ThreadsResult>(body: query, url: buildURL(path: .threads)), completion: completion)
    }
    
    public func threadRun(query: ThreadRunQuery, completion: @escaping (Result<RunResult, Error>) -> Void) {
        performRequest(request: JSONRequest<RunResult>(body: query, url: buildURL(path: .threadRun)), completion: completion)
    }

    public func assistants(after: String? = nil, completion: @escaping (Result<AssistantsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<AssistantsResult>(url: buildURL(path: .assistants, after: after), method: "GET"), completion: completion)
    }

    public func assistantCreate(query: AssistantsQuery, completion: @escaping (Result<AssistantResult, Error>) -> Void) {
        performRequest(request: JSONRequest<AssistantsResult>(body: query, url: buildURL(path: .assistants), method: "POST"), completion: completion)
    }

    public func assistantModify(query: AssistantsQuery, assistantId: String, completion: @escaping (Result<AssistantResult, Error>) -> Void) {
        performRequest(request: JSONRequest<AssistantsResult>(body: query, url: buildAssistantURL(path: .assistantsModify, assistantId: assistantId), method: "POST"), completion: completion)
    }

    public func files(query: FilesQuery, completion: @escaping (Result<FilesResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<FilesResult>(body: query, url: buildURL(path: .files)), completion: completion)
    }
    // END UPDATES FROM 11-06-23

    public func completions(query: CompletionsQuery, completion: @escaping (Result<CompletionsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<CompletionsResult>(body: query, url: buildURL(path: configuration.apiPath.completions)), completion: completion)
    }
    
    public func completionsStream(query: CompletionsQuery, control: StreamControl, onResult: @escaping (Result<CompletionsResult, Error>) -> Void, completion: ((Error?) -> Void)?) {
        performStreamingRequest(request: JSONRequest<CompletionsResult>(body: query.makeStreamable(), url: buildURL(path: configuration.apiPath.completions)), control: control, onResult: onResult, completion: completion)
    }
    
    public func images(query: ImagesQuery, completion: @escaping (Result<ImagesResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ImagesResult>(body: query, url: buildURL(path: configuration.apiPath.images)), completion: completion)
    }
    
    public func imageEdits(query: ImageEditsQuery, completion: @escaping (Result<ImagesResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<ImagesResult>(body: query, url: buildURL(path: .imageEdits)), completion: completion)
    }
    
    public func imageVariations(query: ImageVariationsQuery, completion: @escaping (Result<ImagesResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<ImagesResult>(body: query, url: buildURL(path: .imageVariations)), completion: completion)
    }
    
    public func embeddings(query: EmbeddingsQuery, completion: @escaping (Result<EmbeddingsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<EmbeddingsResult>(body: query, url: buildURL(path: configuration.apiPath.embeddings)), completion: completion)
    }
    
    public func chats(query: ChatQuery, completion: @escaping (Result<ChatResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ChatResult>(body: query, url: buildURL(path: configuration.apiPath.chats)), completion: completion)
    }
    
    public func chatsStream(query: ChatQuery, control: StreamControl, onResult: @escaping (Result<ChatStreamResult, Error>) -> Void, completion: ((Error?) -> Void)?) {
        performStreamingRequest(request: JSONRequest<ChatResult>(body: query.makeStreamable(), url: buildURL(path: configuration.apiPath.chats)), control: control, onResult: onResult, completion: completion)
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
    
    @available(iOS 13.0, *)
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
    
    public func audioCreateSpeech(query: AudioSpeechQuery, completion: @escaping (Result<AudioSpeechResult, Error>) -> Void) {
        performSpeechRequest(request: JSONRequest<AudioSpeechResult>(body: query, url: buildURL(path: configuration.apiPath.audioSpeech)), completion: completion)
    }

    public func audioCreateSpeechStream(query: AudioSpeechQuery, onResult: @escaping (Result<AudioSpeechResult, Error>) -> Void, completion: ((Error?) -> Void)?) {
        performSpeechStreamingRequest(
            request: JSONRequest<AudioSpeechResult>(body: query, url: buildURL(path: .audioSpeech)),
            onResult: onResult,
            completion: completion
        )
    }
}

extension OpenAI {
    func performRequest<ResultType: Codable>(request: any URLRequestBuildable, completion: @escaping (Result<ResultType, Error>) -> Void) {
        do {
            let request = try request.build(token: configuration.token, organizationIdentifier: configuration.organizationIdentifier, timeoutInterval: configuration.timeoutInterval, customHeaders: configuration.customHeaders)
            let task = session.dataTask(with: request) { data, _, error in
                if let error = error {
                    return completion(.failure(error))
                }
                guard let data = data else {
                    return completion(.failure(OpenAIError.emptyData))
                }

                var apiError: Error?
                let decoder = JSONDecoder()
                do {
                    completion(.success(try decoder.decode(ResultType.self, from: data)))
                } catch {
                    completion(.failure((try? decoder.decode(APIErrorResponse.self, from: data)) ?? error))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    func performStreamingRequest<ResultType: Codable>(request: any URLRequestBuildable, control: StreamControl, onResult: @escaping (Result<ResultType, Error>) -> Void, completion: ((Error?) -> Void)?) {
        do {
            let request = try request.build(token: configuration.token, organizationIdentifier: configuration.organizationIdentifier, timeoutInterval: configuration.timeoutInterval, customHeaders: configuration.customHeaders)
            let session = StreamingSession<ResultType>(urlRequest: request)
            control.setSession(session as! StreamingSession<ChatStreamResult>)
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
            let request = try request.build(token: configuration.token, 
                                            organizationIdentifier: configuration.organizationIdentifier,
                                            timeoutInterval: configuration.timeoutInterval,
                                            customHeaders: configuration.customHeaders)
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
        } catch {
            completion(.failure(error))
        }
    }
    
    func performSpeechRequest(request: any URLRequestBuildable, completion: @escaping (Result<AudioSpeechResult, Error>) -> Void) {
        do {
            let request = try request.build(token: configuration.token, 
                                            organizationIdentifier: configuration.organizationIdentifier,
                                            timeoutInterval: configuration.timeoutInterval,
                                            customHeaders: configuration.customHeaders)
            
            let task = session.dataTask(with: request) { data, _, error in
                if let error = error {
                    return completion(.failure(error))
                }
                guard let data = data else {
                    return completion(.failure(OpenAIError.emptyData))
                }
                
                completion(.success(AudioSpeechResult(audio: data)))
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }

    func performSpeechStreamingRequest(request: any URLRequestBuildable, onResult: @escaping (Result<AudioSpeechResult, Error>) -> Void, completion: ((Error?) -> Void)?) {
        do {
            let request = try request.build(token: configuration.token,
                                            organizationIdentifier: configuration.organizationIdentifier,
                                            timeoutInterval: configuration.timeoutInterval,
                                            customHeaders: configuration.customHeaders)
            let session = StreamingSession<AudioSpeechResult>(urlRequest: request)
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
}

extension OpenAI {
    func buildURL(path: String) -> URL {
        let urlString = configuration.baseURL.absoluteString.appending(path)
        return URL(string: urlString)!
    }
    
     func buildURL(path: String, after: String? = nil) -> URL {
         var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)!
//         components.scheme = "https"
//         components.host = configuration.baseURL.host
         components.path = path
         if let after {
             components.queryItems = [URLQueryItem(name: "after", value: after)]
         }
         
         return components.url!
     }

    func buildRunsURL(path: String, threadId: String, before: String? = nil) -> URL {
        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)!
//        components.scheme = "https"
//        components.host = configuration.baseURL.host
        components.path = path.replacingOccurrences(of: "THREAD_ID", with: threadId)
        if let before {
            components.queryItems = [URLQueryItem(name: "before", value: before)]
        }
        return components.url!
    }

    func buildRunRetrieveURL(path: String, threadId: String, runId: String, before: String? = nil) -> URL {
        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)!
//        components.scheme = "https"
//        components.host = configuration.baseURL.host
        components.path = path.replacingOccurrences(of: "THREAD_ID", with: threadId)
                              .replacingOccurrences(of: "RUN_ID", with: runId)
        if let before {
            components.queryItems = [URLQueryItem(name: "before", value: before)]
        }
        return components.url!
    }

    func buildAssistantURL(path: String, assistantId: String) -> URL {
        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)!
//        components.scheme = "https"
//        components.host = configuration.baseURL.host
        components.path = path.replacingOccurrences(of: "ASST_ID", with: assistantId)

        return components.url!
    }
}

typealias APIPath = String
extension APIPath {
    // 1106
    static let assistants = "/v1/assistants"
    static let assistantsModify = "/v1/assistants/ASST_ID"
    static let threads = "/v1/threads"
    static let threadRun = "/v1/threads/runs"
    static let runs = "/v1/threads/THREAD_ID/runs"
    static let runRetrieve = "/v1/threads/THREAD_ID/runs/RUN_ID"
    static let runRetrieveSteps = "/v1/threads/THREAD_ID/runs/RUN_ID/steps"
    static func runSubmitToolOutputs(threadId: String, runId: String) -> String {
        "/v1/threads/\(threadId)/runs/\(runId)/submit_tool_outputs"
    }
    static let threadsMessages = "/v1/threads/THREAD_ID/messages"
    static let files = "/v1/files"
    // 1106 end

    static let completions = "/v1/completions"
    static let embeddings = "/v1/embeddings"
    static let chats = "/v1/chat/completions"
    static let edits = "/v1/edits"
    static let models = "/v1/models"
    static let moderations = "/v1/moderations"
    
    static let audioSpeech = "/v1/audio/speech"
    static let audioTranscriptions = "/v1/audio/transcriptions"
    static let audioTranslations = "/v1/audio/translations"
    
    static let images = "/v1/images/generations"
    static let imageEdits = "/v1/images/edits"
    static let imageVariations = "/v1/images/variations"
    
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
