# iOS Auth0 Workshop

A hands-on workshop for building a secure iOS app with Auth0 authentication. You'll implement browser-based Universal Login and native authentication flows, manage user sessions with biometric protection, and configure multi-factor authentication (MFA) using SMS — including enrollment during login and post-login self-service management.

**Estimated duration: 2–3 hours**

## What You'll Build

- A fully functional iOS app with Auth0 integration
- Support for multiple authentication methods (browser redirect and native flows)
- Secure session management with refresh tokens and biometric authentication
- Multi-factor authentication with SMS verification
- MFA enrollment during native login flows
- Self-service MFA management via the My Account API

## What You'll Learn

- Setting up an Auth0 tenant and application configuration
- Implementing OAuth 2.0 / OIDC flows in iOS
- Integrating the Auth0.swift SDK into an iOS app
- Managing secure credential storage with the Keychain
- Universal Links vs. Custom URL Schemes
- Native login screens as an alternative to browser-based flows
- Implementing and testing multi-factor authentication
- Handling MFA enrollment during authentication
- Enabling users to manage their own MFA enrollments

## Prerequisites

- Xcode installed on macOS
- Basic familiarity with Swift and iOS development
- An Auth0 account (free tier works fine)
- Optional: A paid Apple Developer account (required for Universal Links; free accounts can use Custom URL Schemes)

---

## Workshop Steps

### Step 1 — Create a New Auth0 Tenant

Create a new Auth0 tenant for this workshop.

### Step 2 — Accept Invitation

If working with a team using a shared demo environment, accept the tenant invitation.

### Step 3 — Add an SMS Provider (for later)

You'll come back to this later, but set it up now:

1. Go to **Authentication > Multi-factor Auth > Phone Message**
2. Attach component → **Twilio SMS Provider for Auth0**
3. Configure your Twilio credentials

### Step 4 — Create a Native App Integration

1. Go to **Applications > Applications**
2. Click **Create Application**
3. Choose **Native** as the application type
4. Give it a name (e.g., `Workshop iOS App`)

### Step 5 — Configure Callback and Logout URLs

In your application settings, add these URLs. Replace `{YOUR_AUTH0_DOMAIN}` with your tenant domain (e.g., `dev-abc123.us.auth0.com`).

**Allowed Callback URLs:**
```
https://{YOUR_AUTH0_DOMAIN}/ios/com.jmdevlabs.workshop/callback,
com.jmdevlabs.workshop://{YOUR_AUTH0_DOMAIN}/ios/com.jmdevlabs.workshop/callback
```

**Allowed Logout URLs:**
```
https://{YOUR_AUTH0_DOMAIN}/ios/com.jmdevlabs.workshop/callback,
com.jmdevlabs.workshop://{YOUR_AUTH0_DOMAIN}/ios/com.jmdevlabs.workshop/callback
```

### Step 6 — Disable Non-Verifiable Callback URI Confirmation

Inside the native application integration:

1. Go to the **Settings** tab
2. Scroll to **Advanced Settings > OAuth**
3. Find **Non-Verifiable Callback URI End-User Confirmation**
4. Check **Override tenant settings**
5. Toggle the confirmation **OFF**

> This is for demo purposes to avoid Auth0 consent screens.

### Step 7 — Configure Grant Types

Under **Advanced Settings > Grant Types**, enable:

- ✅ Authorization Code
- ✅ Refresh Token
- ✅ Password (Resource Owner Password)
- ✅ MFA
- ❌ Implicit (disable)

### Step 8 — Download the Repository

```bash
git clone https://github.com/juanquintero-okta/workshop-ios.git
cd workshop-ios
```

### Step 8a — Enable My Account API (Early Access)

The My Account API allows users to manage their own MFA enrollments directly from your app.

- Contact Auth0 support to enable the My Account API for your tenant
- Once enabled, verify it appears in the Auth0 Dashboard under **Applications > APIs** as `https://your-tenant.auth0.com/me/`

> This step is required for the post-login MFA management features covered later. MFA enrollment during login will still work without it.

### Step 9 — Check Package Dependencies

1. Open the project in Xcode
2. Go to the **Package Dependencies** tab
3. Confirm the **Auth0.swift** dependency is present (Xcode will resolve it automatically)

### Step 10 — Configure Auth0.plist

Open `workshop/Auth0.plist` in Xcode (right-click → **Open As > Source Code**) and replace the placeholder values with your Auth0 application credentials:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ClientId</key>
    <string>YOUR_AUTH0_CLIENT_ID</string>
    <key>Domain</key>
    <string>YOUR_AUTH0_DOMAIN</string>
