import Foundation

nonisolated enum AppPreferences {
    static let selectedSendingAddressID = "quickmail.selectedSendingAddressID"
    static let cachedUser = "quickmail.cachedUser"
    static let showRemoteImagesByDefault = "quickmail.privacy.showRemoteImagesByDefault"
    // Keep the original storage key so existing theme choices migrate automatically.
    static let appThemeID = "quickmail.appearance.appCanvasStyle"
}
