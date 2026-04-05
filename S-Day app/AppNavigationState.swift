import Combine
import Foundation
import SwiftUI

enum AppTab: Hashable {
    case overview
    case preOp
    case postOp
    case settings
}

enum PreOpJumpTarget: Equatable {
    case unscheduled
    case surgeryDate(Date)
}

@MainActor
final class AppNavigationState: ObservableObject {
    static let shared = AppNavigationState()

    @Published var selectedTab: AppTab = .overview
    @Published var preOpSearchText: String = ""
    @Published var postOpSearchText: String = ""
    @Published var preOpJumpTarget: PreOpJumpTarget?
    @Published private(set) var preOpComposerFocusToken: Int = 0

    func showPreOp(date: Date?) {
        preOpSearchText = ""
        preOpComposerFocusToken = 0
        if let date {
            preOpJumpTarget = .surgeryDate(Calendar.current.startOfDay(for: date))
        } else {
            preOpJumpTarget = .unscheduled
        }
        selectedTab = .preOp
    }

    func showPreOp(searchText: String) {
        preOpComposerFocusToken = 0
        preOpJumpTarget = nil
        preOpSearchText = searchText
        selectedTab = .preOp
    }

    func showPreOpComposer() {
        preOpJumpTarget = nil
        preOpSearchText = ""
        selectedTab = .preOp
        preOpComposerFocusToken &+= 1
    }

    func showPostOp(searchText: String = "") {
        postOpSearchText = searchText
        selectedTab = .postOp
    }
}
