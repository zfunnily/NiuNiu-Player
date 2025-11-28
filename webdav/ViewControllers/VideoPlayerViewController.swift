//
//  VideoPlayerViewController.swift
//  webdav
//

import UIKit
import AVFoundation

// 屏幕长宽比枚举
enum VideoGravity: String, CaseIterable {
    case resizeAspect = "保持比例"
    case resizeAspectFill = "填充"
    case resize = "拉伸"
    
    var avLayerVideoGravity: AVLayerVideoGravity {
        switch self {
        case .resizeAspect:
            return .resizeAspect
        case .resizeAspectFill:
            return .resizeAspectFill
        case .resize:
            return .resize
        }
    }
}

class VideoPlayerViewController: UIViewController {
    
    private let videoSource: VideoSource
    private let playerManager = PlayerManager.shared
    private var isPlaying = false
    
    private var currentVideoGravity: VideoGravity = .resizeAspectFill
    private var isFullscreen: Bool = false
    private var originalOrientation: UIDeviceOrientation?

    // 控制按钮
    private let playPauseButton = UIButton(type: .system)
    private let slider = UISlider()
    private let timeLabel = UILabel()
    private let durationLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let aspectRatioButton = UIButton(type: .system)
    private let rotateButton = UIButton(type: .system)

    // 控制栏
    private let controlsContainer = UIView()
    private var isControlsVisible = true
    private var controlsTimer: Timer?

    // 添加速度控制按钮
    private let speedButton = UIButton(type: .system)
    private var currentPlaybackRate: Float = 1.0
    private let playbackRates: [Float] = [-2.0, -1.0, 0.5, 1.0, 1.5, 2.0]
    private var timer: Timer?
    
    init(videoSource: VideoSource) {
        self.videoSource = videoSource
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupOrientationObserver()
        playVideo()
    }
    
