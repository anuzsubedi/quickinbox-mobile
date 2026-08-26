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
    @State private var state: ScannerState = .checking
    @State private var didDeliverResult = false
    @State private var showsPairingHelp = false

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .checking:
                    ProgressView("Preparing camera…")
                case .ready:
                    scanner
                case .permissionDenied:
                    ContentUnavailableView {
                        Label("Camera Access Needed", systemImage: "camera.fill")
                    } description: {
                        Text("Allow camera access in Settings, or enter the server and pairing code manually.")
                    } actions: {
                        Button("Open Settings") {
                            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(settingsURL)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .unavailable(let message):
                    ContentUnavailableView {
                        Label("Scanner Unavailable", systemImage: "qrcode.viewfinder")
                    } description: {
                        Text(message)
                    }
                case .failed(let message):
                    ErrorStateView(title: "Couldn’t Start Scanner", message: message) {
                        Task { await prepareScanner() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    dismiss()
                    onEnterManually()
                } label: {
                    Label("Enter Code Manually", systemImage: "keyboard")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
                .accessibilityHint("Closes the scanner and opens manual pairing fields")
            }
            .navigationTitle("Scan Pairing Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsPairingHelp = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Where to find the QR code")
                }
            }
        }
        .task { await prepareScanner() }
        .alert("Where to Find the QR Code", isPresented: $showsPairingHelp) {
            Button("Got It", role: .cancel) { }
        } message: {
            Text("In QuickMail on the web, open Settings, then Connect mobile app. Keep the QR code visible on your computer and scan it with this camera.")
        }
    }

    private var scanner: some View {
        ZStack {
            DataScannerRepresentable(
                onValue: deliver,
                onFailure: { message in state = .failed(message) }
            )
            .ignoresSafeArea(edges: .bottom)

            VStack {
                Spacer()
                scannerGuidance
                    .padding()
            }
        }
    }

    private var scannerGuidance: some View {
        Label(
            "Point the camera at the QR code in QuickMail Settings",
            systemImage: "qrcode"
        )
        .font(.subheadline.weight(.medium))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
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
