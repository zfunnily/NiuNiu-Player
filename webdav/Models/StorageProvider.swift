//
//  StorageProvider.swift
//  potplayer
//
//  Created by ZQJ on 2025/11/14.
//

import Foundation

protocol StorageProvider: AnyObject {
    var providerType: String { get }
    var displayName: String { get set }
    
    // 目录操作
    func listContents(of path: String) async throws -> [FileItem]
    func createDirectory(at path: String) async throws
    
    // 文件操作
    func downloadFile(from path: String) async throws -> Data
    func uploadFile(data: Data, to path: String) async throws
    func deleteItem(at path: String) async throws
    func renameItem(at path: String, to newName: String) async throws
    
    // 连接测试
    func testConnection() async throws -> Bool
}

// 提供者配置协议
protocol ProviderConfiguration: Codable {
    var type: String { get }
    var displayName: String { get set }
}

// WebDAV配置
struct WebDAVConfiguration: ProviderConfiguration {
    let type: String = "webdav"
    var displayName: String
    let baseURL: URL
    let username: String
    let password: String
    let isBasicAuth: Bool
}
