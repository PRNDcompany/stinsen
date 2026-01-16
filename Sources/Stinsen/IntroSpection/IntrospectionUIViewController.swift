//
//  IntrospectionUIViewController.swift
//  
//
//  Created by wani on 2022/04/25.
//

#if os(iOS)
import UIKit

@available(iOS 13.0, tvOS 13.0, macOS 10.15.0, *)
class IntrospectionUIViewController: UIViewController {
    
    var handler: ((IntrospectionUIViewController) -> Void)? = nil

    required init() {
        super.init(nibName: nil, bundle: nil)
        view = IntrospectionUIView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        handler?(self)
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        handler?(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        handler?(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handler?(self)
    }
}
#endif
