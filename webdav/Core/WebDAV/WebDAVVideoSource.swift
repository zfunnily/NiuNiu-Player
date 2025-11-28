//
//  WebDAVVideoSource.swift
//  webdav
//
//  Created by ZQJ on 2025/11/24.
//

//
//  WebDAVVideoSource.swift
//  webdav

import Foundation
import AVFoundation

// WebDAV视频源
class WebDAVVideoSource: VideoSource {
    private let baseURL: URL
    private let filePath: String
    private let username: String?
    private let password: String?
    private let displayName: String
    
    init(baseURL: URL, filePath: String, username: String?, password: String?, name: String) {
        self.baseURL = baseURL
        self.filePath = filePath
        self.username = username
        self.password = password
        self.displayName = name
    }
    
    var name: String {
        return displayName
    }

    // 添加fileExtension属性实现
    var fileExtension: String? {
        // 从filePath中提取文件扩展名
        let url = URL(fileURLWithPath: filePath)
        return url.pathExtension
    }
    
    // 修改getStreamURL方法，改进路径拼接
    func getStreamURL() -> URL? {
        // 安全地构建URL，处理特殊字符
        var pathComponents = [String]()
        
        // 添加基础URL的路径组件
        let basePath = baseURL.pathComponents.dropFirst().joined(separator: "/")
        if !basePath.isEmpty {
            pathComponents.append(basePath)
        }
        
        // 处理文件路径，确保正确拼接
        var cleanFilePath = filePath
        if cleanFilePath.hasPrefix("/") {
            cleanFilePath.removeFirst()
        }
        pathComponents.append(cleanFilePath)
        
        // 重新构建完整URL
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = "/" + pathComponents.joined(separator: "/")

        // 添加身份验证（如果需要）
        if let username = username, let password = password, components.scheme?.hasPrefix("http") ?? false {
            components.user = username
            components.password = password
        }
        
        print("构建的视频URL: \(components.url?.absoluteString ?? "无效URL")")
        return components.url
    }

    // 修改getPlayerItem方法，添加网络配置
    func getPlayerItem() -> AVPlayerItem? {
        guard let fileURL = getStreamURL() else { 
            print("无法构建视频URL")
            return nil 
        }
        
        // 创建带有身份验证和网络配置的选项
        var options: [String: Any] = [:]
        
        // 添加身份验证头
        if let username = username, let password = password {
            let headers: [String: String] = {
                let loginString = "\(username):\(password)"
                if let loginData = loginString.data(using: .utf8) {
                    let base64LoginString = loginData.base64EncodedString()
                    return ["Authorization": "Basic \(base64LoginString)"]
                }
                return [:]
            }()
            
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        
        // 添加网络配置
        options["AVURLAssetHTTPShouldCacheResponseKey"] = { (response: HTTPURLResponse, cacheStoragePolicy: URLCache.StoragePolicy) -> URLCache.StoragePolicy in
            // 允许缓存HTTP响应
            return URLCache.StoragePolicy.allowed
        }
        
        options["AVURLAssetAllowsCellularAccessKey"] = true  // 允许蜂窝网络访问
        
        let asset = AVURLAsset(url: fileURL, options: options)
        
        // 这里不再预加载，因为在VideoPlayerManager中已经处理
        
        let playerItem = AVPlayerItem(asset: asset)
        print("创建播放器项成功")
        return playerItem
    }
}
