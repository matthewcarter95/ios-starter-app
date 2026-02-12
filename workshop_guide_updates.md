# Workshop Guide Updates - MFA SMS Enrollment

Copy and paste these sections into your Google Doc at the indicated locations.

---

## UPDATE 1: Add after Step 8 (Grant Types)

**INSERT THIS AS NEW STEP 8a:**

---

**8a. Enable My Account API (Early Access)**

The My Account API allows users to manage their own MFA enrollments directly from your app. This feature is currently in Early Access.

1. Contact Auth0 support to enable the **My Account API** for your tenant
2. Once enabled, verify it's working by checking the Auth0 Dashboard under **Applications > APIs**
3. You should see the My Account API (`https://your-tenant.auth0.com/me/`) listed

> **Note:** This step is required for the post-login MFA management features covered later in this workshop. If you skip this step, the MFA enrollment during login will still work, but users won't be able to manage their MFA from the home screen.

---

## UPDATE 2: Expand "Enable MFA for your application" Section

**ADD THIS AFTER the existing MFA setup steps (after "You should be prompted to enroll in SMS for MFA"):**

---

**MFA SMS Enrollment During Native Login**

When using native login flows, the app needs to handle MFA enrollment for users who don't yet have MFA configured.

**How it works:**

When a user without MFA attempts to sign in and MFA is required by your tenant policy:
1. The login attempt returns an `association_required` error (not `mfa_required`)
2. This error includes an `mfa_token` needed to enroll the user
3. The app prompts the user to enter their phone number
4. The app calls Auth0's `/mfa/associate` endpoint to send an SMS
5. User enters the OTP code received via SMS
6. Enrollment completes and user is authenticated

**Auth0 Dashboard Requirements:**

- MFA Grant Type must be enabled (already done in step 7)
- Phone Message > SMS factor must be enabled (already done above)

**Code Implementation:**

See `AuthViewController.swift` for the implementation:

```swift
// Detect association_required error (user needs to enroll)
if let authErr = error as? Auth0.AuthenticationError,
   let code = authErr.info["error"] as? String,
   code == "association_required",
   let mfaToken = authErr.info["mfa_token"] as? String {

    // Start enrollment flow
    self.handleMfaEnrollment(mfaToken: mfaToken)
}
```

**Key Methods:**
- `handleMfaEnrollment(mfaToken:)` - Shows phone number input dialog
- `enrollPhoneNumber(mfaToken:phoneNumber:)` - Calls `/mfa/associate` to send SMS
- `showEnrollmentOtpDialog(mfaToken:oobCode:)` - Shows OTP verification dialog

**Testing:**

1. Create a new user (who has never enrolled in MFA)
2. Enable "Require Multi-factor Auth" > "Always" in Auth0 Dashboard
3. Sign in using native flow (toggle Flow Picker ON in app settings)
4. You should see the phone number enrollment prompt
5. Enter phone number, receive SMS, enter OTP
6. User is now enrolled and authenticated

---

## UPDATE 3: Add NEW Section "MFA Management (My Account API)"

**INSERT THIS AS A NEW SECTION after "MFA with native flow":**

---

## MFA Management via My Account API

After a user is signed in, they can manage their MFA enrollments directly from the app using Auth0's My Account API. This provides a self-service experience without requiring users to go through the login flow again.

**Prerequisites:**

- My Account API must be enabled for your tenant (see step 8a)
- User must be signed in with a valid session
- The app must have refresh tokens (offline_access scope)

**Auth0 Dashboard Configuration:**

The app automatically requests these scopes when exchanging tokens for My Account API access:
- `read:me:authentication_methods` - View enrolled MFA methods
- `create:me:authentication_methods` - Enroll new MFA methods
- `delete:me:authentication_methods` - Remove MFA methods

No additional dashboard configuration is needed beyond enabling My Account API.

**App Features:**

The home screen now includes an MFA Management section (visible when signed in):

1. **Check Enrollment Status**
   - Automatically checks if user has SMS MFA enrolled
   - Displays "SMS MFA Enrolled ✓" or "Not Enrolled"

2. **Enroll SMS MFA**
   - Tap "Enroll SMS MFA" button
   - Enter phone number
   - Receive and enter OTP code
   - MFA is now enrolled

3. **Delete SMS MFA**
   - Tap "Delete MFA" button
   - Confirm deletion (biometric auth required if enabled)
   - MFA enrollment is removed

**Code Implementation:**

See `HomeViewController.swift` for the implementation:

**Token Exchange:**
```swift
// Get My Account API credentials using SDK
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
        // Returns PhoneEnrollmentChallenge
        // Contains: authenticationId, authenticationSession
    }
```

**Confirm Enrollment (after user enters OTP):**
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

**Key SDK Types:**

| Type | Properties | Description |
|------|------------|-------------|
| `PhoneEnrollmentChallenge` | `authenticationId`, `authenticationSession` | Returned from `enrollPhone()`, needed for `confirmPhoneEnrollment()` |

**Testing:**

1. Sign in to the app (using browser or native flow)
2. On the home screen, look for the MFA Management section
3. If not enrolled, tap "Enroll SMS MFA"
4. Enter phone number and verify with OTP
5. Status should change to "SMS MFA Enrolled ✓"
6. Tap "Delete MFA" to remove enrollment
7. Confirm with biometric (if enabled) or just confirm
8. Status returns to "Not Enrolled"

**Error Handling:**

The app handles these common scenarios:
- **Token exchange fails**: Shows error message, allows retry
- **Invalid phone number**: Shows error, allows re-entry
- **Wrong OTP code**: Shows error, allows retry
- **MFA token timeout**: ~5 minute expiration, user must restart flow
- **Network errors**: Shows appropriate error messages

---

## Summary of New Features

| Feature | Location | Auth0 API |
|---------|----------|-----------|
| MFA Enrollment During Login | `AuthViewController.swift` | `/mfa/associate` |
| Check MFA Status | `HomeViewController.swift` | My Account API - `getAuthenticationMethods` |
| Enroll MFA Post-Login | `HomeViewController.swift` | My Account API - `enrollPhone` + `confirmPhoneEnrollment` |
| Delete MFA | `HomeViewController.swift` | My Account API - `deleteAuthenticationMethod` |

---

## Updated Workshop Flow

After completing all sections, your app will support:

1. ✅ Browser-based Universal Login
2. ✅ Native login with username/password
3. ✅ Session management with refresh tokens
4. ✅ Biometric authentication for session protection
5. ✅ MFA verification (for users already enrolled)
6. ✅ **NEW:** MFA enrollment during native login
7. ✅ **NEW:** Post-login MFA management (enroll/delete)

---

**THAT'S ALL FOR THE UPDATES!**

The workshop now covers the complete MFA lifecycle:
- Enrollment during authentication (when required)
- Verification during authentication (for enrolled users)
- Self-service management after authentication
