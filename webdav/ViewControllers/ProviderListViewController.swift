import UIKit

class ProviderListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    private let addButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupTableView()

         // 应用统一导航栏样式
        navigationController?.applyGlobalNavigationBarStyle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    private func setupUI() {
        title = "WebDAV服务器"
        view.backgroundColor = .systemBackground

        // 移除默认返回按钮，设置为空
        navigationItem.hidesBackButton = true
        
        // 设置添加按钮
        addButton.setTitle("添加服务器", for: .normal)
        addButton.backgroundColor = .systemBlue
        addButton.setTitleColor(.white, for: .normal)
        addButton.layer.cornerRadius = 12
        addButton.layer.shadowColor = UIColor.black.cgColor
        addButton.layer.shadowOpacity = 0.2
        addButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        addButton.layer.shadowRadius = 4
        addButton.addTarget(self, action: #selector(addProviderTapped), for: .touchUpInside)
        
        view.addSubview(tableView)
        view.addSubview(addButton)
    }
    
    private func setupConstraints() {
        // 设置表格视图约束
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -20)
        ])
        
        // 设置添加按钮约束
        addButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            addButton.widthAnchor.constraint(equalToConstant: 240),
            addButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ProviderCell.self, forCellReuseIdentifier: "ProviderCell")
        tableView.rowHeight = 80
        tableView.separatorStyle = .singleLine
        
        // 设置空状态
        let emptyLabel = UILabel()
        emptyLabel.text = "暂无WebDAV服务器\n点击下方按钮添加"
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.textColor = .secondaryLabel
        tableView.backgroundView = emptyLabel
        tableView.backgroundView?.isHidden = !ProviderManager.shared.providers.isEmpty
    }
    
    // MARK: - TableView 代理方法
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = ProviderManager.shared.providers.count
        tableView.backgroundView?.isHidden = count > 0
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProviderCell", for: indexPath) as! ProviderCell
        let provider = ProviderManager.shared.providers[indexPath.row]
        cell.configure(with: provider)
        
        // 设置编辑按钮回调
        cell.editHandler = { [weak self] in
            self?.editProvider(provider)
        }
        
        // 设置删除按钮回调
        cell.deleteHandler = { [weak self] in
            self?.deleteProvider(provider)
        }
        
        // 设置连接按钮回调
        cell.connectHandler = { [weak self] in
            self?.connectProvider(provider)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let provider = ProviderManager.shared.providers[indexPath.row]
        connectProvider(provider)
    }
    
    // MARK: - 操作方法
    
    @objc private func addProviderTapped() {
        let editVC = ProviderEditViewController(mode: .add)
        editVC.delegate = self
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    private func editProvider(_ provider: WebDAVProvider) {
        let editVC = ProviderEditViewController(mode: .edit, provider: provider)
        editVC.delegate = self
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    private func deleteProvider(_ provider: WebDAVProvider) {
        let alert = UIAlertController(
            title: "删除服务器",
            message: "确定要删除服务器 \(provider.name) 吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
            ProviderManager.shared.deleteProvider(id: provider.id)
            self.tableView.reloadData()
        })
        
        present(alert, animated: true)
    }
    
    private func connectProvider(_ provider: WebDAVProvider) {
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // 测试连接
       ProviderManager.shared.testConnection(provider) { [weak self] success, error in
           DispatchQueue.main.async {
               activityIndicator.removeFromSuperview()
               
               if success {
                   // 连接成功，跳转到文件浏览器界面
                   let fileBrowserVC = WebDAVFileBrowserViewController(provider: provider)
                   self?.navigationController?.pushViewController(fileBrowserVC, animated: true)
               } else {
                   let errorMessage = error?.localizedDescription ?? "无法连接到服务器，请检查服务器信息"
                   let alert = UIAlertController(
                       title: "连接失败",
                       message: errorMessage,
                       preferredStyle: .alert
                   )
                   alert.addAction(UIAlertAction(title: "确定", style: .default))
                   self?.present(alert, animated: true)
               }
           }
       }
    }
}
