//
//  VideoSource.swift
//  webdav

import Foundation
import AVFoundation

// 视频源协议
protocol VideoSource {
    func getStreamURL() -> URL?
    func getPlayerItem() -> AVPlayerItem?
    var name: String { get }
    var fileExtension: String? { get }
}

// 播放器配置
struct PlayerConfiguration {
    let autoPlay: Bool
    let loopEnabled: Bool
    let preloadSeconds: Double?
    let initialVolume: Float
    
    init(autoPlay: Bool = true, loopEnabled: Bool = false, preloadSeconds: Double? = 30.0, initialVolume: Float = 1.0) {
        self.autoPlay = autoPlay
        self.loopEnabled = loopEnabled
        self.preloadSeconds = preloadSeconds
        self.initialVolume = initialVolume
    }
}
