//
//  StreamingSession.swift
//  
//
//  Created by Sergii Kryvoblotskyi on 18/04/2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class StreamingSession<ResultType: Codable>: NSObject, Identifiable, URLSessionDelegate, URLSessionDataDelegate {
    
    enum StreamingError: Error {
        case unknownContent
        case emptyContent
    }
    
    var onReceiveContent: ((StreamingSession, ResultType) -> Void)?
    var onProcessingError: ((StreamingSession, Error) -> Void)?
    var onComplete: ((StreamingSession, Error?) -> Void)?
    
    private var partialContent = ""
    private let streamingCompletionMarker = "[DONE]"
    private let commentMarker = ":"
    private let urlRequest: URLRequest
    private lazy var urlSession: URLSession = {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        return session
    }()
    
    init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
    }
    
    func perform() {
        self.urlSession
            .dataTask(with: self.urlRequest)
            .resume()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?(self, error)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let stringContent = String(data: data, encoding: .utf8) else {
            onProcessingError?(self, StreamingError.unknownContent)
            return
        }
        
        // first, check if it's an error
        do {
            let decoded = try JSONDecoder().decode(APIErrorResponse.self, from: data)
            onProcessingError?(self, decoded)
            return
        } catch {
            // not an JSON error, continue
        }
        
        let jsonObjects = "\(partialContent)\(stringContent)"
            .components(separatedBy: "\n")
            .filter { $0.isEmpty == false }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.starts(with: "data: ") }
            .map { String($0.dropFirst("data: ".count)) }
        guard jsonObjects.isEmpty == false, jsonObjects.first != streamingCompletionMarker else {
            return
        }
        jsonObjects.enumerated().forEach { (index, jsonContent)  in
            guard jsonContent != streamingCompletionMarker else {
                return
            }
            guard let jsonData = jsonContent.data(using: .utf8) else {
                onProcessingError?(self, StreamingError.unknownContent)
                return
            }
            
            var apiError: Error? = nil
            do {
                let decoder = JSONDecoder()
                let object = try decoder.decode(ResultType.self, from: jsonData)
                onReceiveContent?(self, object)
                
                if index == jsonObjects.count - 1 {
                    partialContent = ""
                }
            } catch {
                // if decoding error on last item, it's most likely a partial chunk, keep it around as leftover characters for the next call
                if index == jsonObjects.count - 1 {
                    partialContent = "data: \(jsonContent)"
                } else {
                    apiError = error
                }
            }
            
            if let apiError = apiError {
                do {
                    let decoded = try JSONDecoder().decode(APIErrorResponse.self, from: jsonData)
                    onProcessingError?(self, decoded)
                } catch {
                    onProcessingError?(self, apiError)
                }
            }
        }
    }
}
