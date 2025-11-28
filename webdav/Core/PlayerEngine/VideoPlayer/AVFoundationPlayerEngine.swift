//
//  AVFoundationPlayerEngine.swift
//  webdav
//
//  Created by ZQJ on 2025/11/26.
//

//
//  AVFoundationPlayerEngine.swift
//  webdav
//

import Foundation
import UIKit
import AVFoundation

class AVFoundationPlayerEngine: NSObject, PlayerEngine {

    
    // 内部使用VideoPlayerManager
    private let playerManager = VideoPlayerManager.shared
    private weak var playerView: UIView?
    private var timer: Timer?
    private var url: URL?
    
    // 添加播放速度控制属性
    private var playbackRate: Float = 1.0
    
    // 状态管理
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var progress: Float = 0
    private(set) var playerState: PlayerState = .idle
    
    // 回调
    var onStateChanged: ((PlayerState) -> Void)?
    var onTimeUpdated: ((TimeInterval) -> Void)?
    var onError: ((Error?) -> Void)?
    
    // 初始化
    override init() {
        super.init()
    }
    
    // 播放控制
    func play() {
        playerManager.play()
        isPlaying = true
        updateState(.playing)
        startTimer()
    }
    
    func pause() {
        playerManager.pause()
        isPlaying = false
        updateState(.paused)
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        playerManager.seek(to: time)
    }
    
    func seek(to progress: Float) {
        playerManager.seek(to: Double(progress))
    }
    
    // 配置方法
    func setupPlayer(on view: UIView) {
        self.playerView = view
        updateState(.idle)
    }
    
    func setVideoURL(_ url: URL) {
        self.url = url
        updateState(.loading)
        
        // 使用VideoPlayerManager播放视频
        if let videoSource = createVideoSource(from: url) {
            playerManager.playVideo(from: videoSource,
                                  onViewController: viewControllerFromView(playerView),
                                  configuration: PlayerConfiguration()) {
                self.updateState(.playing)
            } onFailure: { error in
                self.updateState(.error)
                self.onError?(error)
            } onPlaybackStateChanged: { isPlaying in
                self.isPlaying = isPlaying
            }
        }
    }
    
    func setVideoGravity(_ gravity: VideoGravity) {
        // 映射VideoGravity到AVLayerVideoGravity
        var avGravity: AVLayerVideoGravity
        switch gravity {
        case .resizeAspect:
            avGravity = .resizeAspect
        case .resizeAspectFill:
            avGravity = .resizeAspectFill
        case .resize:
            avGravity = .resize
        default:
            avGravity = .resizeAspectFill
        }
        playerManager.updateVideoGravity(avGravity)
    }
    
    func setVolume(_ volume: Float) {
        playerManager.setVolume(volume)
    }
    
    func setLoopEnabled(_ isEnabled: Bool) {
        // VideoPlayerManager已经支持循环播放，这里只是保持接口一致
    }
    
    // 辅助方法
    private func updateState(_ state: PlayerState) {
        playerState = state
        onStateChanged?(state)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimeInfo()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimeInfo() {
        if let playerItem = playerManager.getCurrentPlayerItem() {
            currentTime = playerItem.currentTime().seconds
            duration = playerItem.duration.seconds
            progress = duration > 0 ? Float(currentTime / duration) : 0
            onTimeUpdated?(currentTime)
        }
    }
    
    private func createVideoSource(from url: URL) -> VideoSource? {
        // 创建一个临时的VideoSource实现用于AVFoundation播放
        class TempVideoSource: VideoSource {
            let url: URL
            let name: String
            
            init(url: URL) {
                self.url = url
                self.name = url.lastPathComponent
            }
            
            func getStreamURL() -> URL? {
                return url
            }
            
            func getPlayerItem() -> AVPlayerItem? {
                return AVPlayerItem(url: url)
            }
            
            var fileExtension: String? {
                return url.pathExtension
            }
        }
        return TempVideoSource(url: url)
    }
    
    private func viewControllerFromView(_ view: UIView?) -> UIViewController {
        var responder: UIResponder? = view
        while responder != nil && !(responder is UIViewController) {
            responder = responder?.next
        }
        return (responder as? UIViewController) ?? UIViewController()
    }
    
    func setPlaybackRate(_ rate: Float) {
        
    }
    
    func getPlaybackRate() -> Float {
        return playbackRate
    }
    
    // 资源清理
    func cleanup() {
        stopTimer()
        playerManager.cleanupPreviousPlayer()
        playerView = nil
        url = nil
        updateState(.idle)
    }
}