      override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // 保存原始方向
        originalOrientation = UIDevice.current.orientation
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        playerManager.cleanup()
        // 恢复原始方向
        if let orientation = originalOrientation {
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        }
        // 移除方向监听
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    // 添加旋转支持
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    private func setupOrientationObserver() {
        // 监听设备方向变化
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleOrientationChange),
                                           name: UIDevice.orientationDidChangeNotification,
                                           object: nil)
    }
    
    @objc private func handleOrientationChange() {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            isFullscreen = true
        case .portrait, .portraitUpsideDown:
            isFullscreen = false
        default:
            break
        }
        // 更新旋转按钮状态
        updateRotateButton()
    }
    
    
    private func setupUI() {
        view.backgroundColor = .black
        title = videoSource.name
        
        // 设置控制栏
        setupControls()
        
        // 设置关闭按钮
        closeButton.setTitle("退出", for: .normal)
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        
        // 设置约束
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupControls() {
        // 控制容器
        controlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(controlsContainer)
        
        // 播放/暂停按钮
        playPauseButton.setTitle("暂停", for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        controlsContainer.addSubview(playPauseButton)
        
        // 屏幕旋转按钮
        rotateButton.setTitle("全屏", for: .normal)
        rotateButton.tintColor = .white
        rotateButton.addTarget(self, action: #selector(rotateButtonTapped), for: .touchUpInside)
        controlsContainer.addSubview(rotateButton)
        
        // 长宽比按钮
        aspectRatioButton.setTitle("填充", for: .normal)
        aspectRatioButton.tintColor = .white
        aspectRatioButton.addTarget(self, action: #selector(aspectRatioButtonTapped), for: .touchUpInside)
        controlsContainer.addSubview(aspectRatioButton)

        // 进度条
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.tintColor = .white
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        controlsContainer.addSubview(slider)
        
        // 时间标签
        timeLabel.textColor = .white
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.text = "0:00"
        controlsContainer.addSubview(timeLabel)
        
        // 总时长标签
        durationLabel.textColor = .white
        durationLabel.font = UIFont.systemFont(ofSize: 12)
        durationLabel.text = "0:00"
        controlsContainer.addSubview(durationLabel)

        // 添加速度控制按钮
        speedButton.setTitle("1.0x", for: .normal)
        speedButton.tintColor = .white
        speedButton.addTarget(self, action: #selector(speedButtonTapped), for: .touchUpInside)
        controlsContainer.addSubview(speedButton)

        // 设置约束
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        // 控制按钮约束
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playPauseButton.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 16),
            playPauseButton.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 16),
            playPauseButton.widthAnchor.constraint(equalToConstant: 60),
            playPauseButton.heightAnchor.constraint(equalToConstant: 30)
        ])
         
        // 旋转按钮约束
        rotateButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rotateButton.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 16),
            rotateButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 16),
            rotateButton.widthAnchor.constraint(equalToConstant: 60),
            rotateButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // 长宽比按钮约束
        aspectRatioButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            aspectRatioButton.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 16),
            aspectRatioButton.leadingAnchor.constraint(equalTo: rotateButton.trailingAnchor, constant: 16),
            aspectRatioButton.widthAnchor.constraint(equalToConstant: 60),
            aspectRatioButton.heightAnchor.constraint(equalToConstant: 30)
        ])
               
        // 进度条约束
        slider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            slider.topAnchor.constraint(equalTo: playPauseButton.bottomAnchor, constant: 8),
            slider.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -16)
        ])
        
        // 时间标签约束
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timeLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 16)
        ])
        
        // 总时长标签约束
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            durationLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4),
            durationLabel.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -16)
        ])

        // 速度按钮约束
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            speedButton.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 16),
            speedButton.leadingAnchor.constraint(equalTo: aspectRatioButton.trailingAnchor, constant: 16),
            speedButton.widthAnchor.constraint(equalToConstant: 60),
            speedButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupGestures() {
        // 点击手势显示/隐藏控制栏
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        view.addGestureRecognizer(tapGesture)
        
        // 双击切换全屏
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapToToggleFullscreen))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
        
        // 设置手势优先级
        tapGesture.require(toFail: doubleTapGesture)
    }
    
    @objc private func doubleTapToToggleFullscreen() {
        rotateButtonTapped()
    }
    
    @objc private func rotateButtonTapped() {
        // 切换全屏/非全屏
        if isFullscreen {
            // 切换回竖屏
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        } else {
            // 切换到横屏
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        }
        resetControlsTimer()
    }
    
    private func updateRotateButton() {
        rotateButton.setTitle(isFullscreen ? "竖屏" : "全屏", for: .normal)
    }
    
    @objc private func aspectRatioButtonTapped() {
        // 切换下一个长宽比
        let allGravities: [VideoGravity] = [.resizeAspect, .resizeAspectFill, .resize]
        if let currentIndex = allGravities.firstIndex(of: currentVideoGravity),
           currentIndex < allGravities.count - 1 {
            currentVideoGravity = allGravities[currentIndex + 1]
        } else {
            currentVideoGravity = allGravities[0]
        }
        updateVideoGravity()
        resetControlsTimer()
    }

    private func updateVideoGravity() {
        // 更新按钮标题
        switch currentVideoGravity {
        case .resizeAspect:
            aspectRatioButton.setTitle("保持比例", for: .normal)
        case .resizeAspectFill:
            aspectRatioButton.setTitle("填充", for: .normal)
        case .resize:
            aspectRatioButton.setTitle("拉伸", for: .normal)
        }
        
        // 更新播放器图层的视频重力属性
        PlayerManager.shared.updateVideoGravity(currentVideoGravity)
    }
        
    private func playVideo() {
        let configuration = PlayerConfiguration(autoPlay: true, loopEnabled: false)
        
        playerManager.playVideo(
            from: videoSource,
            onViewController: self,
            configuration: configuration,
            onSuccess: { [weak self] in
                self?.setupProgressUpdate()
            },
            onFailure: { [weak self] error in
                let errorMessage = error?.localizedDescription ?? "无法播放视频"
                self?.showError(errorMessage)
            },
            onPlaybackStateChanged: { [weak self] isPlaying in
                self?.isPlaying = isPlaying
                self?.updatePlayPauseButton()
            }
        )
    }
    
    private func setupProgressUpdate() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    deinit {
        timer?.invalidate()
    }
    
    private func updateProgress() {
        let currentTime = PlayerManager.shared.getCurrentTime()
        let duration = PlayerManager.shared.getDuration()
        
        if duration > 0 {
            slider.value = Float(currentTime / duration)
            timeLabel.text = formatTime(currentTime)
            durationLabel.text = formatTime(duration)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func updatePlayPauseButton() {
        playPauseButton.setTitle(isPlaying ? "暂停" : "播放", for: .normal)
    }
    
// 确保退出按钮一直可见，不随控制栏隐藏
    @objc private func toggleControls() {
        // 切换播放/暂停状态
        if isPlaying {
            playerManager.pause()
        } else {
            playerManager.play()
        }
        
        // 确保控制栏可见
        if !isControlsVisible {
            isControlsVisible = true
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self = self else { return }
                self.controlsContainer.alpha = 1.0
            }
        }
        
        // 重置自动隐藏计时器
        resetControlsTimer()
    }
    private func hideControls() {
        if isControlsVisible {
            isControlsVisible = false
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self = self else { return }
                self.controlsContainer.alpha = 0.0
                // 移除closeButton的alpha变化
                // self.closeButton.alpha = 0.0
            }
        }
    }


    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()

        if isControlsVisible {
            controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.hideControls()
            }
            RunLoop.current.add(controlsTimer!, forMode: .common)
        }
    }
    
    
    // 确保playPauseTapped方法正确工作
    @objc private func playPauseTapped() {
        if isPlaying {
            playerManager.pause()
        } else {
            playerManager.play()
        }
        resetControlsTimer()
    }
    
    @objc private func sliderValueChanged() {
        playerManager.seek(to: Double(slider.value))
        resetControlsTimer()
    }
    
    // 速度控制按钮点击事件
    @objc private func speedButtonTapped() {
        // 循环切换播放速度
        if let currentIndex = playbackRates.firstIndex(of: currentPlaybackRate),
           currentIndex < playbackRates.count - 1 {
            currentPlaybackRate = playbackRates[currentIndex + 1]
        } else {
            currentPlaybackRate = playbackRates[0]
        }
        
        // 更新按钮标题
        let sign = currentPlaybackRate < 0 ? "-" : ""
        let absRate = abs(currentPlaybackRate)
        speedButton.setTitle("\(sign)\(absRate)x", for: .normal)
        
        // 设置播放速度
        playerManager.setPlaybackRate(currentPlaybackRate)
        
        resetControlsTimer()
    }
    
    @objc private func closeButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func showError(_ message: String) {
        resetPlayerState()
        let alert = UIAlertController(title: "播放错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
    private func resetPlayerState() {
        isPlaying = false
        updatePlayPauseButton()
        // 可选：重置进度条
        slider.value = 0
        timeLabel.text = "0:00"
        // 可选：取消自动隐藏计时器
        controlsTimer?.invalidate()
    }

}

// 扩展数组以安全访问元素
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
