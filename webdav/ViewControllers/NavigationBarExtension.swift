//
//  NavigationBarExtension.swift
//  webdav
//
//  Created by ZQJ on 2025/12/1.
//

import UIKit

// 导航栏样式扩展
extension UINavigationController {
    // 应用全局导航栏样式
    func applyGlobalNavigationBarStyle() {
        // 设置导航栏背景色
        navigationBar.backgroundColor = .systemBackground
        navigationBar.barTintColor = .systemBackground
        
        // 设置导航栏标题样式
        navigationBar.titleTextAttributes = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ]
        
        // 设置导航栏按钮样式
        UIBarButtonItem.appearance().setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.systemBlue
        ], for: .normal)
        
        // 设置导航栏阴影
        navigationBar.shadowImage = UIImage()
        navigationBar.isTranslucent = false
        
        // 设置返回按钮样式
        navigationBar.backIndicatorImage = UIImage(systemName: "chevron.left")
        navigationBar.backIndicatorTransitionMaskImage = UIImage(systemName: "chevron.left")
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UINavigationController.self]).title = "返回"
    }
}
