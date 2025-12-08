//
//  FileBrowserView.swift
//  potplayer
//
//  Created by ZQJ on 2025/11/14.
//
import UIKit

class FileBrowserViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let provider: StorageProvider
    private let tableView = UITableView()
    private var currentPath = "/"
    private var fileItems: [FileItem] = []
    private var pathHistory: [String] = []
    private var isLoading = false
    
    init(provider: StorageProvider) {
        self.provider = provider
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFiles(at: currentPath)
    }
    
    private func setupUI() {
        title = provider.displayName
        view.backgroundColor = .white
        
        // 设置表格视图
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FileCell.self, forCellReuseIdentifier: "FileCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // 添加下拉刷新
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshFiles), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func loadFiles(at path: String) {
        isLoading = true
        
        // 显示加载指示器
        if tableView.refreshControl?.isRefreshing == false {
            let activityIndicator = UIActivityIndicatorView(style: .medium)
            tableView.tableFooterView = activityIndicator
            activityIndicator.startAnimating()
        }
        
        Task {
            do {
                let items = try await provider.listContents(of: path)
                
                // 按目录优先，然后按名称排序
                let sortedItems = items.sorted { a, b in
                    if a.isDirectory && !b.isDirectory {
                        return true
                    } else if !a.isDirectory && b.isDirectory {
                        return false
                    } else {
                        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                    }
                }
                
                await MainActor.run {
                    self.fileItems = sortedItems
                    self.tableView.reloadData()
                    self.updateNavigationTitle()
                    self.isLoading = false
                    
                    // 停止加载指示器
                    if let refreshControl = tableView.refreshControl, refreshControl.isRefreshing {
                        refreshControl.endRefreshing()
                    }
                    tableView.tableFooterView = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    
                    // 停止加载指示器
                    if let refreshControl = tableView.refreshControl, refreshControl.isRefreshing {
                        refreshControl.endRefreshing()
                    }
                    tableView.tableFooterView = nil
                    
                    // 显示错误提示
                    let alert = UIAlertController(title: "错误", message: "加载失败: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
    
    private func updateNavigationTitle() {
        if currentPath == "/" {
            title = provider.displayName
        } else {
            let pathComponents = currentPath.components(separatedBy: "/").filter { !$0.isEmpty }
            title = pathComponents.last ?? provider.displayName
        }
    }
    
    @objc private func refreshFiles() {
        loadFiles(at: currentPath)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 如果不是根目录，添加返回上一级的选项
        return currentPath == "/" ? fileItems.count : fileItems.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileCell", for: indexPath) as! FileCell
        
        if currentPath != "/" && indexPath.row == 0 {
            // 返回上一级
            cell.configureForParentDirectory()
        } else {
            // 常规文件或目录
            let itemIndex = currentPath != "/" ? indexPath.row - 1 : indexPath.row
            let item = fileItems[itemIndex]
            cell.configure(with: item)
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if currentPath != "/" && indexPath.row == 0 {
            // 返回上一级
            goToParentDirectory()
        } else {
            let itemIndex = currentPath != "/" ? indexPath.row - 1 : indexPath.row
            let item = fileItems[itemIndex]
            
            if item.isDirectory {
                // 进入子目录
                pathHistory.append(currentPath)
                currentPath = item.path
                loadFiles(at: currentPath)
            } else {
                // 文件操作菜单
                showFileOptions(for: item)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // 如果是返回上一级行，不显示滑动操作
        if currentPath != "/" && indexPath.row == 0 {
            return nil
        }
        
        let itemIndex = currentPath != "/" ? indexPath.row - 1 : indexPath.row
        let item = fileItems[itemIndex]
        
        // 删除操作
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] (_, _, completion) in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "确认删除", message: "确定要删除 \(item.name) 吗？", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
                completion(false)
            }))
            alert.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { [weak self] _ in
                guard let self = self else { return }
                self.deleteItem(item, at: indexPath)
                completion(true)
            }))
            
            self.present(alert, animated: true)
        }
        
        // 重命名操作
        let renameAction = UIContextualAction(style: .normal, title: "重命名") { [weak self] (_, _, completion) in
            guard let self = self else { return }
            self.showRenameDialog(for: item, at: indexPath)
            completion(true)
        }
        renameAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
    }
    
    private func goToParentDirectory() {
        if !pathHistory.isEmpty {
            currentPath = pathHistory.removeLast()
            loadFiles(at: currentPath)
        }
    }
    
    private func showFileOptions(for item: FileItem) {
        let alert = UIAlertController(title: item.name, message: nil, preferredStyle: .actionSheet)
        
        // 下载操作
        alert.addAction(UIAlertAction(title: "下载", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.downloadFile(item)
        })
        
        // 分享操作
        alert.addAction(UIAlertAction(title: "分享", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.shareFile(item)
        })
        
        // 预览操作（如果支持）
        alert.addAction(UIAlertAction(title: "预览", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.previewFile(item)
        })
        
        // 取消操作
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 在iPad上设置弹出框的位置
        if let popoverController = alert.popoverPresentationController {
            if let cell = tableView.cellForRow(at: IndexPath(row: fileItems.firstIndex(of: item) ?? 0, section: 0)) {
                popoverController.sourceView = cell
                popoverController.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    private func showRenameDialog(for item: FileItem, at indexPath: IndexPath) {
        let alert = UIAlertController(title: "重命名", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = item.name
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let self = self, let newName = alert.textFields?.first?.text, !newName.isEmpty else {
                return
            }
            
            self.renameItem(item, to: newName, at: indexPath)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteItem(_ item: FileItem, at indexPath: IndexPath) {
        Task {
            do {
                try await provider.deleteItem(at: item.path)
                
                await MainActor.run {
                    let actualIndex = currentPath != "/" ? indexPath.row - 1 : indexPath.row
                    fileItems.remove(at: actualIndex)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: "错误", message: "删除失败: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
    
    private func renameItem(_ item: FileItem, to newName: String, at indexPath: IndexPath) {
        Task {
            do {
                try await provider.renameItem(at: item.path, to: newName)
                
                await MainActor.run {
                    let actualIndex = currentPath != "/" ? indexPath.row - 1 : indexPath.row
                    // 重新加载整个列表以保持正确排序
                    loadFiles(at: currentPath)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: "错误", message: "重命名失败: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
    
    private func downloadFile(_ item: FileItem) {
        // 显示进度指示器
        let progressAlert = UIAlertController(title: "下载中", message: "正在下载 \(item.name)", preferredStyle: .alert)
        present(progressAlert, animated: true)
        
        Task {
            do {
                let data = try await provider.downloadFile(from: item.path)
                
                await MainActor.run {
                    progressAlert.dismiss(animated: true) {
                        // 保存到文件系统或显示成功提示
                        let alert = UIAlertController(title: "下载成功", message: "文件已成功下载", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    progressAlert.dismiss(animated: true) {
                        let alert = UIAlertController(title: "错误", message: "下载失败: \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    private func shareFile(_ item: FileItem) {
        let progressAlert = UIAlertController(title: "准备分享", message: "正在准备文件...", preferredStyle: .alert)
        present(progressAlert, animated: true)
        
        Task {
            do {
                let data = try await provider.downloadFile(from: item.path)
                
                await MainActor.run {
                    progressAlert.dismiss(animated: true) {
                        let activityViewController = UIActivityViewController(activityItems: [data], applicationActivities: nil)
                        
                        // 设置分享项的文件名
                        activityViewController.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
                            if completed {
                                DLog("文件分享成功")
                            }
                        }
                        
                        // 在iPad上设置弹出框位置
                        if let popoverController = activityViewController.popoverPresentationController {
                            popoverController.sourceView = self.view
                            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                            popoverController.permittedArrowDirections = []
                        }
                        
                        self.present(activityViewController, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    progressAlert.dismiss(animated: true) {
                        let alert = UIAlertController(title: "错误", message: "准备分享失败: \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    private func previewFile(_ item: FileItem) {
        let progressAlert = UIAlertController(title: "准备预览", message: "正在加载文件...", preferredStyle: .alert)
        present(progressAlert, animated: true)
        
        Task {
            do {
                let data = try await provider.downloadFile(from: item.path)
                
                await MainActor.run {
                    progressAlert.dismiss(animated: true) {
                        // 创建预览控制器
                        let previewController = UIDocumentInteractionController(url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(item.name))
                        
                        // 写入临时文件
                        do {
                            try data.write(to: previewController.url!)
                            
                            // 设置代理以支持预览
                            previewController.delegate = self
                            
                            // 显示预览
                            if !previewController.presentPreview(animated: true) {
                                let alert = UIAlertController(title: "无法预览", message: "不支持预览此类型的文件", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "确定", style: .default))
                                self.present(alert, animated: true)
                            }
                        } catch {
                            let alert = UIAlertController(title: "错误", message: "无法保存预览文件", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "确定", style: .default))
                            self.present(alert, animated: true)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    progressAlert.dismiss(animated: true) {
                        let alert = UIAlertController(title: "错误", message: "加载文件失败: \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
}

// MARK: - 文件单元格

class FileCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with item: FileItem) {
        textLabel?.text = item.name
        
        if item.isDirectory {
            imageView?.image = UIImage(systemName: "folder.fill")
            detailTextLabel?.text = "文件夹"
        } else {
            // 根据文件扩展名设置图标
            let fileExtension = URL(fileURLWithPath: item.name).pathExtension.lowercased()
            var iconName: String
            
            switch fileExtension {
            case "pdf":
                iconName = "doc.pdf.fill"
            case "doc", "docx":
                iconName = "doc.text.fill"
            case "xls", "xlsx":
                iconName = "table.fill"
            case "ppt", "pptx":
                iconName = "presentation.fill"
            case "txt":
                iconName = "text.fill"
            case "jpg", "jpeg", "png", "gif", "heic":
                iconName = "photo.fill"
            case "mp3", "wav", "aac", "m4a":
                iconName = "music.note.fill"
            case "mp4", "mov", "avi", "mkv":
                iconName = "film.fill"
            case "zip", "rar", "7z", "tar", "gz":
                iconName = "archivebox.fill"
            default:
                iconName = "document.fill"
            }
            
            imageView?.image = UIImage(systemName: iconName)
            detailTextLabel?.text = "\(item.displaySize) · \(item.displayDate)"
        }
    }
    
    func configureForParentDirectory() {
        textLabel?.text = ".."
        detailTextLabel?.text = "返回上一级"
        imageView?.image = UIImage(systemName: "folder.fill.badge.arrow.up")
    }
}

// MARK: - UIDocumentInteractionControllerDelegate

extension FileBrowserViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        // 清理临时文件
        if let url = controller.url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
