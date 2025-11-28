//
//  FileItem.swift
//  potplayer
//
//  Created by ZQJ on 2025/11/14.
//
import Foundation

struct FileItem: Codable, Equatable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    
    var displaySize: String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else if size < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        } else {
            return String(format: "%.1f GB", Double(size) / (1024.0 * 1024.0 * 1024.0))
        }
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: modificationDate)
    }
}
