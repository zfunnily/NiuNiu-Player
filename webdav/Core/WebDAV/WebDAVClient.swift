//
//  WebDAVClient.swift
//  webdav
//
//  Created by ZQJ on 2025/11/20.
//

import Foundation

class WebDAVClient {
    let baseURL: URL
    let username: String?
    let password: String?
    let maxRetries = 3
    let session: URLSession
    private let sessionDelegate: WebDAVSessionDelegate
   
    init(baseURL: URL, username: String?, password: String?) {
        self.baseURL = baseURL
        self.username = username
        self.password = password

        // 创建URLSession配置
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        
        // 创建代理对象并传入认证信息
        self.sessionDelegate = WebDAVSessionDelegate(username: username, password: password)

        // 使用自定义代理初始化session
        self.session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }
    
    // 创建带认证的请求
    private func createRequest(for path: String, method: String, headers: [String: String]? = nil) -> URLRequest {
        var normalizedPath = path
        if !path.isEmpty && !path.hasPrefix("/") {
            normalizedPath = "/" + path
        }
        
        let url = baseURL.appendingPathComponent(normalizedPath)
        print("创建请求: \(method) \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        print("Final URL:", request.url?.absoluteString ?? "nil")

        // 设置WebDAV必要的头部
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("*/*", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("WebDAVClient/1.0", forHTTPHeaderField: "User-Agent")

        // 添加Host头部
        if let host = url.host,
        let port = url.port {
            request.setValue("\(host):\(port)", forHTTPHeaderField: "Host")
        } else if let host = url.host {
            request.setValue(host, forHTTPHeaderField: "Host")
        }

        // 添加自定义头部
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // 添加基本认证
        if let username = username, let password = password {
            print("添加Basic认证头，用户名: \(username)")
            
            let loginString = "\(username):\(password)"
            guard let loginData = loginString.data(using: .utf8) else {
                print("无法将用户名密码转换为数据")
                return request
            }
            
            let base64LoginString = loginData.base64EncodedString(options: [])
            let authString = "Basic \(base64LoginString)"
            request.setValue(authString, forHTTPHeaderField: "Authorization")
            
             // 解码认证头进行验证（仅用于调试）
            if let decodedData = Data(base64Encoded: base64LoginString),
            let decodedString = String(data: decodedData, encoding: .utf8) {
                print("认证头解码验证: \(decodedString)")
            }
            // 打印认证头的长度（但不要打印完整内容，出于安全考虑）
            print("认证头设置，长度: \(authString.count)")
        } else {
            print("未提供认证信息")
        }
        
        // 打印所有请求头
        print("请求头:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            print("\(key): \(value)")
        }
        return request
    }
    
    // 测试连接
    func testConnection(completion: @escaping (Result<Bool, Error>) -> Void) {
        let headers = [
            "Depth": "0", 
            "Content-Type": "application/xml"
        ]

        var request = createRequest(for: "", method: "PROPFIND", headers: headers)

        request.httpBody = nil

        print("发送GET请求到: \(request.url?.absoluteString ?? "nil")")

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("连接错误: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("testConnection, 状态码: \(httpResponse.statusCode)")
                // 打印所有响应头以便调试
                print("响应头:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("\(key): \(value)")
                }
                
                // 打印响应体（如果有）
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("响应体: \(responseString)")
                }
                
                // WebDAV服务器通常返回207 Multi-Status或200 OK表示成功
                let success = (200...299).contains(httpResponse.statusCode)
                completion(.success(success))
                if httpResponse.statusCode == 401 {
                    print("注意: 服务器返回 401，可能需要不同的认证方式或路径错误")
                    if let wwwAuth = httpResponse.allHeaderFields["WWW-Authenticatee"] ?? httpResponse.allHeaderFields["www-authenticate"]
                    {
                        print("服务器要求认证方式:", wwwAuth)
                    }
                }
                if httpResponse.statusCode == 404 {
                    print("注意: 服务器返回 404，检查URL路径是否正确")
                }
                
            } else {
                completion(.failure(NSError(domain: "WebDAV", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])))
            }
        }
        
        task.resume()
    }
    
    // 获取目录内容
    func listContents(at path: String, completion: @escaping (Result<[WebDAVItem], Error>) -> Void) {
        let headers = [
            "Depth": "1", // 只获取直接子项，避免"infinity"问题
            "Content-Type": "application/xml"
        ]

        var request = createRequest(for: path, method: "PROPFIND", headers: headers)

        let body = """
            <d:propfind xmlns:d="DAV:">
                <d:prop>
                    <d:resourcetype/>
                    <d:getcontentlength/>
                    <d:getlastmodified/>
                    <d:displayname/>
                </d:prop>
            </d:propfind>
            """
            
        if let data = body.data(using: .utf8) {
            request.httpBody = data
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                completion(.failure(NSError(domain: "WebDAV", code: 0, userInfo: [NSLocalizedDescriptionKey: "请求失败"])))
                return
            }
            
            // 解析XML响应
            do {
                let items = try self.parseDirectoryListing(at: path, xmlData: data)
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 解析WebDAV目录列表XML
    private func parseDirectoryListing(at path: String, xmlData: Data) throws -> [WebDAVItem] {
        let parseResult = WebDAVXMLParser.parseDirectoryListing(at: path, xmlData: xmlData)
        switch parseResult {
        case .success(let items):
            // 成功解析目录项
//            for item in items {
//                print("\(item.type == .directory ? "目录" : "文件"): \(item.name), 大小: \(item.size ?? 0)字节")
//            }
            return items
        case .failure(let error):
            print("解析失败: \(error)")
        }
        var items: [WebDAVItem] = []
        return items
    }
    
    // 创建目录
    func createDirectory(at path: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let request = createRequest(for: path, method: "MKCOL")
        
        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                // 201 Created 或 405 Method Not Allowed（表示目录已存在）
                let success = httpResponse.statusCode == 201 || httpResponse.statusCode == 405
                completion(.success(success))
            } else {
                completion(.failure(NSError(domain: "WebDAV", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])))
            }
        }
        
        task.resume()
    }
    
    // 上传文件
    func uploadFile(data: Data, to path: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let request = createRequest(for: path, method: "PUT")
        
        let task = session.uploadTask(with: request, from: data) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                completion(.success(success))
            } else {
                completion(.failure(NSError(domain: "WebDAV", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])))
            }
        }
        
        task.resume()
    }
    
    // 下载文件
    func downloadFile(from path: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let request = createRequest(for: path, method: "GET")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                completion(.failure(NSError(domain: "WebDAV", code: 0, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                return
            }
            
            completion(.success(data))
        }
        
        task.resume()
    }
    
    // 删除文件或目录
    func deleteItem(at path: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let request = createRequest(for: path, method: "DELETE")
        
        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                completion(.success(success))
            } else {
                completion(.failure(NSError(domain: "WebDAV", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])))
            }
        }
        
        task.resume()
    }
}
