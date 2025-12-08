//
//  PlayerManager.swift
//  webdav
//
//  Created by ZQJ on 2025/11/26.
//

import Foundation
import UIKit

class PlayerManager {
    static let shared = PlayerManager()
    private init() {}
    
    // 当前使用的播放器引擎
    private var currentEngine: PlayerEngine?
    private weak var currentViewController: UIViewController?
    private var currentVideoSource: VideoSource?
    
    // 播放视频
    func playVideo(from source: VideoSource,
                  onViewController viewController: UIViewController,
                  configuration: PlayerConfiguration = PlayerConfiguration(),
                  onSuccess: (() -> Void)? = nil,
                  onFailure: ((Error?) -> Void)? = nil,
                  onPlaybackStateChanged: ((Bool) -> Void)? = nil) {
        
        // 清理之前的播放器
        cleanup()
        
        // 保存当前信息
        currentVideoSource = source
        currentViewController = viewController
        
        // 根据文件类型选择合适的引擎
        let engine = createPlayerEngine(for: source)
        currentEngine = engine
        
        // 配置引擎
        engine.setupPlayer(on: viewController.view)
        engine.setVolume(configuration.initialVolume)
        engine.setLoopEnabled(configuration.loopEnabled)
        
        // 设置回调
        engine.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            
            let isPlaying = state == .playing
            onPlaybackStateChanged?(isPlaying)
            
            if state == .loading && onSuccess != nil {
                onSuccess?()
            }
            // 加载成功
            if state == .playing && onSuccess != nil {
                onSuccess?()
            }
        }
        
        engine.onError = { error in
            onFailure?(error)
        }
        
        // 加载视频
        if let url = source.getStreamURL() {
            engine.setVideoURL(url)
            
            // 自动播放
            if configuration.autoPlay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    engine.play()
                }
            }
        } else {
            onFailure?(NSError(domain: "PlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取视频URL"]))
        }
    }
    
    // 根据视频源创建适合的播放器引擎
    private func createPlayerEngine(for source: VideoSource) -> PlayerEngine {
        // 这里可以根据文件扩展名或其他条件选择不同的引擎
//        if let fileExtension = source.fileExtension?.lowercased() {
//            // 对于AVFoundation支持良好的格式，使用原生播放器
//            let avSupportedFormats = ["mp4", "mov", "m4v", "mp3", "aac"]
//            if avSupportedFormats.contains(fileExtension) {
//                return AVFoundationPlayerEngine()
//            }
//        }
        // 目前统一使用VLC引擎，因为它支持最多的格式
        return VLCPlayerEngine()
    }
    // 控制方法
    func play() {
        currentEngine?.play()
    }
    
    func pause() {
        currentEngine?.pause()
    }
    
    func seek(to time: TimeInterval) {
        currentEngine?.seek(to: time)
    }
    
    func seek(to progress: Float) {
        currentEngine?.seek(to: progress)
    }
    
    func setVolume(_ volume: Float) {
        currentEngine?.setVolume(volume)
    }
    
    func updateVideoGravity(_ gravity: VideoGravity) {
        currentEngine?.setVideoGravity(gravity)
    }
    
    // 获取当前状态
    func getCurrentTime() -> TimeInterval {
        return currentEngine?.currentTime ?? 0
    }
    
    func getDuration() -> TimeInterval {
        return currentEngine?.duration ?? 0
    }
    
    func getProgress() -> Float {
        return currentEngine?.progress ?? 0
    }

    func setPlaybackRate(_ rate: Float) {
        currentEngine?.setPlaybackRate(rate)
    }
    
    func getPlaybackRate() -> Float {
        return currentEngine?.getPlaybackRate() ?? 1.0
    }
    
    // 清理资源
    func cleanup() {
        currentEngine?.cleanup()
        currentEngine = nil
        currentViewController = nil
        currentVideoSource = nil
    }
    
    deinit {
        cleanup()
    }
}
