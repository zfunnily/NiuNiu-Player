//
//  VLCPlayerEngine.swift
//  webdav
//
//  Created by ZQJ on 2025/11/26.
//

import Foundation
import UIKit
import MobileVLCKit

class VLCPlayerEngine: NSObject, PlayerEngine, VLCMediaListPlayerDelegate {
    // VLC列表播放器实例
    private var vlcListPlayer: VLCMediaListPlayer?
    private var mediaList: VLCMediaList?
    private var playerView: UIView?
    private var timer: Timer?
    private var currentURL: URL?

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
        guard let listPlayer = vlcListPlayer else { return }
        listPlayer.play()
        // 确保速度设置正确应用
        listPlayer.mediaPlayer.rate = playbackRate
    }
    
    func pause() {
        guard let listPlayer = vlcListPlayer else { return }
        listPlayer.pause()
        // 不需要手动设置isPlaying，由delegate方法更新
    }
    
    func seek(to time: TimeInterval) {
        guard let listPlayer = vlcListPlayer else { return }
        listPlayer.mediaPlayer.time = VLCTime(int: Int32(time * 1000))
    }
    
    func seek(to progress: Float) {
        guard duration > 0 else { return }
        seek(to: TimeInterval(progress) * duration)
    }
    
    // 配置方法
    func setupPlayer(on view: UIView) {
        cleanup()
        
        self.playerView = view
        
        // 创建媒体列表
        let list = VLCMediaList()
        self.mediaList = list
        
        // 创建列表播放器
        let listPlayer = VLCMediaListPlayer()
        listPlayer.mediaPlayer.drawable = view
        listPlayer.mediaList = list
        listPlayer.delegate = self
        
        vlcListPlayer = listPlayer
        updateState(.idle)
    }
    
    func setVideoURL(_ url: URL) {
        guard let list = mediaList, let listPlayer = vlcListPlayer else { return }
        
        // 清除现有媒体
        while list.count > 0 {
            list.removeMedia(at: 0)
        }

        // 创建新的媒体对象
        let media = VLCMedia(url: url)
        // 配置缓冲
        media.addOptions([
            "network-caching": NSNumber(value: 3000), // 3秒缓冲
            "http-user-agent": "iOS Video Player/1.0",
            "http-reconnect": NSNumber(value: 1)
        ])
        
        // 添加到媒体列表
        list.add(media)
        
        // 保存当前URL
        currentURL = url
        
        // 准备播放
        listPlayer.play()
        updateState(.loading)
    }
    
    func setVideoGravity(_ gravity: VideoGravity) {
        // VLC的videoGravity类型处理
        guard let listPlayer = vlcListPlayer else { return }
        let mediaPlayer = listPlayer.mediaPlayer
        
        switch gravity {
        case .resizeAspect:
            // 保持比例，不拉伸
            mediaPlayer.videoAspectRatio = nil
            mediaPlayer.videoCropGeometry = nil
        case .resizeAspectFill:
            // 保持比例并填满
            mediaPlayer.videoAspectRatio = nil
            mediaPlayer.videoCropGeometry = nil
        case .resize:
            // 拉伸填充
            mediaPlayer.videoAspectRatio = nil
        }
    }
    
    func setVolume(_ volume: Float) {
        guard let listPlayer = vlcListPlayer else { return }
        if let audio = listPlayer.mediaPlayer.audio {
            audio.volume = Int32(volume * 100)
        }
    }
    
    func setLoopEnabled(_ isEnabled: Bool) {
        // 使用VLCMediaListPlayer的repeatMode实现循环播放
        vlcListPlayer?.repeatMode = isEnabled ? .repeatCurrentItem : .doNotRepeat
    }
    
    // 内部方法
    private func updateState(_ state: PlayerState) {
        playerState = state
        onStateChanged?(state)
    }
    
    private func updateTimeInfo() {
        guard let listPlayer = vlcListPlayer else { return }
        let mediaPlayer = listPlayer.mediaPlayer
        
        currentTime = Double(mediaPlayer.time.intValue) / 1000.0
        duration = Double(mediaPlayer.media?.length.intValue ?? 0) / 1000.0
        progress = duration > 0 ? Float(currentTime / duration) : 0
        onTimeUpdated?(currentTime)
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimeInfo()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // VLCMediaListPlayerDelegate方法
    func mediaListPlayer(_ mediaListPlayer: VLCMediaListPlayer, didChange state: VLCMediaPlayerState) {
        switch state {
        case .stopped:
            isPlaying = false
            updateState(.ended)
            stopTimer()
        case .playing:
            isPlaying = true
            updateState(.playing)
            startTimer()
            mediaListPlayer.mediaPlayer.rate = playbackRate
        case .paused:
            isPlaying = false
            updateState(.paused)
            // stopTimer()
            // 暂停时继续更新时间，这样用户可以看到当前播放位置·
        case .ended:
            isPlaying = false
            updateState(.ended)
            stopTimer()
        case .error:
            isPlaying = false
            updateState(.error)
            onError?(nil)
            stopTimer()
        default:
            break
        }
    }
    
    func mediaListPlayer(_ mediaListPlayer: VLCMediaListPlayer, mediaPlayerTimeChanged currentTime: VLCTime, duration: VLCTime) {
        // 可选：在这里更新时间信息，或者继续使用定时器
        self.currentTime = Double(currentTime.intValue) / 1000.0
        self.duration = Double(duration.intValue) / 1000.0
        self.progress = self.duration > 0 ? Float(self.currentTime / self.duration) : 0
        onTimeUpdated?(self.currentTime)
    }

     // 添加设置播放速度的方法
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        guard let listPlayer = vlcListPlayer else { return }
        listPlayer.mediaPlayer.rate = rate
    }
     // 获取当前播放速度
    func getPlaybackRate() -> Float {
        return playbackRate
    }
    
    // 资源清理
    func cleanup() {
        stopTimer()
        vlcListPlayer?.stop()
        vlcListPlayer = nil
        mediaList = nil
        playerView = nil
        currentURL = nil
        updateState(.idle)
    }
    
    deinit {
        cleanup()
    }
}
