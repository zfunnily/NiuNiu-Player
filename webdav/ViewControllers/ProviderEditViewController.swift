//
//  ProviderEditViewController.swift
//  webdav
//
//  Created by ZQJ on 2025/11/19.
//

import UIKit

enum EditMode {
    case add
    case edit
}

protocol ProviderEditViewControllerDelegate: AnyObject {
    func providerEditViewControllerDidSave()
}

class ProviderEditViewController: UIViewController {
    
    weak var delegate: ProviderEditViewControllerDelegate?
    private let mode: EditMode
    private var provider: WebDAVProvider?
    
    private let nameTextField = UITextField()
    private let urlTextField = UITextField()
    private let usernameTextField = UITextField()
    private let passwordTextField = UITextField()
    private let saveButton = UIButton(type: .system)
    private let testButton = UIButton(type: .system)

    // 添加滚动视图
    private let scrollView = UIScrollView()
    
    init(mode: EditMode, provider: WebDAVProvider? = nil) {
        self.mode = mode
        self.provider = provider
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
        setupKeyboardObservers()

    }
    deinit {
        // 移除键盘通知
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        title = mode == .add ? "添加服务器" : "编辑服务器"
        view.backgroundColor = .systemBackground

        // 添加滚动视图
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        
         // 设置文本字段
         setupTextField(nameTextField, placeholder: "服务器名称", tag: 1)
         setupTextField(urlTextField, placeholder: "服务器地址 (例如: https://example.com/webdav)", tag: 2)
         setupTextField(usernameTextField, placeholder: "用户名", tag: 3)
         setupTextField(passwordTextField, placeholder: "密码", tag: 4, isSecure: false)
        
        // 如果是编辑模式，填充现有数据
         if let provider = provider, mode == .edit {
             nameTextField.text = provider.name
             urlTextField.text = provider.serverURL
             usernameTextField.text = provider.username
             passwordTextField.text = provider.getDecryptedPassword()
         }
        
        // 设置保存按钮
        saveButton.setTitle("保存", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 12
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        
        // 设置测试连接按钮
        testButton.setTitle("测试连接", for: .normal)
        testButton.backgroundColor = .systemGreen
        testButton.setTitleColor(.white, for: .normal)
        testButton.layer.cornerRadius = 12
        testButton.addTarget(self, action: #selector(testConnectionTapped), for: .touchUpInside)
        
        // 创建垂直栈视图
        let stackView = UIStackView(arrangedSubviews: [
            createLabel(with: "服务器名称"),
            nameTextField,
            createLabel(with: "服务器地址"),
            urlTextField,
            createLabel(with: "用户名"),
            usernameTextField,
            createLabel(with: "密码"),
            passwordTextField,
            UIView(), // 占位视图
            testButton,
            saveButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // 将栈视图添加到滚动视图
        scrollView.addSubview(stackView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            // 滚动视图约束
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // 栈视图约束
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40) // 确保栈视图宽度固定
        ])
        
        // 设置按钮高度
        saveButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
        testButton.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    // 设置键盘通知
    private func setupKeyboardObservers() {
        // 键盘显示通知
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        // 键盘隐藏通知
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // 键盘显示时调整滚动视图
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        
        // 增加底部内边距，为键盘留出空间
        scrollView.contentInset.bottom = keyboardSize.height
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardSize.height
        
        // 如果当前焦点在底部附近，自动滚动到焦点控件
        if let activeField = view.findFirstResponder(), 
           let activeFieldFrame = activeField.superview?.convert(activeField.frame, to: scrollView) {
            scrollView.scrollRectToVisible(activeFieldFrame, animated: true)
        }
    }
    
    // 键盘隐藏时恢复滚动视图
    @objc private func keyboardWillHide() {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    // 添加收起键盘的辅助方法
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
    }
    
    private func setupConstraints() {
        // 已经在setupUI中通过栈视图设置了约束
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String, tag: Int, isSecure: Bool = false) {
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.tag = tag
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.isSecureTextEntry = isSecure
        textField.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }
    
    private func createLabel(with text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }
    
    private func validateForm() -> Bool {
        guard let name = nameTextField.text, !name.isEmpty else {
            showAlert(title: "错误", message: "请输入服务器名称")
            return false
        }
        
        guard let url = urlTextField.text, !url.isEmpty else {
            showAlert(title: "错误", message: "请输入服务器地址")
            return false
        }
        
        // 简单的URL验证
        if !url.starts(with: "http://") && !url.starts(with: "https://") {
            showAlert(title: "错误", message: "服务器地址必须以 http:// 或 https:// 开头")
            return false
        }
        
        return true
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - 按钮事件
    
    @objc private func saveTapped() {
        guard validateForm() else { return }
        
        let name = nameTextField.text ?? ""
        let url = urlTextField.text ?? ""
        let username = usernameTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        
        switch mode {
        case .add:
            let newProvider = WebDAVProvider(
                name: name,
                serverURL: url,
                username: username,
                password: password
            )
            ProviderManager.shared.addProvider(newProvider)
            
        case .edit:
            if var provider = provider {
                provider.name = name
                provider.serverURL = url
                provider.username = username
                provider.updatePassword(password) // 使用新的更新方法
                ProviderManager.shared.updateProvider(id: provider.id, updatedProvider: provider)
            }
        }
        
        delegate?.providerEditViewControllerDidSave()
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func testConnectionTapped() {
        guard validateForm() else { return }
        
        let name = nameTextField.text ?? ""
        let url = urlTextField.text ?? ""
        let username = usernameTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        
        let testProvider = WebDAVProvider(
            name: name,
            serverURL: url,
            username: username,
            password: password
        )
        
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // 测试连接
        ProviderManager.shared.testConnection(testProvider) { [weak self] success, error in
            DispatchQueue.main.async {
                activityIndicator.removeFromSuperview()
                
                if success {
                    self?.showAlert(title: "连接成功", message: "成功连接到服务器")
                } else {
                    let errorMessage = error?.localizedDescription ?? "无法连接到服务器，请检查配置信息"
                    self?.showAlert(title: "连接失败", message: errorMessage)
                }
            }
        }
    }
    
    @objc private func cancelTapped() {
        navigationController?.popViewController(animated: true)
    }
}

// 扩展ProviderListViewController实现代理方法
extension ProviderListViewController: ProviderEditViewControllerDelegate {
    func providerEditViewControllerDidSave() {
        tableView.reloadData()
    }
}
// WebDAVClient扩展 - 添加重试功能
extension WebDAVClient {
    
    private func executeRequestWithRetry(request: URLRequest, retriesLeft: Int, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                // 判断是否需要重试（例如网络错误）
                if retriesLeft > 0, self.shouldRetryAfterError(error) {
                    // 指数退避重试 - 现在使用已定义的maxRetries
                    let delay = DispatchTimeInterval.milliseconds(Int(pow(2.0, Double(self.maxRetries - retriesLeft))) * 100)
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.executeRequestWithRetry(request: request, retriesLeft: retriesLeft - 1, completion: completion)
                    }
                    return
                }
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "WebDAV", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])))
                return
            }
            
            completion(.success((data, httpResponse)))
        }
        
        task.resume()
    }
    
    private func shouldRetryAfterError(_ error: Error) -> Bool {
        // 根据错误类型判断是否应该重试
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain &&
               [NSURLErrorTimedOut, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost].contains(nsError.code)
    }
    
    // 公共方法，调用重试逻辑
    func executeRequest(request: URLRequest, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        executeRequestWithRetry(request: request, retriesLeft: maxRetries, completion: completion)
    }
}
// UIView扩展：查找当前第一响应者
fileprivate extension UIView {
    func findFirstResponder() -> UIView? {
        if isFirstResponder {
            return self
        }
        
        for subview in subviews {
            if let firstResponder = subview.findFirstResponder() {
                return firstResponder
            }
        }
        
        return nil
    }
}
