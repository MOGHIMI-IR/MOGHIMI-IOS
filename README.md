# Moghimi V2Ray for iOS

Native iOS VPN client project for Moghimi V2Ray. The project is being built separately from the Android app.

## Safety and privacy goals
- No Apple ID sign-in, Apple ID password access, or iCloud account access.
- No analytics, advertising SDK, device fingerprinting, or hidden startup VPN.
- No system VPN configuration is enabled without the user's explicit action and the iOS consent flow.
- VPN traffic is handled by the selected server; Supabase is used only to retrieve the app's active public profile list and any authorized config files.
- No self-downloading or self-installing executable updates.

## Platform
- Deployment target: iOS 15.0 (intended for iPhone 13 and newer; simulator and device verification remain required).
- SwiftUI app + Apple Network Extension Packet Tunnel.
- Xray runtime is supplied through SwiftyXrayKit / LibXray.
- One app build target is intended to cover supported iPhone models.

## Build status
Initial source setup only. A successful CI compile, signed device install, VPN tunnel test, and App Store approval are not claimed until those checks have actually completed.

## Signing requirements
A real device VPN build requires the Apple Network Extension capability and matching provisioning profiles. The certificate, private key, provisioning profile, Team ID, and bundle IDs must belong to the app owner's Apple Developer account. Never commit these files or passwords. The GitHub workflow will build unsigned artifacts by default and can be extended to sign only after the owner configures the required GitHub Actions secrets.

Apple's App Store rules for VPN apps require organization enrollment and specific privacy disclosures. See [Apple App Review Guidelines, section 5.4](https://developer.apple.com/app-store/review/guidelines/).

## Upstream notices
The iOS implementation is based on the GPL-3.0-licensed palazikVPN iOS client (iliYF/xStarRay). Changes for Moghimi are identified in this repository. The full GPL-3.0 license and required notices are retained. The runtime package SwiftyXrayKit is separately licensed; see THIRD_PARTY_NOTICES.md.
