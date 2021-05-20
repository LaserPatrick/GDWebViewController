//
//  GDWebViewController.swift
//  GDWebBrowserClient
//
//  Created by Alex G on 03.12.14.
//  Copyright (c) 2015 Alexey Gordiyenko. All rights reserved.
//

//MIT License
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit
import WebKit

public enum GDWebViewControllerProgressIndicatorStyle {
    case activityIndicator
    case progressView
    case both
    case none
}

@objc public protocol GDWebViewControllerDelegate {
    @objc optional func webViewController(_ webViewController: GDWebViewController, didChangeURL newURL: URL?)
    @objc optional func webViewController(_ webViewController: GDWebViewController, didChangeTitle newTitle: NSString?)
    @objc optional func webViewController(_ webViewController: GDWebViewController, didFinishLoading loadedURL: URL?)
    @objc optional func webViewController(_ webViewController: GDWebViewController, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void)
    @objc optional func webViewController(_ webViewController: GDWebViewController, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void)
    @objc optional func webViewController(_ webViewController: GDWebViewController, didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge, completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
}

open class GDWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, GDWebViewNavigationToolbarDelegate {
    
    // MARK: Public Properties
    
    /** An object to serve as a delegate which conforms to GDWebViewNavigationToolbarDelegate protocol. */
    open weak var delegate: GDWebViewControllerDelegate?
    
    /** The style of progress indication visualization. Can be one of four values: .ActivityIndicator, .ProgressView, .Both, .None*/
    open var progressIndicatorStyle: GDWebViewControllerProgressIndicatorStyle = .both
    
    /** A Boolean value indicating whether horizontal swipe gestures will trigger back-forward list navigations. The default value is false. */
    open var allowsBackForwardNavigationGestures: Bool {
        get {
            return webView.allowsBackForwardNavigationGestures
        }
        set(value) {
            webView.allowsBackForwardNavigationGestures = value
        }
    }
    
    /** A boolean value if set to true shows the toolbar; otherwise, hides it. */
    open var showsToolbar: Bool {
        set(value) {
            self.toolbarHeight = value ? 44 : 0
        }
        
        get {
            return self.toolbarHeight == 44
        }
    }
    
    /** A boolean value if set to true shows the refresh control (or stop control while loading) on the toolbar; otherwise, hides it. */
    open var showsStopRefreshControl: Bool {
        get {
            return toolbarContainer.showsStopRefreshControl
        }
        
        set(value) {
            toolbarContainer.showsStopRefreshControl = value
        }
    }
    
    /** The navigation toolbar object (read-only). */
    var toolbar: GDWebViewNavigationToolbar {
        get {
            return toolbarContainer
        }
    }
    
    /** Boolean flag which indicates whether JavaScript alerts are allowed. Default is `true`. */
    open var allowJavaScriptAlerts = true
    
    public var webView: WKWebView!
    
