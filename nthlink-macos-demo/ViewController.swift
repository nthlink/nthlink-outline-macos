import Cocoa
import NetworkExtension

let appGroup = "group.com.outline.sdk"
let config_server_key = "CONFIG_SERVER"
let config_encrypt_key = "CONFIG_ENCRYPT"
let config_password_key = "CONFIG_PASSWORD"

class ViewController: NSViewController {
    public var vpnManager = NEVPNManager.shared()

    @IBOutlet weak var status: NSTextField!
    
    @IBOutlet weak var toggleSwitch: NSSwitch!
    
    @IBAction func toggle(_ sender: Any) {
        self.vpnManager.isEnabled = true
        self.vpnManager.saveToPreferences { error in
            guard error == nil else {
                print("Unable to save VPN configuration: \(String(describing: error))")
                return
            }
            self.vpnManager.loadFromPreferences { error in
                guard error == nil else {
                    print("Unable to load VPN configuration: \(String(describing: error))")
                    return
                }

                NotificationCenter.default.addObserver(self, selector: #selector(self.updateVpnStatus), name: NSNotification.Name.NEVPNStatusDidChange, object: self.vpnManager.connection)

                switch self.vpnManager.connection.status {
                case .disconnected, .invalid:
                    do {
                        UserDefaults.init(suiteName: appGroup)?.set("159.203.107.7:443", forKey: config_server_key)
                        UserDefaults.init(suiteName: appGroup)?.set("chacha20-ietf-poly1305", forKey: config_encrypt_key)
                        UserDefaults.init(suiteName: appGroup)?.set("r6WCeI6GwYrEQDAq7aEvxQ", forKey: config_password_key)
                        try self.vpnManager.connection.startVPNTunnel()
                    } catch {
                        print("Unable to start VPN tunnel: \(error)")
                    }
                default:
                    self.vpnManager.connection.stopVPNTunnel()
                }
            }
        }
    }
    
    func loadOrCreateVPNManager(completionHandler: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences(completionHandler: { managers, error in
            guard let managers = managers, error == nil else {
                completionHandler(error)
                return
            }
            // Take an existing VPN configuration or create a new one if none exist.
            if managers.count > 0 {
                self.vpnManager = managers[0]
            } else {
                let manager = NETunnelProviderManager()
                manager.protocolConfiguration = NETunnelProviderProtocol()
                manager.localizedDescription = "VPN"
                manager.protocolConfiguration?.serverAddress = "VPN"
                manager.saveToPreferences { error in
                    guard error == nil else {
                        completionHandler(error)
                        return
                    }
                    manager.loadFromPreferences { error in
                        self.vpnManager = manager
                    }
                }
            }
            completionHandler(nil)
        })
    }
    
    @objc func updateVpnStatus() {
        // Update label according to VPN connection status.
        switch vpnManager.connection.status {
        case .connected:
            status.stringValue = "Connected"
            toggleSwitch.state = .on
            break
        case .connecting:
            status.stringValue = "Connecting"
            toggleSwitch.state = .on
            break
        case .disconnected:
            status.stringValue = "Disconnected"
            toggleSwitch.state = .off
            break
        case .disconnecting:
            status.stringValue = "Disconnecting"
            toggleSwitch.state = .on
            break
        case .invalid:
            status.stringValue = "Invalid"
            toggleSwitch.state = .off
            break
        case .reasserting:
            status.stringValue = "Reasserting"
            toggleSwitch.state = .on
            break
        default:
            status.stringValue = "Unknown"
            toggleSwitch.state = .off
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load or create a VPN configuration, this will ask user for VPN permission for the first time.
        loadOrCreateVPNManager(completionHandler: { error in
            guard error == nil else {
                print("Unable to load or create VPN manager: \(String(describing: error))")
                return
            }
            self.updateVpnStatus()
            // Observe VPN connection status changes.
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateVpnStatus), name: NSNotification.Name.NEVPNStatusDidChange, object: self.vpnManager.connection)
        })
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: self.vpnManager.connection)
    }
}

