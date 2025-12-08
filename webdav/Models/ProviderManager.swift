import Foundation

class ProviderManager {
    static let shared = ProviderManager()
    private let providersKey = "webdavProviders"
    
    var providers: [WebDAVProvider] = []
    
    init() {
        loadProviders()
    }
    
    // 添加新的WebDAV服务器
    func addProvider(_ provider: WebDAVProvider) {
        providers.append(provider)
        saveProviders()
    }
    
    // 更新WebDAV服务器信息
    func updateProvider(id: UUID, updatedProvider: WebDAVProvider) {
        if let index = providers.firstIndex(where: { $0.id == id }) {
            providers[index] = updatedProvider
            saveProviders()
        }
    }
    
    // 删除WebDAV服务器
    func deleteProvider(id: UUID) {
        providers.removeAll { $0.id == id }
        saveProviders()
    }
    
    // 获取指定ID的服务器
    func getProvider(id: UUID) -> WebDAVProvider? {
        return providers.first { $0.id == id }
    }
    
    // 创建WebDAV客户端
    func createClient(for provider: WebDAVProvider) -> WebDAVClient? {
        // 使用displayURL而不是直接使用serverURL，确保URL格式正确
        let urlString = provider.displayURL
        DLog("创建客户端，URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            DLog("URL格式无效")
            return nil
        }

        // let username = provider.username.isEmpty ? nil : provider.username
        // let password = provider.password.isEmpty ? nil : provider.password
        // DLog("使用用户名: \(username ?? "无")，密码长度: \(password?.count ?? 0)")


        // return WebDAVClient(baseURL: url, username: username, password: password)
        
        let username = provider.username.isEmpty ? nil : provider.username
        let password = provider.getDecryptedPassword()
        DLog("使用用户名: \(username ?? "无")，密码长度: \(password.count)")
        return WebDAVClient(baseURL: url, username: username, password: password.isEmpty ? nil : password)
    }
    
    // 测试连接
    func testConnection(_ provider: WebDAVProvider, completion: @escaping (Bool, Error?) -> Void) {
        guard let client = createClient(for: provider) else {
            completion(false, NSError(domain: "WebDAV", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的URL"]))
            return
        }
        
        client.testConnection { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let success):
                    // 更新连接状态
                    if let index = self.providers.firstIndex(where: { $0.id == provider.id }) {
                        self.providers[index].isConnected = success
                        self.saveProviders()
                    }
                    completion(success, nil)
                case .failure(let error):
                    completion(false, error)
                }
            }
        }
    }
    
    // 保存到本地存储
    private func saveProviders() {
        if let encoded = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(encoded, forKey: providersKey)
        }
    }
    
    // 从本地存储加载
    private func loadProviders() {
        if let data = UserDefaults.standard.data(forKey: providersKey) {
            if let decoded = try? JSONDecoder().decode([WebDAVProvider].self, from: data) {
                providers = decoded
            }
        }
    }
}
