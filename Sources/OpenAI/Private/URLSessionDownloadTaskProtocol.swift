//
//  URLSessionDownloadTaskProtocol.swift
//  
//
//  Created by Daniel Nguyen on 11/9/23.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol URLSessionDownloadTaskProtocol {
    
    func resume()
}

extension URLSessionDownloadTask: URLSessionDownloadTaskProtocol {}


