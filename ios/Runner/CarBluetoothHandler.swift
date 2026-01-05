import Flutter
import AVFoundation

/// Handler for Car Bluetooth detection on iOS
/// 
/// iOS Limitations:
/// - iOS does not allow apps to directly access Bluetooth Classic connection states
/// - This implementation uses AVAudioSession route changes as a best-effort solution
/// - When audio routes change to/from Bluetooth (car), we detect it
/// - This is not 100% reliable but is the best available approach on iOS
/// 
/// Note: For full functionality, iOS apps would need to use Core Bluetooth (BLE only)
/// or request special entitlements from Apple (which are typically denied).
class CarBluetoothHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.findmycar/car_bluetooth",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.findmycar/car_bluetooth_events",
            binaryMessenger: registrar.messenger()
        )
        let instance = CarBluetoothHandler()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    private var audioSession: AVAudioSession?
    private var isMonitoring = false
    private var eventSink: FlutterEventSink?
    
    override init() {
        super.init()
        audioSession = AVAudioSession.sharedInstance()
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(result: result)
        case "startMonitoring":
            startMonitoring(result: result)
        case "stopMonitoring":
            stopMonitoring(result: result)
        case "getPairedDevices":
            getPairedDevices(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initialize(result: @escaping FlutterResult) {
        // On iOS, we can't directly check Bluetooth availability
        // We'll assume it's available and use audio route monitoring
        result(true)
    }
    
    private func startMonitoring(result: @escaping FlutterResult) {
        if isMonitoring {
            result(true)
            return
        }
        
        do {
            try audioSession?.setCategory(.playback, mode: .default)
            try audioSession?.setActive(true)
            
            // Observe audio route changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )
            
            isMonitoring = true
            result(true)
        } catch {
            result(FlutterError(
                code: "AUDIO_SESSION_ERROR",
                message: "Failed to set up audio session: \(error.localizedDescription)",
                details: nil
            ))
        }
    }
    
    private func stopMonitoring(result: @escaping FlutterResult) {
        if !isMonitoring {
            result(true)
            return
        }
        
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        isMonitoring = false
        result(true)
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        let currentRoute = audioSession?.currentRoute
        
        // Check if route changed to/from Bluetooth
        let hasBluetoothOutput = currentRoute?.outputs.contains { output in
            output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE
        } ?? false
        
        // Determine connection state
        let isConnected: Bool
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            isConnected = hasBluetoothOutput
        default:
            isConnected = hasBluetoothOutput
        }
        
        // Get device name from current route
        let deviceName = currentRoute?.outputs.first?.portName ?? "Unknown"
        let deviceId = currentRoute?.outputs.first?.uid ?? "unknown"
        
        // Send event through event channel
        let eventData: [String: Any] = [
            "isConnected": isConnected,
            "deviceId": deviceId,
            "deviceName": deviceName
        ]
        eventSink?(eventData)
    }
    
    private func getPairedDevices(result: @escaping FlutterResult) {
        // iOS doesn't allow apps to get list of paired Bluetooth devices
        // Return empty list and note the limitation
        result([])
    }
    
    // MARK: - FlutterStreamHandler
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

