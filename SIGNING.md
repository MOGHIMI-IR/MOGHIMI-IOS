# iOS signing and Apple account setup

A developer identity must belong to the owner of the Moghimi app. Do not use another developer's certificate, borrowed Team ID, fake author signature, or a certificate embedded in source control.

## Required identifiers

Register these identifiers under the owner's Apple Developer team:

- App bundle ID: `com.moghimi.vpn.ios`
- Packet Tunnel extension bundle ID: `com.moghimi.vpn.ios.PacketTunnel`
- App Group: `group.com.moghimi.vpn.ios`

Enable the Network Extensions capability with **Packet Tunnel Provider** and the App Group for the app and its extension. Apple's entitlement documentation: https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.networking.networkextension

## App Store requirement for VPN apps

Apple App Review Guideline 5.4 states that VPN apps offered through the App Store may only be offered by developers enrolled as an organization. Organization enrollment and the required privacy declaration/policy are Apple requirements, not code settings.

## GitHub Actions secrets

The optional manual workflow expects these repository secrets:

- `IOS_TEAM_ID`: the owner's Apple Team ID.
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID.
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer UUID.
- `APP_STORE_CONNECT_PRIVATE_KEY`: full contents of the owner's private `.p8` API key.

Store the API key only in GitHub Actions Secrets. Never paste it into ChatGPT or commit it to the repository. The key must have sufficient access to manage signing/provisioning for the app.

The signed workflow uses automatic Xcode provisioning and exports a signed IPA artifact. It does not upload to TestFlight or the App Store. Apple must have granted the Network Extension capability to this team; otherwise provisioning will fail.

## What cannot be created without your account

I cannot create an Apple certificate, provisioning profile, developer identity, Team ID or App Store Connect key on your behalf. Those credentials must be issued by your Apple Developer account. The unsigned CI artifact is only a compile/package check and is not a usable VPN install.
