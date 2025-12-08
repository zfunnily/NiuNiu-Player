//
//  VideoPlayerManager.swift
//  webdav
//
//  Created by ZQJ on 2025/11/24.
//

//
//  VideoPlayerManager.swift
//  webdav
//
//  Created by ZQJ on 2023/11/22.
//

import AVFoundation
import UIKit

class VideoPlayerManager {
    // 单例模式
    static let shared = VideoPlayerManager()
    private init() {}
    
    // 当前播放器
    private var currentPlayer: AVPlayer?
    private var currentPlayerLayer: AVPlayerLayer?
    private var currentViewController: UIViewController?
    
    // 播放通知令牌
    private var playToEndTimeObserver: Any?
    private var timeControlStatusObserver: NSKeyValueObservation?
    
    // 播放视频
    func playVideo(from source: VideoSource,
                  onViewController viewController: UIViewController,
                  configuration: PlayerConfiguration = PlayerConfiguration(),
                  onSuccess: (() -> Void)? = nil,
                  onFailure: ((Error?) -> Void)? = nil,
                  onPlaybackStateChanged: ((Bool) -> Void)? = nil) {
        // 清理之前的播放器
        cleanupPreviousPlayer()
        
        // 获取播放器项
        guard let playerItem = source.getPlayerItem() else {
            onFailure?(NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建播放器项"]))
            return
        }

        // 添加视频加载失败处理
        NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled, object: playerItem, queue: .main) { _ in
            DLog("播放卡顿")
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: .main) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                DLog("播放失败: \(error.localizedDescription)")
                onFailure?(error)
            }
        }
        
        // 创建播放器
        let player = AVPlayer(playerItem: playerItem)
        currentPlayer = player
        
        // 创建并配置播放器图层
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = viewController.view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(playerLayer)
        currentPlayerLayer = playerLayer
        currentViewController = viewController

        // 配置后台播放
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            DLog("配置音频会话失败: \(error)")
        }
    
        // 监听播放状态变化
        timeControlStatusObserver = player.observe(\.timeControlStatus) { [weak self] player, _ in
            guard let self = self else { return }
            
            let isPlaying = player.timeControlStatus == .playing
            onPlaybackStateChanged?(isPlaying)
        }
        
        // 配置循环播放
        if configuration.loopEnabled {
            playToEndTimeObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                self?.currentPlayer?.seek(to: .zero)
                if configuration.autoPlay {
                    self?.currentPlayer?.play()
                }
            }
        }
        
        // 自动播放
        if configuration.autoPlay {
            player.play()
            DLog("开始自动播放")

        }
        
        // 设置预加载
        if let preloadSeconds = configuration.preloadSeconds {
            playerItem.preferredForwardBufferDuration = preloadSeconds
            if #available(iOS 16.0, *) {
                Task {
                    do {
                        let isPlayable = try await playerItem.asset.load(.isPlayable)
                        let tracks = try await playerItem.asset.load(.tracks)
                        DLog("资产可播放: \(isPlayable), 轨道数: \(tracks.count)")
                    } catch {
                        DLog("预加载失败: \(error)")
                    }
                }
            } else {
                // iOS 16以下版本保留原有实现
                playerItem.asset.loadValuesAsynchronously(forKeys: ["playable", "tracks"]) { [weak self] in
                    guard let self = self else { return }
                    
                    var error: NSError?
                    if playerItem.asset.statusOfValue(forKey: "playable", error: &error) == .loaded {
                        DLog("资产可播放: \(playerItem.asset.isPlayable)")
                    }
                }
            }
        }
        
        onSuccess?()
    }
    // 添加方法：更新视频重力
    func updateVideoGravity(_ gravity: AVLayerVideoGravity) {
        currentPlayerLayer?.videoGravity = gravity
    }
    
    // 添加方法：获取当前播放器项
    func getCurrentPlayerItem() -> AVPlayerItem? {
        return currentPlayer?.currentItem
    }
    
    // 控制方法
    func play() {
        currentPlayer?.play()
    }
    
    func pause() {
        currentPlayer?.pause()
    }
    
    func seek(to time: CMTime) {
        currentPlayer?.seek(to: time)
    }
    
    func seek(to progress: Double) {
        guard let currentItem = currentPlayer?.currentItem, let duration = currentItem.asset.duration.seconds as Double? else {
            return
        }
        
        let targetTime = CMTime(seconds: progress * duration, preferredTimescale: 600)
        currentPlayer?.seek(to: targetTime)
    }
    
    func setVolume(_ volume: Float) {
        currentPlayer?.volume = volume
    }
    
    // 清理资源
    func cleanupPreviousPlayer() {
        // 移除通知观察
        if let observer = playToEndTimeObserver {
            NotificationCenter.default.removeObserver(observer)
            playToEndTimeObserver = nil
        }
        
        // 移除属性观察
        timeControlStatusObserver = nil
        
        // 暂停播放
        currentPlayer?.pause()
        
        // 移除图层
        if let layer = currentPlayerLayer {
            layer.removeFromSuperlayer()
            currentPlayerLayer = nil
        }
        
        // 清除引用
        currentPlayer = nil
        currentViewController = nil
    }
    
    deinit {
        cleanupPreviousPlayer()
    }
}
