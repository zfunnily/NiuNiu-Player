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
    private var wasStatusBarHidden: Bool = false

    // 控制按钮
    private let playPauseButton = UIButton(type: .system)
    //进度条
    private let slider = UISlider()
    private let timeLabel = UILabel()
    private let durationLabel = UILabel()
    
    // 添加一个变量来跟踪进度条是否正在被拖动
    private var isSliderBeingDragged = false

    private let closeButton = UIButton(type: .system)
    private let aspectRatioButton = UIButton(type: .system)
    private let rotateButton = UIButton(type: .system)

    // 控制栏
    private let controlsContainer = UIView()
    private var isControlsVisible = true
    private var controlsTimer: Timer?
    // 添加进度条预览视图
    private let previewThumbnailView = UIView()
    private let previewLabel = UILabel()

    // 添加速度控制按钮
    private let speedButton = UIButton(type: .system)
    private var currentPlaybackRate: Float = 1.0
    private let playbackRates: [Float] = [-2.0, -1.0, 0.5, 1.0, 1.5, 2.0]
    private var timer: Timer?

    // 添加保存原始播放速度的变量，用于长按倍速功能
    private var originalPlaybackRate: Float = 1.0
    // 长按倍速的目标速度
    private let holdToSpeedUpRate: Float = 2.0
    // 长按手势识别器
    private var longPressGesture: UILongPressGestureRecognizer!
    private var speedHintLabel: UILabel?

    // 滑动手势相关属性
    private var panGesture: UIPanGestureRecognizer!
    private var initialTouchPosition: CGPoint = .zero
    private var initialPlaybackTime: TimeInterval = 0
    private var isSeeking = false
    private var seekHintLabel: UILabel?
    private let seekSensitivity: CGFloat = 2.0 // 滑动敏感度，值越大，滑动相同距离快进越多
    private let maxSeekSeconds: TimeInterval = 60 // 最大快进/快退秒数

    // 亮度和音量调节相关属性
    private var initialBrightness: Float = 0
    private var initialVolume: Float = 0
    private var brightnessHintLabel: UILabel?
    private var volumeHintLabel: UILabel?
    private let brightnessSensitivity: CGFloat = 0.001 // 亮度调节敏感度
    private let volumeSensitivity: CGFloat = 0.002 // 音量调节敏感度

    // 添加辅助属性
    private var isAdjustingBrightness = false
    private var isAdjustingVolume = false
    
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

         // 应用统一导航栏样式
        navigationController?.applyGlobalNavigationBarStyle()
        // 确保控制栏在视图层级的最顶层
        view.bringSubviewToFront(controlsContainer)
        playVideo()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        title = videoSource.name

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "退出",
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )

