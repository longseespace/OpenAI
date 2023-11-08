//
//  DownloadTaskMock.swift
//
//
//  Created by Sergii Kryvoblotskyi on 02/04/2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import OpenAI

class DownloadTaskMock: URLSessionDownloadTaskProtocol {
    
    var url: URL?
    var response: URLResponse?
    var error: Error?
    
    var completion: ((URL?, URLResponse?, Error?) -> Void)?
    
    func resume() {
        completion?(url, response, error)
    }
}

extension DownloadTaskMock {
    
    static func successful(with url: URL) -> DownloadTaskMock {
        let task = DownloadTaskMock()
        task.url = url
        task.response = HTTPURLResponse(url: URL(fileURLWithPath: ""), statusCode: 200, httpVersion: nil, headerFields: nil)
        return task
    }
    
    static func failed(with error: Error) -> DownloadTaskMock {
        let task = DownloadTaskMock()
        task.error = error
        task.response = HTTPURLResponse(url: URL(fileURLWithPath: ""), statusCode: 503, httpVersion: nil, headerFields: nil)
        return task
    }
}
