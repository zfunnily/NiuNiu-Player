//
//  WebDAVFileBrowserViewController.swift
//  webdav
//
//  Created by ZQJ on 2025/11/20.
//

import UIKit
import AVFoundation

class WebDAVFileBrowserViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let provider: WebDAVProvider
    private let tableView = UITableView()
    private var items: [WebDAVItem] = []
    private var currentPath: String
    private let client: WebDAVClient?
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private var navigationHistory: [String] = [] // 存储导航历史
    private var lastSuccessfulPath: String = "/"  // 最后一次成功访问的路径
    
    init(provider: WebDAVProvider, initPath: String = "/") {
        self.provider = provider
        self.currentPath = initPath
        self.client = ProviderManager.shared.createClient(for: provider)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = provider.name
        setupUI()
        setupNavigationBar()
        loadDirectoryContents()

         // 应用统一导航栏样式
        navigationController?.applyGlobalNavigationBarStyle()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // // 设置返回按钮
        // navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        
        // 设置表格视图
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        // 设置加载指示器
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        
        // 添加到视图
        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        
        // 设置约束
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    private func setupNavigationBar() {
        // title = "文件浏览"
        
        // 添加返回上一层按钮
        updateBackButton()
        
        // 可以添加其他导航栏按钮，如下拉刷新等
    }
    
    // MARK: - 导航功能
    
    // 更新返回上一层按钮的可用性
    private func updateBackButton() {
        // 检查是否可以返回上一层（当前路径不是根路径）
        let canGoBack = !isRootPath(currentPath)
        
        // 如果是根路径，使用系统返回按钮
        if canGoBack {
            // 创建返回上一层按钮
            let backButton = UIBarButtonItem(title: "上级", style: .plain, target: self, action: #selector(goBackToParent))
            backButton.isEnabled = canGoBack
            
            navigationItem.leftBarButtonItem = backButton
        } else {
            // 根路径时使用系统默认返回按钮
            navigationItem.leftBarButtonItem = nil
            navigationItem.hidesBackButton = false
        }
    }
    
    // 检查是否是根路径
    private func isRootPath(_ path: String) -> Bool {
        return path == "/" || path.isEmpty
    }
    
    // 为导航栏格式化显示路径
    private func displayPathForNavigationBar(_ path: String) -> String {
        if isRootPath(path) {
            return "根目录"
        }
        
        // 只显示路径的最后一部分，保持导航栏简洁
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        return components.last ?? "根目录"
    }
    
    // 核心功能：返回上一层目录
    @objc private func goBackToParent() {
        guard !isRootPath(currentPath) else { return }
        
        // 保存当前路径到历史记录，用于前进功能（如果需要）
        navigationHistory.append(currentPath)
        
        // 计算父目录路径
        let parentPath = getParentDirectoryPath(currentPath)
        
        // 加载父目录内容
        navigateToPath(parentPath)
    }
    
    // 计算父目录路径
    private func getParentDirectoryPath(_ path: String) -> String {
        // 移除末尾可能的斜杠
        var cleanPath = path
        if cleanPath.hasSuffix("/") && cleanPath.count > 1 {
            cleanPath = String(cleanPath.dropLast())
        }
        
        // 分割路径组件
        let components = cleanPath.components(separatedBy: "/").filter { !$0.isEmpty }
        
        // 如果只有一个组件，父目录就是根目录
        if components.count <= 1 {
            return "/"
        }
        
        // 移除最后一个组件，重新组合成父目录路径
        let parentComponents = components.dropLast()
        return "/" + parentComponents.joined(separator: "/")
    }
    
    // 导航到指定路径
    private func navigateToPath(_ path: String) {
        currentPath = path
        
        // 更新导航栏
        updateBackButton()
        
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        activityIndicator.startAnimating()
        
        // 加载目录内容
        loadDirectoryContents {
            // 加载完成后移除加载指示器
            DispatchQueue.main.async {
                self.navigationItem.rightBarButtonItem = nil
            }
        }
    }
    
    // 显示路径选择器（可选功能）
    @objc private func showPathSelector() {
        // 这里可以实现一个路径选择器，显示完整路径层级供用户选择
        // 简单实现可以是一个ActionSheet或AlertController
        let alert = UIAlertController(title: "当前路径", message: currentPath, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func loadDirectoryContents(completion: (() -> Void)? = nil) {
        guard let client = client else { return }
        
        activityIndicator.startAnimating()
        let curPath: String = currentPath
        
        client.listContents(at: currentPath) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                switch result {
                case .success(let items):
                    self?.lastSuccessfulPath = curPath
                    self?.items = items
                    self?.tableView.reloadData()
                    self?.updateBackButton()
                case .failure(let error):
                    
                    self?.showError(error.localizedDescription)
                    self?.recoverToLastSuccessfulPath(with: error)
                }
                
                // 调用完成回调
                completion?()
            }
        }
    }
    // 恢复到最后成功的路径
    private func recoverToLastSuccessfulPath(with error: Error) {
        // 如果当前路径和最后成功路径不同，尝试恢复
        if currentPath != lastSuccessfulPath {
            // 保存错误信息用于显示
            let errorMessage = "访问目录失败: \(error.localizedDescription)"
            
            // 更新当前路径为最后成功的路径
            currentPath = lastSuccessfulPath
            
            // 重新加载最后成功的路径内容
            currentPath = self.lastSuccessfulPath
            loadDirectoryContents()
            
            // 显示恢复提示
            showRecoveryMessage("已自动恢复到之前的目录")
        } else {
            // 如果最后成功的路径也失败了，显示错误
//            showErrorView(with: error)
        }
    }
    // 显示恢复消息
    private func showRecoveryMessage(_ message: String) {
        let alert = UIAlertController(title: "目录恢复", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - TableView 代理方法
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = items[indexPath.row]
        
        cell.textLabel?.text = item.name
        cell.accessoryType = item.type == WebDAVItemType.directory ? .disclosureIndicator : .none
        
        // 设置图标
        let iconName = item.type == WebDAVItemType.directory ? "folder.fill" : "doc.fill"
        cell.imageView?.image = UIImage(systemName: iconName)
        
        return cell
    }
    
    // 在tableView(_:didSelectRowAt:)方法中修改文件点击处理逻辑
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = items[indexPath.row]
        if item.type == WebDAVItemType.directory {
            // 进入子目录
            currentPath = item.path
            title = item.name
            loadDirectoryContents()
        } else {
            // 检查是否是视频文件
            if isVideoFile(item.name) {
                // 播放视频
                playVideo(item)
            } else {
                // 处理其他文件（下载）
                downloadFile(item)
            }
        }
    }

    // 添加辅助方法检查是否是视频文件
    private func isVideoFile(_ fileName: String) -> Bool {
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"]
        let fileExtension = fileName.lowercased().components(separatedBy: ".").last ?? ""
        return videoExtensions.contains(fileExtension)
    }

    // 添加播放视频方法
    private func playVideo(_ item: WebDAVItem) {
        // 创建WebDAV视频源
        guard let baseURL = client?.baseURL else { return }
        
        let videoSource = WebDAVVideoSource(
            baseURL: baseURL,
            filePath: item.path,
            username: client?.username,
            password: client?.password,
            name: item.name
        )
        
        // 创建并推送视频播放器视图控制器
        let playerVC = VideoPlayerViewController(videoSource: videoSource)
        navigationController?.pushViewController(playerVC, animated: true)
    }
    
    private func downloadFile(_ item: WebDAVItem) {
        guard let client = client else { return }
        
        let alert = UIAlertController(title: "下载文件", message: "确定要下载 \(item.name) 吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "下载", style: .default) { [weak self] _ in
            self?.activityIndicator.startAnimating()
            let path = (self?.currentPath ?? "")
            let filePath = (self?.currentPath.isEmpty ?? true ? "" : path + "/") + item.path
            client.downloadFile(from: filePath) { result in
                DispatchQueue.main.async {
                    self?.activityIndicator.stopAnimating()
                    
                    switch result {
                    case .success(_):
                        let successAlert = UIAlertController(title: "下载成功", message: "文件已下载", preferredStyle: .alert)
                        successAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self?.present(successAlert, animated: true)
                    case .failure(let error):
                        self?.showError(error.localizedDescription)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    @objc private func doneTapped() {
        // 如果是 modal 弹出的页面
        // dismiss(animated: true)
        
        // 如果是 push 页面
        navigationController?.popViewController(animated: true)
    }
}