</dict>
</plist>
```

### Step 11a — Custom URL Scheme (Default)

Unless you have a paid Apple Developer account, use the custom URL scheme already configured in the project. **Skip to Step 12.**

### Step 11b — Universal Links (Optional — Paid Developer Account Required)

If you have a paid developer account:

1. In Xcode, go to the **workshop target > Signing & Capabilities**
2. From the **Editor** menu, select **Add a capability**
3. Search for and add **Associated Domains**
4. Click **+** and add: `applinks:{YOUR_AUTH0_DOMAIN}`
   - Example: `applinks:dev-abc123.us.auth0.com`

> You may need to change the bundle ID, which can cause build issues. Using a custom URL scheme is recommended for completing this workshop.

#### Universal Links vs. Custom URL Schemes

Universal Links use real HTTPS domains verified by Apple through an `apple-app-site-association` file. Only your app — signed with your Team ID — can open those links, preventing malicious apps from intercepting authorization codes. Custom URL schemes (like `myapp://callback`) can be registered by any app on the device, which introduces interception risk.

Universal Links also provide a better UX: iOS intelligently opens your app if installed, or falls back to Safari if not, without any "Open this page in…" prompts.

---

## Let's Test It Out

### Authentication Flows Using Universal Login

Build and run the app. Test these flows:

- **Sign In** — Authenticate with an existing user
- **Sign Up** — Register a new user
- **Password Reset** — Request a password reset
- **Sign Out** — Log out of the application

Everything should work using browser-based Universal Login.

---

## Sessions

### Getting Sessions

When users open your app, check for stored credentials. If they exist and are valid (or can be renewed), you can redirect users to the main flow without requiring login again.

In the app, see `HomeViewController` → `checkCreds` → `renewCreds`. If the user is signed out, they can tap the top icon to sign in.

### Storing Sessions

When users log in, credentials are stored securely in the Keychain:

```swift
let didStore = credentialsManager.store(credentials: credentials)
```

### Biometric Authentication with Session Refresh

You can require biometric authentication (Face ID or Touch ID) before retrieving stored credentials.

**How to enable biometrics on the iOS Simulator:**
1. In the Simulator menu, go to **Features > Face ID** (or Touch ID)
2. Select **Enrolled**
3. To simulate a successful auth: **Features > Face ID > Matching Face**

### Scopes

The authentication request uses:

```swift
.scope("openid profile email offline_access")
```

> The `offline_access` scope is required for session refresh (refresh tokens).

### Audience

```swift
.audience("https://your-tenant.auth0.com/api/v2/")
```

### Using an Ephemeral Session

Find `navigateToUL` in `HomeViewController`. Uncomment this line to avoid the third-party authentication permission popup from Apple:

```swift
.useEphemeralSession()
```

---

## Native Flows

You'll now repeat the same flows using native layouts instead of browser-rendered Universal Login.

### Switch to Native Flows

1. Navigate to the **Settings** screen in the app
2. Toggle **ON** the Flow Picker

### Sign In with Native Flow

Using the same SDK, the app supports both browser redirect and native flows. See `AuthViewController.swift` for `signUp`, `signInWithPassword`, `forgotPassword`, and more.

After signing in you can:

- Sign out (same as before)
- Register a new user
- See the refresh token flow in action — sign in, close the app, reopen it (you should remain signed in)

You can toggle **biometric session protection** ON to prompt the user for Face ID / Touch ID every time the app opens and the session is refreshed.

> Before the next section: toggle the Flow Picker **OFF** and sign out.

---

## Enable MFA for Your Application

1. Go to **Security > Multi-factor Authentication**
2. Select **Phone Message > SMS** and enable it
3. Under **Require Multi-factor Auth**, select **Always**

Sign in again. You should be prompted to enroll in SMS MFA. After enrolling, you can see the factor in **User Management > Users > [your user] > Multi-factor Authentication**.

---

## MFA with Native Flow

### MFA Verification for Enrolled Users

1. Sign out of the app
2. Go to **Settings** and toggle the Flow Picker **ON**
3. Sign in using the native flow

When MFA is required, the error response contains `mfa_required` along with an MFA token, which the app uses to challenge the enrolled factor. The app will print:

```
❌ Login failed: Multifactor authentication required
🔐 MFA token: Fe26.2*SERVER_...
```

If configured correctly, a popup will appear to enter the SMS code sent to the enrolled phone number.

See `AuthViewController.swift` → `signInWithPassword` for the error handling code.

---

## MFA SMS Enrollment During Native Login

When a user without MFA attempts to sign in and MFA is required by your tenant policy:

