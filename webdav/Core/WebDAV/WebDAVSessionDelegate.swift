//
//  WebDAVSessionDelegate.swift
//  webdav
//
//  Created by ZQJ on 2025/11/28.
//

import Foundation


// 修改自定义代理类以正确处理认证挑战
class WebDAVSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let username: String?
    private let password: String?
    
    // 初始化时保存认证信息
    init(username: String?, password: String?) {
        self.username = username
        self.password = password
    }
    
    // 处理服务器证书验证
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 处理服务器信任挑战
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // 处理HTTP Basic认证挑战
        else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            print("收到HTTP Basic认证挑战")
            print("认证领域: \(challenge.protectionSpace.realm ?? "未知")")
            print("认证主机: \(challenge.protectionSpace.host)")
            
            // 检查是否有用户名密码
            if let username = username, let password = password {
                print("提供认证凭证，用户名: \(username)")
                // 创建凭证并提供给服务器
                let credential = URLCredential(user: username, password: password, persistence: .forSession)
                completionHandler(.useCredential, credential)
                return
            } else {
                print("没有可用的认证信息")
            }
        }
        
        // 默认处理其他类型的挑战
        completionHandler(.performDefaultHandling, nil)
    }
    
    // 可以添加其他委托方法来处理会话级别的事件
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            print("URLSession失效: \(error.localizedDescription)")
        }
    }
}
