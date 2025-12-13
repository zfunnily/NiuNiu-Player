//
//  PlayerEngine.swift
//  webdav
//
//  Created by ZQJ on 2025/11/26.
//

import Foundation
import UIKit

// 播放器状态枚举
enum PlayerState: Int {
    case idle = 0
    case loading = 1
    case playing = 2
    case paused = 3
    case ended = 4
    case error = 5
}


// 播放引擎协议
protocol PlayerEngine: AnyObject {
    // 播放控制方法
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func seek(to progress: Float)
    
    // 状态属性
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var progress: Float { get }
    
    // 配置方法
    func setupPlayer(on view: UIView)
    func setVideoURL(_ url: URL)
    func setVideoGravity(_ gravity: VideoGravity)
    func setVolume(_ volume: Float)
    func getVolume() -> Float
    func setLoopEnabled(_ isEnabled: Bool)
    
    // 回调设置
    var onStateChanged: ((PlayerState) -> Void)? { get set }
    var onTimeUpdated: ((TimeInterval) -> Void)? { get set }
    var onError: ((Error?) -> Void)? { get set }

    // 播放速度控制
    func setPlaybackRate(_ rate: Float)
    func getPlaybackRate() -> Float
    // 资源清理
    func cleanup()
}
