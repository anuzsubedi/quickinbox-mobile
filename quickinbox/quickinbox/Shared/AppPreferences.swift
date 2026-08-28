import Foundation

nonisolated enum AppPreferences {
    static let selectedSendingAddressID = "quickinbox.selectedSendingAddressID"
    static let cachedUser = "quickinbox.cachedUser"
    static let showRemoteImagesByDefault = "quickinbox.privacy.showRemoteImagesByDefault"
    // Keep the original storage key so existing theme choices migrate automatically.
    static let appThemeID = "quickinbox.appearance.appCanvasStyle"
}
