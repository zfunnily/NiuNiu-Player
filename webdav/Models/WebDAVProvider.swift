import Foundation

struct WebDAVProvider: Codable, Identifiable, Equatable {
    
    var id = UUID()
    var name: String
    var serverURL: String
    var username: String
    var password: String
    var isConnected: Bool = false
    var usessl: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, name, serverURL, username, password, usessl
    }
    
    // 直接初始化，避免方法调用中的self引用问题
    init(id: UUID = UUID(), name: String, serverURL: String, username: String, password: String, usessl: Bool = false) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
        self.username = username
        self.usessl = usessl
        
        // 添加调试信息，确认输入的原始密码
        DLog("初始化WebDAVProvider，原始密码长度: \(password.count)")
        
        // 直接在初始化中进行密码编码，避免调用可能访问未初始化属性的方法
        self.password = password.data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    static func == (lhs: WebDAVProvider, rhs: WebDAVProvider) -> Bool {
        return lhs.id == rhs.id
    }
    
    var displayURL: String {
        // 检查serverURL是否已经包含协议前缀
        if serverURL.starts(with: "http://") || serverURL.starts(with: "https://") {
            return serverURL
        }
        // 只有在没有协议前缀时才添加
        return "\(usessl ? "https" : "http")://\(serverURL)"
    }
    
    // 获取解密后的密码
    func getDecryptedPassword() -> String {
        DLog("尝试解密密码，编码长度: \(password.count)")
        guard let data = Data(base64Encoded: password) else {
            DLog("密码不是有效的base64编码")
            return ""
        }
        
        guard let decrypted = String(data: data, encoding: .utf8) else {
            DLog("无法将数据转换回字符串")
            return ""
        }
        
        DLog("密码解密成功")
        return decrypted
    }
    
    // 更新密码方法
    mutating func updatePassword(_ newPassword: String) {
        self.password = newPassword.data(using: .utf8)?.base64EncodedString() ?? ""
    }
}