//        navigationItem.rightBarButtonItems = [
//            UIBarButtonItem(title: "全屏", style: .plain, target: self, action: #selector(rotateButtonTapped)),
//            UIBarButtonItem(title: "速度", style: .plain, target: self, action: #selector(speedButtonTapped))
//        ]

        // 确保导航栏初始可见
        navigationController?.setNavigationBarHidden(false, animated: false)
        isControlsVisible = true
        controlsContainer.alpha = 1.0
        controlsContainer.isHidden = false // 明确设置为不隐藏

        wasStatusBarHidden = UIApplication.shared.isStatusBarHidden
        UIApplication.shared.isStatusBarHidden = false

        // 保存原始方向
        originalOrientation = UIDevice.current.orientation
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // navigationController?.setNavigationBarHidden(false, animated: animated)

        UIApplication.shared.isStatusBarHidden = wasStatusBarHidden
        playerManager.cleanup()

        // 恢复原始方向
        if let orientation = originalOrientation {
            setDeviceOrientation(orientation)
        }

        // 移除方向监听
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        // 清理滑动手势相关资源
        hideSeekHint()
    }
    
    // 添加旋转支持
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait, .landscapeLeft, .landscapeRight]
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    private func setupOrientationObserver() {
        // 启用设备方向通知
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
            // 横屏时隐藏导航栏
            navigationController?.setNavigationBarHidden(true, animated: false)
            UIApplication.shared.isStatusBarHidden = true

            // 更新导航栏全屏按钮标题
            updateNavigationBarFullscreenButton()
        case .portrait, .portraitUpsideDown:
            isFullscreen = false
            // 恢复导航栏隐藏状态
            navigationController?.setNavigationBarHidden(true, animated: false)

            // 更新导航栏全屏按钮标题
            updateNavigationBarFullscreenButton()

            // // 竖屏时显示导航栏
            // navigationController?.setNavigationBarHidden(false, animated: true)
            // UIApplication.shared.isStatusBarHidden = false
        default:
            break
        }
        
        // 更新UI布局以适应新方向
        updatePlayerLayout()
        // 更新旋转按钮状态
        updateRotateButton()
    }
    
    // 新增：更新导航栏全屏按钮标题的方法
    private func updateNavigationBarFullscreenButton() {
        if let buttons = navigationItem.rightBarButtonItems, buttons.count >= 2 {
            buttons[0].title = isFullscreen ? "竖屏" : "全屏"
        }
    }

    private func setupUI() {
        view.backgroundColor = .black
        // title = videoSource.name
        
        // 设置控制栏
        setupControls()
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
        slider.minimumTrackTintColor = .systemBlue  // 设置已播放部分的颜色
        slider.maximumTrackTintColor = .white.withAlphaComponent(0.3)  // 设置未播放部分的颜色
        slider.thumbTintColor = .systemBlue  // 设置滑块颜色
        slider.isUserInteractionEnabled = true
        slider.isHidden = false

        // 添加拖动开始和结束的事件监听
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside])
        slider.addTarget(self, action: #selector(sliderTouchCancel), for: .touchCancel) // 添加取消事件
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

        // 初始化进度条预览视图
        previewThumbnailView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        previewThumbnailView.layer.cornerRadius = 8
        previewThumbnailView.clipsToBounds = true
        previewThumbnailView.isHidden = true
        previewThumbnailView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewThumbnailView)

        // 预览时间标签
        previewLabel.textColor = .white
        previewLabel.font = UIFont.systemFont(ofSize: 12)
        previewLabel.textAlignment = .center
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewThumbnailView.addSubview(previewLabel)

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

        NSLayoutConstraint.activate([
            previewLabel.centerXAnchor.constraint(equalTo: previewThumbnailView.centerXAnchor),
            previewLabel.centerYAnchor.constraint(equalTo: previewThumbnailView.centerYAnchor),
            previewThumbnailView.widthAnchor.constraint(equalToConstant: 80),
            previewThumbnailView.heightAnchor.constraint(equalToConstant: 40)
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

        // 添加长按手势实现按住加速播放
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.2 // 长按触发时间，单位秒
        longPressGesture.cancelsTouchesInView = false // 不取消其他手势
        view.addGestureRecognizer(longPressGesture)

        // 添加滑动手势实现快进快退
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        panGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func doubleTapToToggleFullscreen() {
        rotateButtonTapped()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            // 长按开始，保存当前播放速度并设置为倍速
            originalPlaybackRate = currentPlaybackRate
            currentPlaybackRate = holdToSpeedUpRate
            // 更新速度按钮显示
            speedButton.setTitle("\(holdToSpeedUpRate)x", for: .normal)
            // 设置播放速度
            playerManager.setPlaybackRate(currentPlaybackRate)
            
            // 可选：显示一个提示
            showSpeedHint(rate: holdToSpeedUpRate)
            
        case .ended, .cancelled, .failed:
            // 长按结束，恢复原始播放速度
            currentPlaybackRate = originalPlaybackRate
            // 更新速度按钮显示
            let sign = currentPlaybackRate < 0 ? "-" : ""
            let absRate = abs(currentPlaybackRate)
            speedButton.setTitle("\(sign)\(absRate)x", for: .normal)
            // 设置播放速度
            playerManager.setPlaybackRate(currentPlaybackRate)
            
            // 可选：隐藏提示
            hideSpeedHint()
            
        default:
            break
        }
    }
    private func showSpeedHint(rate: Float) {
        // 如果提示标签不存在，创建它
        if speedHintLabel == nil {
            speedHintLabel = UILabel()
            speedHintLabel?.textColor = .white
            speedHintLabel?.font = UIFont.boldSystemFont(ofSize: 36)
            speedHintLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            speedHintLabel?.layer.cornerRadius = 10
            speedHintLabel?.clipsToBounds = true
            speedHintLabel?.textAlignment = .center
            speedHintLabel?.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(speedHintLabel!)
            
            // 设置约束
            NSLayoutConstraint.activate([
                speedHintLabel!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                speedHintLabel!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                speedHintLabel!.paddingHorizontal(constant: 30),
                speedHintLabel!.paddingVertical(constant: 15)
            ])
            
            // 初始隐藏
            speedHintLabel?.alpha = 0
        }
        
        // 设置文本
        speedHintLabel?.text = "\(rate)x"
        
        // 显示动画
        UIView.animate(withDuration: 0.3) {
            self.speedHintLabel?.alpha = 1.0
        }
    }
    
    private func hideSpeedHint() {
        UIView.animate(withDuration: 0.3) {
            self.speedHintLabel?.alpha = 0.0
        }
    }

    private func updatePlayerLayout() {
        // 重新布局播放器以适应新的屏幕方向
        // 由于PlayerManager将播放器层添加到视图上，我们需要确保它能正确调整大小
        UIView.animate(withDuration: 0.3) {
            // 强制布局更新
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    @objc private func rotateButtonTapped() {
        // 切换全屏/非全屏
        if isFullscreen {
            // 切换回竖屏
            setDeviceOrientation(.portrait)
        } else {
            // 切换到横屏
            setDeviceOrientation(.landscapeRight)
        }
        resetControlsTimer()
    }
    
    // 安全地设置设备方向
    private func setDeviceOrientation(_ orientation: UIDeviceOrientation) {
        // 立即更新UI状态
        isFullscreen = orientation.isLandscape
        updateRotateButton()
        updateNavigationBarFullscreenButton() // 更新导航栏按钮
        updatePlayerLayout()
        
        // 根据iOS版本使用不同的方法
        if #available(iOS 16.0, *) {
            // iOS 16及以上版本使用推荐的方法
            if let windowScene = view.window?.windowScene {
                var targetInterfaceOrientation: UIInterfaceOrientationMask
                
                switch orientation {
                case .landscapeLeft:
                    targetInterfaceOrientation = .landscapeLeft
                case .landscapeRight:
                    targetInterfaceOrientation = .landscapeRight
                case .portrait:
                    targetInterfaceOrientation = .portrait
                case .portraitUpsideDown:
                    targetInterfaceOrientation = .portraitUpsideDown
                default:
                    targetInterfaceOrientation = .portrait
                }
                
                // 创建旋转偏好设置
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: targetInterfaceOrientation)
                
                // 请求几何更新
                windowScene.requestGeometryUpdate(geometryPreferences) { error in
                    if error != nil {
                        DLog("屏幕旋转失败: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // iOS 16以下版本使用旧方法
            DispatchQueue.main.async {
                // 在Swift中忽略弃用警告的方式
                if #available(iOS 16.0, *) {
                    // iOS 16+ 已经在上面处理了
                } else {
                    // 直接设置方向，使用@discardableResult或者其他方式处理警告
                    UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
                }
            }
        }
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
                // 确保控制栏初始可见，不自动隐藏
                if let self = self {
                    self.isControlsVisible = true
                    self.controlsContainer.alpha = 1.0
                    if let navigationController = self.navigationController {
                        navigationController.setNavigationBarHidden(false, animated: false)
                    }
                    // 可选：如果选择禁用自动隐藏，则不重置定时器
                    // self.resetControlsTimer() // 注释掉这行可以完全禁用自动隐藏
                }
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
        // 先销毁旧的定时器
        timer?.invalidate()
        
        // 创建新的定时器
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateProgress()
        }
        
        // 添加到主运行循环
        RunLoop.main.add(timer!, forMode: .common)
        
        // 立即更新一次进度
        DispatchQueue.main.async {
            self.updateProgress()
        }
    }

    deinit {
        timer?.invalidate()
    }
    
    private func updateProgress() {
        // 如果用户正在拖动滑块，不更新进度条位置
        if isSliderBeingDragged {
            return
        }
        
        let currentTime = PlayerManager.shared.getCurrentTime()
        let duration = PlayerManager.shared.getDuration()
        
        // 添加调试信息
        DLog("更新进度 - 当前时间: \(currentTime), 总时长: \(duration)")
        
        if duration > 0 {
            slider.value = Float(currentTime / duration)
            timeLabel.text = formatTime(Double(slider.value) * duration)
            durationLabel.text = formatTime(duration)
            
            // 如果控制栏应该可见但被隐藏了，重新显示它
            if isControlsVisible && controlsContainer.isHidden {
                controlsContainer.isHidden = false
                controlsContainer.alpha = 1.0
            }
        } else {
            // 时长为0时的处理
            DLog("警告：视频时长为0，可能媒体尚未加载完成")
            // 保持现有显示，不更新进度条
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
    
    @objc private func toggleControls() {
        self.isControlsVisible.toggle()

        view.bringSubviewToFront(controlsContainer)

         // 使用动画平滑过渡
        UIView.animate(withDuration: 0.3) {
            // 先设置 alpha，最后设置 isHidden
            self.controlsContainer.alpha = self.isControlsVisible ? 1.0 : 0.0
            
            // 导航栏的显隐
            if let navigationController = self.navigationController {
                navigationController.setNavigationBarHidden(!self.isControlsVisible, animated: true)
            }
        } completion: { [weak self] _ in
            guard let self = self else { return }
            // 动画完成后再设置 isHidden，避免状态不一致
            self.controlsContainer.isHidden = !self.isControlsVisible
        }
        
        // 如果显示了控制栏，重置自动隐藏计时器
        if isControlsVisible {
            resetControlsTimer()
        }
    }

    private func scheduleHideControls() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying {
                self.isControlsVisible = false
                UIView.animate(withDuration: 0.3) {
                    self.controlsContainer.alpha = 0
                    self.controlsContainer.isHidden = true
                    // 同步隐藏导航栏
                    if let navigationController = self.navigationController {
                        navigationController.setNavigationBarHidden(true, animated: true)
                    }
                }
            }
        }

        // 方案2：完全禁用自动隐藏（注释掉上面的代码，取消注释下面的代码）
        // controlsTimer?.invalidate() // 只取消定时器，不创建新的
    }

    private func hideControls() {
        if isControlsVisible {
            isControlsVisible = false
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self = self else { return }
                self.controlsContainer.alpha = 0.0
                if let navigationController = self.navigationController {
                    navigationController.setNavigationBarHidden(true, animated: true)
                }
            } completion: { [weak self] _ in
                guard let self = self else { return }
                // 动画完成后再设置 isHidden
                self.controlsContainer.isHidden = true
            }
        }
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
    
        if isControlsVisible {
            controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.hideControls()
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
    
    @objc private func sliderTouchBegan() {
        // 当用户开始拖动滑块时，暂停进度更新
        isSliderBeingDragged = true
        // 暂停视频播放，以便用户精确定位
        playerManager.pause()
        isPlaying = false
        updatePlayPauseButton()
    }
    
    @objc private func sliderTouchEnded() {
        // 当用户停止拖动滑块时，恢复进度更新
        isSliderBeingDragged = false
        
        // 获取视频总时长
        let duration = PlayerManager.shared.getDuration()
        
        // 计算绝对时间：相对值 × 总时长
        let seekTime = Double(slider.value) * duration
        
        // 确保时长有效
        if duration > 0 {
            // 明确调用接受TimeInterval参数的seek方法
            playerManager.seek(to: seekTime)
            
            DLog("拖动进度条到：\(seekTime)秒，总时长：\(duration)秒")
        } else {
            DLog("警告：视频时长无效，无法定位")
        }
        
        // 继续播放
        playerManager.play()
        isPlaying = true
        updatePlayPauseButton()
        resetControlsTimer()
        
        updateProgress()
        // 隐藏预览
        previewThumbnailView.isHidden = true
    }

    @objc private func sliderTouchCancel() {
        // 当拖动被取消时，恢复进度更新
        isSliderBeingDragged = false
        // 隐藏预览
        previewThumbnailView.isHidden = true
    }
    
    @objc private func sliderValueChanged() {
        // 计算当前预览时间
        let duration = PlayerManager.shared.getDuration()
        let seekTime = Double(slider.value) * duration

        // 添加调试日志
        DLog("拖动滑块到位置：\(slider.value)，对应时间：\(seekTime)秒")

        // 更新预览
        updatePreview(at: seekTime)
    }

    private func updatePreview(at time: Double) {
        // 更新预览标签
        previewLabel.text = formatTime(time)
        
        // 计算预览视图的位置（在进度条上方）
        let sliderFrame = slider.frame
        let touchPointX = CGFloat(slider.value) * sliderFrame.width + sliderFrame.origin.x
        
        // 调整预览视图位置，确保不超出屏幕
        var previewX = touchPointX - previewThumbnailView.bounds.width / 2
        let screenWidth = view.bounds.width
        
        if previewX < 16 {
            previewX = 16
        } else if previewX + previewThumbnailView.bounds.width > screenWidth - 16 {
            previewX = screenWidth - 16 - previewThumbnailView.bounds.width
        }
        
        // 设置位置
        previewThumbnailView.frame.origin.x = previewX
        previewThumbnailView.frame.origin.y = sliderFrame.origin.y - previewThumbnailView.bounds.height - 10
        
        // 显示预览
        previewThumbnailView.isHidden = false
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

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let currentPosition = gesture.location(in: view)
        let translation = gesture.translation(in: view)
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        
        switch gesture.state {
        case .began:
            // 开始滑动，只记录初始位置和参数
            initialTouchPosition = currentPosition
            initialPlaybackTime = playerManager.getCurrentTime()
            initialBrightness = Float(UIScreen.main.brightness)
            initialVolume = playerManager.getVolume()
            
            // 重置所有状态标志
            isSeeking = false
            isAdjustingBrightness = false
            isAdjustingVolume = false
            
        case .changed:
            if !isSeeking && !isAdjustingBrightness && !isAdjustingVolume {
                // 第一次检测到滑动，确定滑动类型
                if abs(translation.x) > abs(translation.y) {
                    // 水平滑动，处理快进快退
                    isSeeking = true
                    showSeekHint(seconds: 0)
                } else {
                    // 垂直滑动，处理亮度或音量
                    if currentPosition.x < screenWidth / 2 {
                        // 左边屏幕，调节亮度
                        isAdjustingBrightness = true
                        showBrightnessHint(brightness: initialBrightness)
                    } else {
                        // 右边屏幕，调节音量
                        isAdjustingVolume = true
                        showVolumeHint(volume: initialVolume)
                    }
                }
            }
            
            if isSeeking {
                // 计算滑动距离（只考虑水平方向）
                let horizontalDistance = translation.x
                let screenRatio = abs(horizontalDistance) / screenWidth
                
                // 根据滑动距离计算快进/快退的秒数
                var seekSeconds = screenRatio * seekSensitivity * maxSeekSeconds
                seekSeconds = min(seekSeconds, maxSeekSeconds) // 限制最大快进/快退秒数
                
                // 根据滑动方向确定是快进还是快退
                if horizontalDistance < 0 {
                    seekSeconds = -seekSeconds // 向左滑动是快退
                }
                
                // 计算新的播放时间
                var newTime = initialPlaybackTime + seekSeconds
                let duration = playerManager.getDuration()
                
                // 确保不超出视频范围
                newTime = max(0, min(newTime, duration))
                
                // 更新快进/快退提示
                showSeekHint(seconds: seekSeconds)
                
                // 实时更新播放位置
                playerManager.seek(to: newTime)
            } else if isAdjustingBrightness {
                // 调节亮度
                let verticalDistance = translation.y
                let brightnessChange = -verticalDistance * brightnessSensitivity
                var newBrightness = initialBrightness + Float(brightnessChange)
                
                // 限制亮度范围在0.0-1.0之间
                newBrightness = max(0.0, min(1.0, newBrightness))
                
                // 更新屏幕亮度
                UIScreen.main.brightness = CGFloat(newBrightness)
                
                // 更新亮度提示
                showBrightnessHint(brightness: newBrightness)
            } else if isAdjustingVolume {
                // 调节音量
                let verticalDistance = translation.y
                let volumeChange = -verticalDistance * volumeSensitivity
                var newVolume = initialVolume + Float(volumeChange)
                
                // 限制音量范围在0.0-1.0之间
                newVolume = max(0.0, min(1.0, newVolume))
                
                // 更新音量
                playerManager.setVolume(newVolume)
                
                // 更新音量提示
                showVolumeHint(volume: newVolume)
            }
            
        case .ended, .cancelled, .failed:
            // 滑动结束，隐藏提示
            if isSeeking {
                hideSeekHint()
                isSeeking = false
            } else if isAdjustingBrightness {
                hideBrightnessHint()
                isAdjustingBrightness = false
            } else if isAdjustingVolume {
                hideVolumeHint()
                isAdjustingVolume = false
            }
            
        default:
            break
        }
    }

    private func showBrightnessHint(brightness: Float) {
        // 如果提示标签不存在，创建它
        if brightnessHintLabel == nil {
            brightnessHintLabel = UILabel()
            brightnessHintLabel?.textColor = .white
            brightnessHintLabel?.font = UIFont.boldSystemFont(ofSize: 36)
            brightnessHintLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            brightnessHintLabel?.layer.cornerRadius = 10
            brightnessHintLabel?.clipsToBounds = true
            brightnessHintLabel?.textAlignment = .center
            brightnessHintLabel?.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(brightnessHintLabel!)
            
            // 设置约束（左上角）
            NSLayoutConstraint.activate([
                brightnessHintLabel!.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
                brightnessHintLabel!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
                brightnessHintLabel!.paddingHorizontal(constant: 30),
                brightnessHintLabel!.paddingVertical(constant: 15)
            ])
            
            // 初始隐藏
            brightnessHintLabel?.alpha = 0
        }
        
        // 设置提示文本（亮度百分比）
        let brightnessPercentage = Int(brightness * 100)
        brightnessHintLabel?.text = "🌞 \(brightnessPercentage)%"
        
        // 显示动画
        UIView.animate(withDuration: 0.3) {
            self.brightnessHintLabel?.alpha = 1.0
        }
    }


    private func showSeekHint(seconds: TimeInterval) {
    // 如果提示标签不存在，创建它
    if seekHintLabel == nil {
        seekHintLabel = UILabel()
        seekHintLabel?.textColor = .white
        seekHintLabel?.font = UIFont.boldSystemFont(ofSize: 36)
        seekHintLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        seekHintLabel?.layer.cornerRadius = 10
        seekHintLabel?.clipsToBounds = true
        seekHintLabel?.textAlignment = .center
        seekHintLabel?.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(seekHintLabel!)
        
        // 设置约束
        NSLayoutConstraint.activate([
            seekHintLabel!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            seekHintLabel!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            seekHintLabel!.paddingHorizontal(constant: 30),
            seekHintLabel!.paddingVertical(constant: 15)
        ])
        
        // 初始隐藏
        seekHintLabel?.alpha = 0
    }
    
    // 设置提示文本
    let sign = seconds > 0 ? "→" : "←"
    let absSeconds = abs(seconds)
    let minutes = Int(absSeconds / 60)
    let remainingSeconds = Int(absSeconds) % 60
    if minutes > 0 {
        seekHintLabel?.text = "\(sign) \(minutes):\(remainingSeconds < 10 ? "0" : "")\(remainingSeconds)"
    } else {
        seekHintLabel?.text = "\(sign) \(remainingSeconds)s"
    }
    
    // 设置文本颜色（快进为绿色，快退为红色）
    seekHintLabel?.textColor = seconds > 0 ? .green : .red
    
    // 显示动画
    UIView.animate(withDuration: 0.3) {
        self.seekHintLabel?.alpha = 1.0
    }
}

    private func hideSeekHint() {
        UIView.animate(withDuration: 0.3) {
            self.seekHintLabel?.alpha = 0.0
        }
    }

    private func showVolumeHint(volume: Float) {
        // 如果提示标签不存在，创建它
        if volumeHintLabel == nil {
            volumeHintLabel = UILabel()
            volumeHintLabel?.textColor = .white
            volumeHintLabel?.font = UIFont.boldSystemFont(ofSize: 36)
            volumeHintLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            volumeHintLabel?.layer.cornerRadius = 10
            volumeHintLabel?.clipsToBounds = true
            volumeHintLabel?.textAlignment = .center
            volumeHintLabel?.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(volumeHintLabel!)
            
            // 设置约束（右上角）
            NSLayoutConstraint.activate([
                volumeHintLabel!.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
                volumeHintLabel!.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
                volumeHintLabel!.paddingHorizontal(constant: 30),
                volumeHintLabel!.paddingVertical(constant: 15)
            ])
            
            // 初始隐藏
            volumeHintLabel?.alpha = 0
        }
        
        // 设置提示文本（音量百分比）
        let volumePercentage = Int(volume * 100)
        volumeHintLabel?.text = "🔊 \(volumePercentage)%"
        
        // 显示动画
        UIView.animate(withDuration: 0.3) {
            self.volumeHintLabel?.alpha = 1.0
        }
    }

    private func hideBrightnessHint() {
        UIView.animate(withDuration: 0.3) {
            self.brightnessHintLabel?.alpha = 0.0
        }
    }

    private func hideVolumeHint() {
        UIView.animate(withDuration: 0.3) {
            self.volumeHintLabel?.alpha = 0.0
        }
    }
}

fileprivate extension UIView {
    func paddingHorizontal(constant: CGFloat) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: self, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: constant * 2)
    }
    
    func paddingVertical(constant: CGFloat) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: self, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: constant * 2)
    }
}

// 扩展数组以安全访问元素
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
