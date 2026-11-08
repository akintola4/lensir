//
//  WiFiJoiner.swift
//  Lensir
//
//  Joins a network from a Wi-Fi code. That needs the Hotspot Configuration
//  capability, which is behind the LENSIR_WIFI_JOIN build setting; without
//  it the sheet offers Copy password instead.
//

import Foundation
#if WIFI_JOIN
import NetworkExtension
#endif

enum WiFiJoiner {
    static var isAvailable: Bool {
        #if WIFI_JOIN
        true
        #else
        false
        #endif
    }

    enum Outcome: Equatable {
        case joined
        case cancelled
        case failed(String)
    }

    static func join(_ wifi: WiFi) async -> Outcome {
        #if WIFI_JOIN
        let configuration: NEHotspotConfiguration = switch (wifi.security, wifi.password) {
        case (.open, _), (_, nil): NEHotspotConfiguration(ssid: wifi.ssid)
        case (.wep, let password?): NEHotspotConfiguration(ssid: wifi.ssid, passphrase: password, isWEP: true)
        case (_, let password?): NEHotspotConfiguration(ssid: wifi.ssid, passphrase: password, isWEP: false)
        }
        configuration.hidden = wifi.hidden
        configuration.joinOnce = false
        do {
            try await NEHotspotConfigurationManager.shared.apply(configuration)
            return .joined
        } catch let error as NSError where error.domain == NEHotspotConfigurationErrorDomain {
            switch NEHotspotConfigurationError(rawValue: error.code) {
            case .alreadyAssociated: return .joined
            case .userDenied: return .cancelled
            case .invalidWPAPassphrase, .invalidWEPPassphrase: return .failed("The password in the code is the wrong length.")
            case .invalidSSID: return .failed("The network name in the code isn't valid.")
            default: return .failed("iPhone couldn't join. Copy the password and join in Settings.")
            }
        } catch {
            return .failed("iPhone couldn't join. Copy the password and join in Settings.")
        }
        #else
        return .failed("Joining isn't turned on in this build.")
        #endif
    }
}
