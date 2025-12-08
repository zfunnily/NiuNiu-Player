import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 根据环境配置日志
        #if DEBUG
        Logger.shared.enableDevelopmentMode()
        #else
        Logger.shared.enableProductionMode()
        #endif
        DLog("AppDelegate: didFinishLaunchingWithOptions")
        
        // 应用全局导航栏样式
        UINavigationBar.appearance().backgroundColor = .systemBackground
        UINavigationBar.appearance().barTintColor = .systemBackground
        UINavigationBar.appearance().titleTextAttributes = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ]
        return true
    }
    
    // iOS 18.4 场景配置方法
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        DLog("AppDelegate: 配置场景连接 - iOS 18.4")
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        DLog("AppDelegate: 场景会话已丢弃")
    }
}
