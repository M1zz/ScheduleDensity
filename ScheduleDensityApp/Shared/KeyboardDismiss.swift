//
//  KeyboardDismiss.swift
//  ScheduleDensityApp
//
//  화면의 다른 데를 톡 치면 키보드가 내려가게 한다.
//
//  할 일을 적다 말고 다른 걸 보려는데 키보드가 화면 절반을 덮고 있으면,
//  그걸 닫으려고 엔터를 치거나 아래로 쓸어내리는 법을 따로 배워야 한다.
//  아무 데나 누르면 닫히는 게 사람들이 이미 아는 방식이다.
//

import SwiftUI
import UIKit

/// 창(window) 하나에 탭 인식기를 한 번만 달아 두고, 톡 칠 때마다 편집을 끝낸다.
/// 시트도 같은 창 안에 뜨므로 일정 추가 화면까지 함께 적용된다.
enum KeyboardDismissOnTap {
    private static let handler = TapHandler()
    private static var installedWindows = NSHashTable<UIWindow>.weakObjects()

    /// 앱이 뜬 뒤 한 번 부른다. 창을 아직 못 찾으면 잠깐 뒤에 한 번 더 시도한다.
    static func install() {
        guard !attach() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { _ = attach() }
    }

    @discardableResult
    private static func attach() -> Bool {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else { return false }

        guard !installedWindows.contains(window) else { return true }

        let tap = UITapGestureRecognizer(target: handler, action: #selector(TapHandler.dismiss(_:)))
        // 원래 눌린 것은 그대로 눌려야 한다. 키보드를 닫으려다 버튼을 못 누르면 안 되니까.
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.delegate = handler
        window.addGestureRecognizer(tap)
        installedWindows.add(window)
        return true
    }
}

private final class TapHandler: NSObject, UIGestureRecognizerDelegate {
    @objc func dismiss(_ sender: UITapGestureRecognizer) {
        sender.view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        // 글자 칸을 누른 건 키보드를 열거나 커서를 옮기려는 손짓이다. 그건 건드리지 않는다.
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    /// 다른 제스처(탭·꾹 누르기·스크롤)와 다투지 않고 나란히 인식된다.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
