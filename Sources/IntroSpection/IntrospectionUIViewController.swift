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
    required init() {
        super.init(nibName: nil, bundle: nil)
        view = IntrospectionUIView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
