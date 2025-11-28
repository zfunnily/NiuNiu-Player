//
//  ProviderCell.swift
//  webdav
//
//  Created by ZQJ on 2025/11/19.
//

import UIKit

class ProviderCell: UITableViewCell {
    
    // 回调闭包
    var editHandler: (() -> Void)?
    var deleteHandler: (() -> Void)?
    var connectHandler: (() -> Void)?
    
    private let nameLabel = UILabel()
    private let urlLabel = UILabel()
    private let statusIndicator = UIView()
    private let buttonStackView = UIStackView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 设置名称标签
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textColor = .label
        
        // 设置URL标签
        urlLabel.font = UIFont.systemFont(ofSize: 14)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 1
        
        // 设置状态指示器
        statusIndicator.layer.cornerRadius = 6
        statusIndicator.widthAnchor.constraint(equalToConstant: 12).isActive = true
        statusIndicator.heightAnchor.constraint(equalToConstant: 12).isActive = true
        
        // 创建按钮
        let connectButton = createButton(systemName: "externaldrive", color: .systemBlue)
        connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        
        let editButton = createButton(systemName: "pencil", color: .systemGray)
        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
        
        let deleteButton = createButton(systemName: "trash", color: .systemRed)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        
        // 设置按钮栈视图
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = 8
        buttonStackView.distribution = .fillEqually
        buttonStackView.addArrangedSubview(connectButton)
        buttonStackView.addArrangedSubview(editButton)
        buttonStackView.addArrangedSubview(deleteButton)
        
        // 创建主内容栈视图
        let infoStackView = UIStackView(arrangedSubviews: [nameLabel, urlLabel])
        infoStackView.axis = .vertical
        infoStackView.spacing = 4
        infoStackView.alignment = .leading
        
        // 创建状态栈视图
        let statusStackView = UIStackView(arrangedSubviews: [statusIndicator, UIView()])
        statusStackView.axis = .horizontal
        statusStackView.spacing = 8
        statusStackView.alignment = .center
        
        // 主水平栈视图
        let mainStackView = UIStackView(arrangedSubviews: [infoStackView, statusStackView, buttonStackView])
        mainStackView.axis = .horizontal
        mainStackView.spacing = 12
        mainStackView.alignment = .center
        mainStackView.distribution = .fill
        
        // 添加到单元格
        contentView.addSubview(mainStackView)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        
        // 设置信息栈视图权重
        infoStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        buttonStackView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
    
    private func createButton(systemName: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = color
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return button
    }
    
    func configure(with provider: WebDAVProvider) {
        nameLabel.text = provider.name
        urlLabel.text = provider.serverURL
        
        // 设置状态指示器颜色
        statusIndicator.backgroundColor = provider.isConnected ? .systemGreen : .systemGray
    }
    
    // 按钮点击事件
    @objc private func connectButtonTapped() {
        connectHandler?()
    }
    
    @objc private func editButtonTapped() {
        editHandler?()
    }
    
    @objc private func deleteButtonTapped() {
        deleteHandler?()
    }
}
