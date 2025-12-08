//
//  VLCPlayerEngine.swift
//  webdav
//
//  Created by ZQJ on 2025/11/26.
//

import Foundation
import UIKit
import MobileVLCKit

class VLCPlayerEngine: NSObject, PlayerEngine, VLCMediaListPlayerDelegate, VLCMediaPlayerDelegate {
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
    
    private var durationPollingTimer: Timer?

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
        
        listPlayer.delegate = self
        listPlayer.mediaPlayer.delegate = self
        
        listPlayer.mediaList = list
        
        vlcListPlayer = listPlayer
        updateState(.idle)
    }
    
    func setVideoURL(_ url: URL) {
        guard let list = mediaList, let listPlayer = vlcListPlayer else { return }

        // 重置状态
        self.currentTime = 0
        self.duration = 0
        self.progress = 0

        // 清除现有媒体
        while list.count > 0 {
            list.removeMedia(at: 0)
        }

        // 创建新的媒体对象
        let media = VLCMedia(url: url)
        
        // 配置缓冲和网络选项
        media.addOptions([
            "network-caching": NSNumber(value: 3000), // 3秒缓冲
            "http-user-agent": "iOS Video Player/1.0",
            "http-reconnect": NSNumber(value: 1),
            "preload": NSNumber(value: 1) // 预加载
        ])
        
        media.parse()
        
        // 尝试直接获取时长（立即尝试）
        let initialLength = media.length.intValue
        if initialLength > 0 {
            self.duration = Double(initialLength) / 1000.0
            print("[初始解析] 立即获取到时长: \(self.duration)秒")
        }
        
        // 添加到媒体列表
        list.add(media)
        
        // 保存当前URL
        currentURL = url
        
        // 准备播放
        updateState(.loading)
        listPlayer.play()
        
        // 开始轮询获取时长
        startDurationPolling()
        
        // 立即尝试获取时长
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateTimeInfo()
        }
    }

    private func startDurationPolling() {
        // 先清除可能存在的轮询计时器
        stopDurationPolling()
        
        var pollingCount = 0
        let maxPollingCount = 50 // 增加到50次轮询
        let pollingInterval: TimeInterval = 0.3 // 缩短到0.3秒
        
        durationPollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] timer in
            guard let self = self, let listPlayer = self.vlcListPlayer else {
                timer.invalidate()
                return
            }
            
            pollingCount += 1
            
            // 尝试直接从mediaPlayer获取时长
            if let media = listPlayer.mediaPlayer.media {
                // 强制完全解析
                media.parse()
                
                let length = media.length.intValue
                if length > 0 {
                    self.duration = Double(length) / 1000.0
                    print("[轮询成功] 获取到有效时长: \(self.duration)秒 (第\(pollingCount)次)")
                    self.updateTimeInfo()
                    timer.invalidate()
                    return
                }
            }
            
            // 达到最大轮询次数，停止轮询
            if pollingCount >= maxPollingCount {
                print("[轮询超时] 无法获取有效时长")
                timer.invalidate()
            } else {
                // 只在调试时打印，避免日志过多
                if pollingCount % 5 == 0 {
                    print("[轮询中] 第\(pollingCount)次轮询，等待时长信息...")
                }
            }
        }

        // 确保定时器在RunLoop中运行
        if let timer = durationPollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopDurationPolling() {
        durationPollingTimer?.invalidate()
        durationPollingTimer = nil
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
        
        // 获取当前播放时间 - 使用直接的时间值获取
        let playerTime = mediaPlayer.time
        // 首先尝试使用intValue获取时间（更可靠的方法）
        let intValue = playerTime.intValue
        var currentTimeValue = Double(intValue) / 1000.0
        if currentTimeValue == 0 {
            if let timeValue = playerTime.value as? Double {
                currentTimeValue = timeValue / 1000.0
            }
        }
        // 如果仍然为0，尝试使用媒体的当前时间（作为最后备选）
        if currentTimeValue == 0, let media = mediaPlayer.media {
            let mediaCurrentTime = mediaPlayer.time.intValue
            currentTimeValue = Double(mediaCurrentTime) / 1000.0
        }
        
        self.currentTime = currentTimeValue

        // if let timeValue = playerTime.value as? Double {
        //     self.currentTime = timeValue / 1000.0
        // } else {
        //     // 对于非可选类型的intValue，直接使用
        //     let intValue = playerTime.intValue
        //     self.currentTime = Double(intValue) / 1000.0
        // }

        // 改进的时长获取逻辑，尝试多种方式
        var foundDuration: Double = 0
        
        // 方法1：使用media.length
        if let media = mediaPlayer.media {
            let length = media.length.intValue
            if length > 0 {
                foundDuration = Double(length) / 1000.0
                print("[方法] 更新时长: \(foundDuration)秒")
            }
        }
        
        // 只有获取到有效时长才更新，避免覆盖已有值
        if foundDuration > 0 {
            self.duration = foundDuration
        }
        
        // 计算进度
        self.progress = self.duration > 0 ? Float(self.currentTime / self.duration) : 0
        
        print("[更新时间] 当前时间: \(currentTime), 总时长: \(duration), 进度: \(progress)")
        
        // 触发更新回调
        onTimeUpdated?(self.currentTime)
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimeInfo()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        guard let player = vlcListPlayer?.mediaPlayer else { return }

        switch player.state {
        case .stopped:
            isPlaying = false
            updateState(.ended)
            stopTimer()

        case .playing:
            isPlaying = true
            updateState(.playing)
            startTimer()
            player.rate = playbackRate

            updateTimeInfo()

        case .paused:
            isPlaying = false
            updateState(.paused)

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

    // VLCMediaListPlayerDelegate方法
//    func mediaListPlayer(_ mediaListPlayer: VLCMediaListPlayer, didChange state: VLCMediaPlayerState) {
//        switch state {
//        case .stopped:
//            isPlaying = false
//            updateState(.ended)
//            stopTimer()
//        case .playing:
//            isPlaying = true
//            updateState(.playing)
//            startTimer()
//            mediaListPlayer.mediaPlayer.rate = playbackRate
//
//            // 播放开始时尝试更新时长
//            if let media = mediaListPlayer.mediaPlayer.media {
//                media.parse()
//                let length = media.length.intValue
//                if length > 0 {
//                    duration = Double(length) / 1000.0
//                    print("播放开始，更新时长: \(duration)秒")
//                }
//            }
//
//            updateTimeInfo()
//        case .paused:
//            isPlaying = false
//            updateState(.paused)
//            // stopTimer()
//            // 暂停时继续更新时间，这样用户可以看到当前播放位置·
//        case .ended:
//            isPlaying = false
//            updateState(.ended)
//            stopTimer()
//        case .error:
//            isPlaying = false
//            updateState(.error)
//            onError?(nil)
//            stopTimer()
//        default:
//            break
//        }
//    }
    
    func mediaListPlayer(_ mediaListPlayer: VLCMediaListPlayer, mediaPlayerTimeChanged currentTime: VLCTime, duration: VLCTime) {
        // 确保值有效再更新
        let currentTimeValue = Double(currentTime.intValue) / 1000.0
        let durationValue = Double(duration.intValue) / 1000.0
        
        // 只在获取到有效值时更新
        if currentTimeValue >= 0 {
            self.currentTime = currentTimeValue
        }
        
        if durationValue > 0 {
            self.duration = durationValue
        }
        
        // 计算进度
        self.progress = self.duration > 0 ? Float(self.currentTime / self.duration) : 0
        
        print("[代理更新] 当前时间: \(self.currentTime), 总时长: \(self.duration), 进度: \(self.progress)")
        
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
        stopDurationPolling() // 停止时长轮询
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