    // MARK: Private Properties
    fileprivate var progressView: UIProgressView!
    fileprivate var toolbarContainer: GDWebViewNavigationToolbar!
    fileprivate var toolbarHeightConstraint: NSLayoutConstraint!
    fileprivate var toolbarHeight: CGFloat = 0
    fileprivate var navControllerUsesBackSwipe: Bool = false
    lazy fileprivate var activityIndicator: UIActivityIndicatorView! = {
        var activityIndicator = UIActivityIndicatorView()
        activityIndicator.backgroundColor = UIColor(white: 0, alpha: 0.2)
        #if swift(>=4.2)
        activityIndicator.style = .whiteLarge
        #else
        activityIndicator.activityIndicatorViewStyle = .whiteLarge
        #endif
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(activityIndicator)
        
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-0-[activityIndicator]-0-|", options: [], metrics: nil, views: ["activityIndicator": activityIndicator]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[topGuide]-0-[activityIndicator]-0-[toolbarContainer]|", options: [], metrics: nil, views: ["activityIndicator": activityIndicator, "toolbarContainer": self.toolbarContainer, "topGuide": self.topLayoutGuide]))
        return activityIndicator
    }()
    
    // MARK: Public Methods
    
    /**
     Navigates to an URL created from provided string.
     
     - parameter URLString: The string that represents an URL.
     */
    
    // TODO: Earlier `scheme` property was optional. Now it isn't true. Need to check that scheme is always
    
    open func loadURLWithString(_ URLString: String) {
        if let URL = URL(string: URLString) {
            if (URL.scheme != "") && (URL.host != nil) {
                loadURL(URL)
            } else {
                loadURLWithString("http://\(URLString)")
            }
        }
    }
    
    /**
     Navigates to the URL.
     
     - parameter URL: The URL for a request.
     - parameter cachePolicy: The cache policy for a request. Optional. Default value is .UseProtocolCachePolicy.
     - parameter timeoutInterval: The timeout interval for a request, in seconds. Optional. Default value is 0.
     */
    open func loadURL(_ URL: Foundation.URL, cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval = 0) {
        webView.load(URLRequest(url: URL, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval))
    }
    
    /**
     Evaluates the given JavaScript string.
     - parameter javaScriptString: The JavaScript string to evaluate.
     - parameter completionHandler: A block to invoke when script evaluation completes or fails.
     
     The completionHandler is passed the result of the script evaluation or an error.
     */
    open func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((AnyObject?, NSError?) -> Void)?) {
        webView.evaluateJavaScript(javaScriptString, completionHandler: completionHandler as! ((Any?, Error?) -> Void)?)
    }
    
    /**
     Shows or hides toolbar.
     
     - parameter show: A Boolean value if set to true shows the toolbar; otherwise, hides it.
     - parameter animated: A Boolean value if set to true animates the transition; otherwise, does not.
     */
    open func showToolbar(_ show: Bool, animated: Bool) {
        self.showsToolbar = show
        
        if toolbarHeightConstraint != nil {
            toolbarHeightConstraint.constant = self.toolbarHeight
            if animated {
                UIView.animate(withDuration: 0.2, animations: { () -> Void in
                    self.view.layoutIfNeeded()
                })
            } else {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc open func goBack(){
        webView.goBack()
    }
    
    @objc open func goForward(){
        webView.goForward()
    }
    
    @objc open func stopLoading(){
        webView.stopLoading()
    }
    
    @objc open func reload(){
        webView.reload()
    }
    
    // MARK: GDWebViewNavigationToolbarDelegate Methods
    
    func webViewNavigationToolbarGoBack(_ toolbar: GDWebViewNavigationToolbar) {
        webView.goBack()
    }
    
    func webViewNavigationToolbarGoForward(_ toolbar: GDWebViewNavigationToolbar) {
        webView.goForward()
    }
    
    func webViewNavigationToolbarRefresh(_ toolbar: GDWebViewNavigationToolbar) {
        webView.reload()
    }
    
    func webViewNavigationToolbarStop(_ toolbar: GDWebViewNavigationToolbar) {
        webView.stopLoading()
    }
    
    // MARK: WKNavigationDelegate Methods
    
    open func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }
    
    open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoading(false)
        if error._code == NSURLErrorCancelled {
            return
        }
        
        showError(error.localizedDescription)
    }
    
    open func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoading(false)
        if error._code == NSURLErrorCancelled {
            return
        }
        showError(error.localizedDescription)
    }
    
    open func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard ((delegate?.webViewController?(self, didReceiveAuthenticationChallenge: challenge, completionHandler: { (disposition, credential) -> Void in
            completionHandler(disposition, credential)
        })) != nil)
            else {
                completionHandler(.performDefaultHandling, nil)
                return
        }
    }
    
    open func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    }
    
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showLoading(true)
    }
    
    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard ((delegate?.webViewController?(self, decidePolicyForNavigationAction: navigationAction, decisionHandler: { (policy) -> Void in
            decisionHandler(policy)
        })) != nil)
            else {
                decisionHandler(.allow);
                return
        }
    }
    
    open func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
        guard ((delegate?.webViewController?(self, decidePolicyForNavigationResponse: navigationResponse, decisionHandler: { (policy) -> Void in
            decisionHandler(policy)
        })) != nil)
            else {
                decisionHandler(.allow)
                return
        }
    }
    
    
    open func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url{
            if url.description.lowercased().range(of: "http://") != nil || url.description.lowercased().range(of: "https://") != nil  {
                webView.load(navigationAction.request)
            }
        }
        return nil
    }
    
    // MARK: WKUIDelegate Methods
    
    open func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        if !allowJavaScriptAlerts {
            return
        }
        
        let alertController: UIAlertController = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: {(action: UIAlertAction) -> Void in
            completionHandler()
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: Some Private Methods
    
    fileprivate func showError(_ errorString: String?) {
        let alertView = UIAlertController(title: "Error", message: errorString, preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertView, animated: true, completion: nil)
    }
    
    fileprivate func showLoading(_ animate: Bool) {
        if animate {
            if (progressIndicatorStyle == .activityIndicator) || (progressIndicatorStyle == .both) {
                activityIndicator.startAnimating()
            }
            
            toolbar.loadDidStart()
        } else if activityIndicator != nil {
            if (progressIndicatorStyle == .activityIndicator) || (progressIndicatorStyle == .both) {
                activityIndicator.stopAnimating()
            }
            
            toolbar.loadDidFinish()
        }
    }
    
    fileprivate func progressChanged(_ newValue: NSNumber) {
        if progressView == nil {
            progressView = UIProgressView()
            progressView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(progressView)
            
            self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-0-[progressView]-0-|", options: [], metrics: nil, views: ["progressView": progressView]))
            self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[topGuide]-0-[progressView(2)]", options: [], metrics: nil, views: ["progressView": progressView, "topGuide": self.topLayoutGuide]))
        }
        
        progressView.progress = newValue.floatValue
        if progressView.progress == 1 {
            progressView.progress = 0
            UIView.animate(withDuration: 0.2, animations: { () -> Void in
                self.progressView.alpha = 0
            })
        } else if progressView.alpha == 0 {
            UIView.animate(withDuration: 0.2, animations: { () -> Void in
                self.progressView.alpha = 1
            })
        }
    }
    
    fileprivate func backForwardListChanged() {
        if self.navControllerUsesBackSwipe && self.allowsBackForwardNavigationGestures {
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !webView.canGoBack
        }
        
        toolbarContainer.backButtonItem?.isEnabled = webView.canGoBack
        toolbarContainer.forwardButtonItem?.isEnabled = webView.canGoForward
    }
    
    // MARK: KVO
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {return}
        switch keyPath {
        case "estimatedProgress":
            if (progressIndicatorStyle == .progressView) || (progressIndicatorStyle == .both) {
                if let newValue = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    progressChanged(newValue)
                }
            }
        case "URL":
            delegate?.webViewController?(self, didChangeURL: webView.url)
        case "title":
            delegate?.webViewController?(self, didChangeTitle: webView.title as NSString?)
        case "loading":
            if let val = change?[NSKeyValueChangeKey.newKey] as? Bool {
                if !val {
                    showLoading(false)
                    backForwardListChanged()
                    delegate?.webViewController?(self, didFinishLoading: webView.url)
                }
            }
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: Overrides
    
    // Override this property getter to show bottom toolbar above other toolbars
    override open var edgesForExtendedLayout: UIRectEdge {
        get {
            return UIRectEdge(rawValue: super.edgesForExtendedLayout.rawValue ^ UIRectEdge.bottom.rawValue)
        }
        set {
            super.edgesForExtendedLayout = newValue
        }
    }
    
    // MARK: Life Cycle
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up toolbarContainer
        self.view.addSubview(toolbarContainer)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-0-[toolbarContainer]-0-|", options: [], metrics: nil, views: ["toolbarContainer": toolbarContainer]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[toolbarContainer]-0-|", options: [], metrics: nil, views: ["toolbarContainer": toolbarContainer]))
        toolbarHeightConstraint = NSLayoutConstraint(item: toolbarContainer, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: toolbarHeight)
        toolbarContainer.addConstraint(toolbarHeightConstraint)
        
        // Set up webView
        self.view.addSubview(webView)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-0-[webView]-0-|", options: [], metrics: nil, views: ["webView": webView as WKWebView]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[topGuide]-0-[webView]-0-[toolbarContainer]|", options: [], metrics: nil, views: ["webView": webView as WKWebView, "toolbarContainer": toolbarContainer, "topGuide": self.topLayoutGuide]))
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "loading", options: .new, context: nil)
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webView.removeObserver(self, forKeyPath: "estimatedProgress")
        webView.removeObserver(self, forKeyPath: "URL")
        webView.removeObserver(self, forKeyPath: "title")
        webView.removeObserver(self, forKeyPath: "loading")
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navVC = self.navigationController {
            if let gestureRecognizer = navVC.interactivePopGestureRecognizer {
                navControllerUsesBackSwipe = gestureRecognizer.isEnabled
            } else {
                navControllerUsesBackSwipe = false
            }
        }
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if navControllerUsesBackSwipe {
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
    
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        webView.stopLoading()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    static var config: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        return config
    }
    
    open func commonInit() {
        GDWebViewController.config.websiteDataStore.httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                GDWebViewController.config.websiteDataStore.httpCookieStore.delete(cookie, completionHandler: nil)
            }
            if let cookies = HTTPCookieStorage.shared.cookies {
                for cookie in cookies {
                    let store = GDWebViewController.config.websiteDataStore.httpCookieStore
                    store.setCookie(cookie, completionHandler: nil)
                }
            }
        }
        webView = WKWebView(frame: CGRect.zero, configuration: GDWebViewController.config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        toolbarContainer = GDWebViewNavigationToolbar(delegate: self)
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
    }
}
