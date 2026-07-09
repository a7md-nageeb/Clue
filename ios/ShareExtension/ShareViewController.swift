import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Retrieve and process the shared content
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        let textType = kUTTypeText as String
        let urlType = kUTTypeURL as String
        
        if attachment.hasItemConformingToTypeIdentifier(textType) {
            attachment.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] (data, error) in
                if let text = data as? String {
                    self?.saveSharedTextAndLaunch(text)
                } else {
                    self?.dismissExtension()
                }
            }
        } else if attachment.hasItemConformingToTypeIdentifier(urlType) {
            attachment.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] (data, error) in
                if let url = data as? URL {
                    self?.saveSharedTextAndLaunch(url.absoluteString)
                } else {
                    self?.dismissExtension()
                }
            }
        } else {
            dismissExtension()
        }
    }
    
    private func saveSharedTextAndLaunch(_ text: String) {
        // Save the shared text to the App Group shared container
        let sharedDefaults = UserDefaults(suiteName: "group.com.forgottenthings")
        sharedDefaults?.set(text, forKey: "sharedText")
        sharedDefaults?.synchronize()
        
        // Open the host app using custom URL scheme
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                let url = URL(string: "forgotten-things://share")!
                application.perform(#selector(UIApplication.open(_:options:completionHandler:)), with: url)
                break
            }
            responder = responder?.next
        }
        
        dismissExtension()
    }
    
    private func dismissExtension() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
