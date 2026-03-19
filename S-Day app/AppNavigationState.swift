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

final class AppNavigationState: ObservableObject {
    @Published var selectedTab: AppTab = .overview
    @Published var preOpSearchText: String = ""
    @Published var postOpSearchText: String = ""
    @Published var preOpJumpTarget: PreOpJumpTarget?

    func showPreOp(date: Date?) {
        preOpSearchText = ""
        if let date {
            preOpJumpTarget = .surgeryDate(Calendar.current.startOfDay(for: date))
        } else {
            preOpJumpTarget = .unscheduled
        }
        selectedTab = .preOp
    }

    func showPreOp(searchText: String) {
        preOpJumpTarget = nil
        preOpSearchText = searchText
        selectedTab = .preOp
    }

    func showPostOp(searchText: String = "") {
        postOpSearchText = searchText
        selectedTab = .postOp
    }
}
