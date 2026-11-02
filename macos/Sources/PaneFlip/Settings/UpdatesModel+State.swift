import Foundation
import Observation
import PaneFlipCore

extension UpdatesModel {
    enum State: Equatable {
        case idle, checking, upToDate, failed
        case available(ReleaseInfo)
        case installing(ReleaseInfo)
        case installFailed(ReleaseInfo)
    }
}
