import AVFoundation
import SwiftUI
import UIKit
import Vision
import VisionKit

struct QRScannerView: View {
    let onScan: (String) -> Void
    let onEnterManually: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var state: ScannerState = .checking
    @State private var didDeliverResult = false
    @State private var showsPairingHelp = false
    @State private var shouldRecheckAfterSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            scannerContent
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            scannerHeader
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            manualEntryRegion
        }
        .task { await prepareScanner() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, shouldRecheckAfterSettings else { return }
            shouldRecheckAfterSettings = false
            Task { await prepareScanner() }
        }
        .alert("Where to Find the QR Code", isPresented: $showsPairingHelp) {
            Button("Got It", role: .cancel) { }
        } message: {
            Text("In QuickMail on the web, open Settings, then Connect mobile app. Keep the code visible on your computer and scan it with this camera.")
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var scannerContent: some View {
        switch state {
        case .checking:
            scannerStatus(
                title: "Preparing camera...",
                message: "QuickMail is checking camera access.",
                showsProgress: true
            )
        case .ready:
            liveScanner
        case .permissionDenied:
            scannerStatus(
                title: "Camera Access Needed",
                message: "Allow camera access in Settings, or enter the server and pairing code manually.",
                actionTitle: "Open Settings",
                action: openSettings
            )
        case .unavailable(let message):
            scannerStatus(
                title: "Scanner Unavailable",
                message: message
            )
        case .failed(let message):
            scannerStatus(
                title: "Couldn't Start Scanner",
                message: message,
                actionTitle: "Try Again",
                action: { Task { await prepareScanner() } }
            )
        }
    }

    private var scannerHeader: some View {
        ZStack {
            Text("Scan QR code")
                .font(.system(.headline, design: .default, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .frame(minWidth: 44, minHeight: 44)

                Spacer()

                Button("How to pair") {
                    showsPairingHelp = true
                }
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.72))
    }

    private var manualEntryRegion: some View {
        VStack(spacing: 0) {
            Button {
                dismiss()
                onEnterManually()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "keyboard")
                        .font(.subheadline.weight(.semibold))
                    Text("Enter code manually")
                        .font(.system(.headline, design: .default, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    ScannerStyle.coral,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Closes the scanner and opens manual pairing fields")
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(ScannerStyle.ink)
    }

    private var liveScanner: some View {
        GeometryReader { geometry in
            ZStack {
                DataScannerRepresentable(
                    onValue: deliver,
                    onFailure: { message in state = .failed(message) }
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 48)

                    ScannerCornerBrackets()
                        .stroke(
                            .white.opacity(0.94),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .frame(
                            width: viewfinderSide(in: geometry.size),
                            height: viewfinderSide(in: geometry.size)
                        )
                        .accessibilityHidden(true)

                    Text("Align the code inside the frame")
                        .font(.system(.subheadline, design: .default, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                        .padding(.top, 20)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 44)
                .padding(.bottom, 112)
            }
        }
        .ignoresSafeArea()
    }

    private func scannerStatus(
        title: String,
        message: String,
        showsProgress: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 14) {
            if showsProgress {
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
            } else {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(ScannerStyle.sage)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.system(.title3, design: .default, weight: .semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(.body, design: .default, weight: .regular))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(ScannerStyle.coral)
                    .padding(.top, 4)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func viewfinderSide(in size: CGSize) -> CGFloat {
        min(320, max(160, min(size.width - 56, size.height * 0.48)))
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        shouldRecheckAfterSettings = true
        openURL(settingsURL)
    }

    @MainActor
    private func prepareScanner() async {
        state = .checking

        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            state = .unavailable("Camera scanning has not been enabled for this build. Enter the pairing details manually.")
            return
        }
        guard DataScannerViewController.isSupported else {
            state = .unavailable("This device does not support live QR scanning. Enter the pairing details manually.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            state = DataScannerViewController.isAvailable
                ? .ready
                : .unavailable("The camera is currently unavailable. Close other camera apps and try again.")
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard !Task.isCancelled else { return }
            state = granted && DataScannerViewController.isAvailable ? .ready : .permissionDenied
        case .denied, .restricted:
            state = .permissionDenied
        @unknown default:
            state = .unavailable("The camera is currently unavailable. Enter the pairing details manually.")
        }
    }

    private func deliver(_ value: String) {
        guard !didDeliverResult else { return }
        didDeliverResult = true
        onScan(value)
        dismiss()
    }
}

private enum ScannerStyle {
    static let ink = Color(red: 0.055, green: 0.071, blue: 0.078)
    static let coral = Color(red: 0.875, green: 0.365, blue: 0.302)
    static let sage = Color(red: 0.510, green: 0.650, blue: 0.560)
}

private struct ScannerCornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.18
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        return path
    }
}

private enum ScannerState: Equatable {
    case checking
    case ready
    case permissionDenied
    case unavailable(String)
    case failed(String)
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onValue: (String) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onValue: onValue, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !context.coordinator.didStart else { return }
        context.coordinator.didStart = true
        do {
            try controller.startScanning()
        } catch {
            context.coordinator.onFailure("The camera could not begin scanning. \(error.localizedDescription)")
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onValue: (String) -> Void
        let onFailure: (String) -> Void
        var didStart = false
        private var didRecognizeCode = false

        init(onValue: @escaping (String) -> Void, onFailure: @escaping (String) -> Void) {
            self.onValue = onValue
            self.onFailure = onFailure
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didRecognizeCode else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue else { continue }
                didRecognizeCode = true
                dataScanner.stopScanning()
                onValue(payload)
                return
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            onFailure("Live scanning became unavailable. \(error.localizedDescription)")
        }
    }
}