1. Login returns an `association_required` error (not `mfa_required`)
2. The error includes an `mfa_token` needed to start enrollment
3. The app prompts the user to enter their phone number
4. The app calls `/mfa/associate` to send an enrollment SMS
5. User enters the OTP code
6. Enrollment completes and the user is authenticated

### Code

```swift
// Detect association_required (user needs to enroll)
if let authErr = error as? Auth0.AuthenticationError,
   let code = authErr.info["error"] as? String,
   code == "association_required",
   let mfaToken = authErr.info["mfa_token"] as? String {
    self.handleMfaEnrollment(mfaToken: mfaToken)
}
```

**Key methods in `AuthViewController.swift`:**

- `handleMfaEnrollment(mfaToken:)` — Shows phone number input dialog
- `enrollPhoneNumber(mfaToken:phoneNumber:)` — Calls `/mfa/associate` to send SMS
- `showEnrollmentOtpDialog(mfaToken:oobCode:)` — Shows OTP verification dialog

### Testing

1. Create a new user (who has never enrolled in MFA)
2. Ensure **Require Multi-factor Auth > Always** is enabled
3. Toggle the Flow Picker **ON** and sign in using the native flow
4. Enter your phone number, receive the SMS, enter the OTP
5. The user is now enrolled and authenticated

---

## MFA Management via My Account API

After signing in, users can manage their MFA enrollments directly from the app without going through the login flow again.

**Prerequisites:**
- My Account API enabled on your tenant (Step 8a)
- User signed in with a valid session and `offline_access` scope

### App Features (Home Screen)

- **Check Enrollment Status** — Shows `SMS MFA Enrolled ✓` or `Not Enrolled`
- **Enroll SMS MFA** — Enter phone number, verify OTP, enrollment complete
- **Delete SMS MFA** — Confirm deletion (biometric required if enabled)

### Code (HomeViewController.swift)

**Token Exchange:**

```swift
credentialsManager.apiCredentials(
    forAudience: "https://\(domain)/me/",
    scope: "read:me:authentication_methods create:me:authentication_methods delete:me:authentication_methods"
) { result in
    // Use apiCredentials.accessToken for My Account API calls
}
```

**Check Enrollment:**

```swift
Auth0
    .myAccount(token: accessToken)
    .authenticationMethods
    .getAuthenticationMethods()
    .start { result in
        // Look for method with type == "phone"
    }
```

**Enroll Phone:**

```swift
Auth0
    .myAccount(token: accessToken)
    .authenticationMethods
    .enrollPhone(phoneNumber: phoneNumber, preferredAuthenticationMethod: .sms)
    .start { result in
        // Returns PhoneEnrollmentChallenge with authenticationId and authenticationSession
    }
```

**Confirm Enrollment:**

```swift
Auth0
    .myAccount(token: accessToken)
    .authenticationMethods
    .confirmPhoneEnrollment(
        id: challenge.authenticationId,
        authSession: challenge.authenticationSession,
        otpCode: userEnteredOtp
    )
    .start { result in
        // Enrollment complete
    }
```

**Delete MFA:**

```swift
Auth0
    .myAccount(token: accessToken)
    .authenticationMethods
    .deleteAuthenticationMethod(by: methodId)
    .start { result in
        // MFA removed
    }
```

---

## Feature Summary

| Feature | File | Auth0 API |
|---|---|---|
| Browser-based Login | `HomeViewController.swift` | OAuth 2.0 / OIDC |
| Native Login | `AuthViewController.swift` | `/oauth/token` (Password grant) |
| MFA Verification | `AuthViewController.swift` | `/oauth/token` (with MFA token) |
| MFA Enrollment During Login | `AuthViewController.swift` | `/mfa/associate` |
| Check MFA Status | `HomeViewController.swift` | My Account API |
| Enroll MFA Post-Login | `HomeViewController.swift` | My Account API |
| Delete MFA | `HomeViewController.swift` | My Account API |

---

## Project Structure

```
workshop/
├── Auth0.plist                      # Auth0 credentials — add your own values
├── AppDelegate.swift
├── SceneDelegate.swift
└── vc/
    ├── AuthViewController.swift     # Native login, sign up, MFA flows
    ├── HomeViewController.swift     # Session management, My Account API
    ├── ProfileViewController.swift  # User profile
    └── SettingViewController.swift  # Flow picker toggle
```

---

That's it! By the end of this workshop your app will support:

- ✅ Browser-based Universal Login
- ✅ Native login with username/password
- ✅ Session management with refresh tokens
- ✅ Biometric authentication for session protection
- ✅ MFA verification (for users already enrolled)
- ✅ MFA enrollment during native login
- ✅ Post-login MFA management (enroll / delete)
