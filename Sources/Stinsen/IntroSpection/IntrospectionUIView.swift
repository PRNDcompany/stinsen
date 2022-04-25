//
//  IntrospectionUIView.swift
//  
//
//  Created by wani on 2022/04/25.
//

#if os(iOS)
import UIKit


@available(iOS 13.0, *)
class IntrospectionUIView: UIView {

    required init() {
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
