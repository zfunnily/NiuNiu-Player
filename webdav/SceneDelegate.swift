import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // 确保是窗口场景
        guard let windowScene = (scene as? UIWindowScene) else {
            print("Scene不是UIWindowScene")
            return
        }
        
        // 创建窗口并设置根视图控制器
        window = UIWindow(windowScene: windowScene)
        
        // 创建根视图控制器
        let rootVC = UINavigationController(rootViewController: ProviderListViewController())
        window?.rootViewController = rootVC
        window?.makeKeyAndVisible()
        // 显示窗口 - 这是关键步骤
        window?.makeKeyAndVisible()
        print("SceneDelegate: 窗口已设置并显示")
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        print("SceneDelegate: sceneDidDisconnect")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("SceneDelegate: sceneDidBecomeActive")
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        print("SceneDelegate: sceneWillResignActive")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("SceneDelegate: sceneWillEnterForeground")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("SceneDelegate: sceneDidEnterBackground")
    }
}
