//
//  HomeViewController.swift
//  workshop
//
//  Created by Juan Quintero on 11/17/25.
//
// See more --> https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md

import UIKit
import Auth0
import JWTDecode
import LocalAuthentication

class HomeViewController: UIViewController {
    
    private struct Auth0ConfigLoader {
        static func load() -> (domain: String, clientId: String)? {
            guard
                let url = Bundle.main.url(forResource: "Auth0", withExtension: "plist"),
                let data = try? Data(contentsOf: url),
                let dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
                let domain = dict["Domain"] as? String,
                let clientId = dict["ClientId"] as? String,
                !domain.isEmpty, !clientId.isEmpty
            else { return nil }
            return (domain, clientId)
        }
    }
    
    private lazy var domain: String = {
        let config = Auth0ConfigLoader.load()
        assert(config != nil, "Missing Auth0 configuration. Provide Domain and ClientId in Auth0.plist.")
        return config?.domain ?? ""
    }()
    
    private lazy var clientId: String = {
        let config = Auth0ConfigLoader.load()
        assert(config != nil, "Missing Auth0 configuration. Provide Domain and ClientId in Auth0.plist.")
        return config?.clientId ?? ""
    }()
    
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication()) // <-- handles and store credentials. https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#credentials-manager-ios--macos--tvos--watchos--visionos
    private let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
    
    private var isBiometricEnabled: Bool = false
    private var isNativeFlowEnabled: Bool = false

    // MFA Management State
    private var enrolledMfaMethodId: String?
    private var currentMfaAccessToken: String?
    private var currentEnrollmentChallenge: PhoneEnrollmentChallenge?
    

    
    @IBOutlet weak var signInBtn: UIBarButtonItem!
    @IBOutlet weak var signOutBtn: UIBarButtonItem!
    
    @IBOutlet weak var helloLabel: UILabel!
    
    
    @IBOutlet weak var basicInfoStackView: UIStackView!
    @IBOutlet weak var tokensStackView: UIStackView!
    @IBOutlet weak var securityStackView: UIStackView!
    
    
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var unLabel: UILabel!
    @IBOutlet weak var uuidLabel: UILabel!
    @IBOutlet weak var phLabel: UILabel!
    
    
    @IBOutlet weak var idTokenLabel: UILabel!
    @IBOutlet weak var accessTokenLabel: UILabel!
    
    
    
    @IBOutlet weak var enableBiometricLabel: UILabel!
    @IBOutlet weak var enableBiometricSwitch: UISwitch!

    // MFA Management Section
    @IBOutlet weak var mfaStackView: UIStackView!
    @IBOutlet weak var mfaStatusLabel: UILabel!
    @IBOutlet weak var enrollMfaButton: UIButton!
    @IBOutlet weak var deleteMfaButton: UIButton!
    @IBOutlet weak var mfaActivityIndicator: UIActivityIndicatorView!
    
    
    @IBAction func enableBiometricSwitchTapped(_ sender: UISwitch) {
        
        if sender.isOn {
            // The user is trying to turn Face ID/Touch ID on
            promptForBiometricPermission { granted in
                if granted {
                    // If permission is granted, save the setting in UserDefaults
                    self.setBiometricAuthEnabled(sender.isOn)
                    
                } else {
                    // If permission is not granted, revert the switch to OFF
                    sender.setOn(false, animated: true)
                    
                    self.setBiometricAuthEnabled(sender.isOn)
                    
                    
                }
            }
        } else {
            // The user is turning Face ID/Touch ID off
            setBiometricAuthEnabled(sender.isOn)
        }
    }

    @IBAction func enrollMfaBtnTapped(_ sender: UIButton) {
        startMfaEnrollment()
    }

    @IBAction func deleteMfaBtnTapped(_ sender: UIButton) {
        confirmDeleteMfa()
    }


    @IBAction func signInBtnTapped(_ sender: UIBarButtonItem) {
        
        if isNativeFlowEnabled {
            navigateToNativeAuthScreen()
        } else {
            navigateToUL()
        }
        
        
    }
    
    @IBAction func signOutBtnTapped(_ sender: UIBarButtonItem) {
        
        signOut()
    }
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        basicInfoStackView.layer.cornerRadius = 16
        basicInfoStackView.clipsToBounds = true
        
        tokensStackView.layer.cornerRadius = 16
        tokensStackView.clipsToBounds = true
        
        securityStackView.layer.cornerRadius = 16
        securityStackView.clipsToBounds = true
        
        mfaStackView.layer.cornerRadius = 16
        mfaStackView.clipsToBounds = true
        
        isBiometricEnabled =  UserDefaults.standard.bool(forKey: "isBiometricEnabled")
        enableBiometricSwitch.isOn =  isBiometricEnabled
        
        isNativeFlowEnabled = UserDefaults.standard.bool(forKey: "isNativeFlowEnabled")
        
        
        checkCreds()
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        isNativeFlowEnabled = UserDefaults.standard.bool(forKey: "isNativeFlowEnabled")
        
    }
    
    
    private func checkCreds() {
        
        guard credentialsManager.canRenew() else {
            clearLayouts()
            return
        }
        
        if isBiometricEnabled {
            authenticateWithBiometricsIfNeeded { success in
                if success {
                    self.renewCreds()
                } else {
                    self.signOut()
                }
            }
        } else {
            renewCreds()
        }
    }
    
    
    private func authenticateWithBiometricsIfNeeded(completion: @escaping (Bool) -> Void) {
                
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "This app uses Face ID or Touch ID to secure user sessions."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        completion(true)
                    } else {
                        print("Biometric authentication failed: \(authenticationError?.localizedDescription ?? "Unknown error")")
                        completion(false)
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "This app uses Face ID or Touch ID to secure user sessions."
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        
                        completion(true)
                    } else {
                        print("Passcode authentication failed: \(authenticationError?.localizedDescription ?? "Unknown error")")
                        completion(false)
                    }
                }
            }
        } else {
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            completion(false)
        }
    }
    
    private func renewCreds() {

        credentialsManager
            .credentials { result in
                switch result {
                case .success(let credentials):
                    print("Obtained credentials: \(credentials)")
                    
                    guard self.credentialsManager.user != nil else {
                        return
                    }

                    self.updateUserLayouts()
                    self.updateDebugTokenLayouts(credentials: credentials)
                    
                case .failure(let error):
                    print("Failed with: \(error)")
  
                }
            }
    }
    
    private func updateUserLayouts() {
        
        DispatchQueue.main.async {
            
            let user = self.credentialsManager.user
            
            if let username = user?.email?.components(separatedBy: "@").first {
                self.helloLabel.text = "Hello \(username.uppercased())!"
            }
            
            self.unLabel.text = user?.preferredUsername
            self.uuidLabel.text = "{ \(user?.sub ?? "") }"
            self.emailLabel.text = user?.email
            
            self.securityStackView.isHidden = false

            self.signOutBtn.isHidden = false
            self.signInBtn.isHidden = true

            // Check MFA enrollment status
            self.checkMfaEnrollmentStatus()
        }


    }
    
    private func clearLayouts()  {

        DispatchQueue.main.async {

            self.helloLabel.text = "Hello user!"

            self.idTokenLabel.text = ""
            self.accessTokenLabel.text = ""
            //self.phLabel.text = ""
            self.unLabel.text = ""
            self.uuidLabel.text = ""
            self.emailLabel.text = ""

            self.securityStackView.isHidden = true

            // Hide MFA section when signed out
            self.mfaStackView?.isHidden = true
            self.enrolledMfaMethodId = nil
            self.currentMfaAccessToken = nil
            self.currentEnrollmentChallenge = nil

            self.signOutBtn.isHidden = true
            self.signInBtn.isHidden = false
        }
    }
    
    private func updateDebugTokenLayouts(credentials: Credentials) {
        // Helper function to handle JWT decoding and updating UI
        func handleJWT(_ token: String, label: UILabel) {
            do {
                // Decode the JWT
                let jwt = try decode(jwt: token)
                
                // Attempt to convert the decoded payload to a JSON string
                if let jsonData = try? JSONSerialization.data(withJSONObject: jwt.body, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    DispatchQueue.main.async {
                        label.text = jsonString
                    }
                } else {
                    print("Failed to convert JWT payload to JSON string")
                }
            } catch {
                print("Failed to decode JWT: \(error)")
            }
        }
        
        // Decode and update the idToken
        handleJWT(credentials.idToken, label: self.idTokenLabel)
        
        // Decode and update the accessToken
        handleJWT(credentials.accessToken, label: self.accessTokenLabel)
    }
    
    private func setBiometricAuthEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "isBiometricEnabled")
        
    }
    
    // Method to prompt for biometric permission
    private func promptForBiometricPermission(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if the device supports biometric authentication
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Use Face ID or Touch ID to prompt for permission
            let reason = "This app uses Face ID or Touch ID to secure user sessions."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        // Biometric authentication was successful
                        completion(true)
                    } else {
                        // User either canceled or the biometric auth failed
                        completion(false)
                    }
                }
            }
        } else {
            // Biometric authentication is not available (e.g., no Face ID or Touch ID)
            DispatchQueue.main.async {
                print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
                self.showAlert(message: "Biometric auth not available: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
            }
        }
    }
    
    
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.view.tintColor = .accent
        self.present(alert, animated: true)
    }
    
    
    
    
    private func navigateToUL() {
        
        Auth0
            .webAuth()
            //.useHTTPS() // <-- Use a Universal Link callback URL on iOS 17.4+
            .useEphemeralSession() // <-- Use an ephemeral session. Hide the 3rd party SSO popup.
            //.provider(WebAuthentication.webViewProvider()) // <-- https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#use-wkwebview-instead-of-aswebauthenticationsession
            //.useDPoP() // <-- https://auth0.com/docs/secure/sender-constraining/configure-sender-constraining
            //.parameters(["screen_hint": "signup"]) <-- Direct the user to a specifc screen within UL. https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#web-auth-signup
            .parameters(["prompt": "login"])
            .logging(enabled: true)
            .audience("https://\(domain)/api/v2/") //<-- REPLACE WITH YOUR DOMAIN + /api/v2/
            .scope("openid profile email offline_access")
            .start { result in
                switch result {
                case .success(let credentials):
                    print("Obtained credentials: \(credentials)")
                    
                    _ = self.credentialsManager.store(credentials: credentials) //<--storing the new session creds.
                    
                    self.checkCreds()
                    
                case .failure(let error):
                    print("Failed with: \(error)")
                }
            }
        
    }
    
    private func navigateToNativeAuthScreen() {
        
        if let authViewController = mainStoryboard.instantiateViewController(withIdentifier: "auth") as? AuthViewController {
            authViewController.onAuthSuccess = {
                
                [weak self] in self?.checkCreds()
                self?.checkCreds()
                
            }
            // Present modally
            authViewController.modalPresentationStyle = .automatic
            present(authViewController, animated: true, completion: nil)
                        
        }
        
    }
    
    
    private func signOut(){

//        Auth0.webAuth()
//            //.useHTTPS()
//            .clearSession { result in
//            // ...
//        }

        if !credentialsManager.clear() {
            _ = self.credentialsManager.clear() // <-- clears the session locally only. Read more: https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#logout
        }



        clearLayouts()

        UserDefaults.standard.set(false, forKey: "isBiometricEnabled")

    }

    // MARK: - MFA Management (My Account API)

    private func checkMfaEnrollmentStatus() {
        guard credentialsManager.canRenew() else { return }

        // Show loading state
        DispatchQueue.main.async {
            self.mfaStackView?.isHidden = false
            self.mfaActivityIndicator?.startAnimating()
            self.mfaStatusLabel?.isHidden = true
            self.enrollMfaButton?.isHidden = true
            self.deleteMfaButton?.isHidden = true
        }

        // Get My Account API credentials via token exchange
        getMyAccountCredentials { [weak self] accessToken in
            guard let self = self, let accessToken = accessToken else {
                DispatchQueue.main.async {
                    self?.mfaActivityIndicator?.stopAnimating()
                    self?.enrollMfaButton?.isHidden = false
                    self?.mfaStatusLabel?.text = "Unable to check MFA status"
                    self?.mfaStatusLabel?.isHidden = false
                }
                return
            }

            self.currentMfaAccessToken = accessToken
            self.fetchAuthenticationMethods(accessToken: accessToken)
        }
    }

    private func getMyAccountCredentials(completion: @escaping (String?) -> Void) {
        // Use Auth0.swift SDK's built-in apiCredentials method for My Account API
        let audience = "https://\(domain)/me/"
        let scope = "read:me:authentication_methods create:me:authentication_methods delete:me:authentication_methods"

        print("📤 Getting My Account API credentials via SDK...")

        credentialsManager.apiCredentials(forAudience: audience, scope: scope) { result in
            switch result {
            case .success(let apiCredentials):
                print("✅ Got My Account API token via SDK")
                completion(apiCredentials.accessToken)
            case .failure(let error):
                print("❌ Failed to get API credentials: \(error)")
                completion(nil)
            }
        }
    }

    private func fetchAuthenticationMethods(accessToken: String) {
        print("📤 Fetching authentication methods via SDK...")

        Auth0
            .myAccount(token: accessToken)
            .authenticationMethods
            .getAuthenticationMethods()
            .start { [weak self] result in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.mfaActivityIndicator?.stopAnimating()
                }

                switch result {
                case .success(let methods):
                    print("📨 Found \(methods.count) authentication methods")

                    // Look for phone/SMS authenticator
                    var smsMethodId: String?
                    for method in methods {
                        print("→ Method type: \(method.type), id: \(method.id)")
                        if method.type == "phone" {
                            smsMethodId = method.id
                            break
                        }
                    }

                    if let methodId = smsMethodId {
                        print("✅ SMS MFA is enrolled. Method ID: \(methodId)")
                        self.updateMfaUI(enrolled: true, methodId: methodId)
                    } else {
                        print("ℹ️ No SMS MFA enrolled")
                        self.updateMfaUI(enrolled: false, methodId: nil)
                    }

                case .failure(let error):
                    print("❌ Fetch auth methods error: \(error)")
                    self.updateMfaUI(enrolled: false, methodId: nil)
                }
            }
    }

    private func updateMfaUI(enrolled: Bool, methodId: String?) {
        DispatchQueue.main.async {
            self.enrolledMfaMethodId = methodId

            if enrolled {
                self.mfaStatusLabel?.text = "SMS MFA Enrolled ✓"
                self.mfaStatusLabel?.textColor = .systemGreen
                self.mfaStatusLabel?.isHidden = false
                self.enrollMfaButton?.isHidden = true
                self.deleteMfaButton?.isHidden = false
            } else {
                self.mfaStatusLabel?.text = "Not Enrolled"
                self.mfaStatusLabel?.textColor = .secondaryLabel
                self.mfaStatusLabel?.isHidden = false
                self.enrollMfaButton?.isHidden = false
                self.deleteMfaButton?.isHidden = true
            }
        }
    }

    private func startMfaEnrollment() {
        guard let accessToken = currentMfaAccessToken else {
            // Need to get token first
            getMyAccountCredentials { [weak self] token in
                guard let self = self, let token = token else {
                    self?.showAlert(message: "Failed to get API credentials. Please try again.")
                    return
                }
                self.currentMfaAccessToken = token
                self.showPhoneNumberDialog()
            }
            return
        }

        showPhoneNumberDialog()
    }

    private func showPhoneNumberDialog() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Enroll SMS MFA",
                message: "Enter your phone number to receive verification codes (include country code, e.g. +1)",
                preferredStyle: .alert
            )
            alert.addTextField { textField in
                textField.placeholder = "+1 555 123 4567"
                textField.keyboardType = .phonePad
            }
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
                let phone = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !phone.isEmpty {
                    self?.enrollPhone(phoneNumber: phone)
                } else {
                    self?.showAlert(message: "Please enter a valid phone number.")
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.view.tintColor = .accent
            self.present(alert, animated: true)
        }
    }

    private func enrollPhone(phoneNumber: String) {
        guard let accessToken = currentMfaAccessToken else {
            showAlert(message: "Session expired. Please try again.")
            return
        }

        DispatchQueue.main.async {
            self.enrollMfaButton?.isEnabled = false
            self.mfaActivityIndicator?.startAnimating()
        }

        print("📤 Enrolling phone via SDK: \(phoneNumber.prefix(4))****")

        Auth0
            .myAccount(token: accessToken)
            .authenticationMethods
            .enrollPhone(phoneNumber: phoneNumber, preferredAuthenticationMethod: .sms)
            .start { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let enrollmentChallenge):
                    //let challengeId = enrollmentChallenge.challenge.id
                    print("✅ SMS sent for enrollment.")
                    self.currentEnrollmentChallenge = enrollmentChallenge
                    self.showMfaOtpDialog()

                case .failure(let error):
                    print("❌ Enrollment error: \(error)")
                    DispatchQueue.main.async {
                        self.enrollMfaButton?.isEnabled = true
                        self.mfaActivityIndicator?.stopAnimating()
                        self.showAlert(message: "Enrollment failed: \(error.localizedDescription)")
                    }
                }
            }
    }

    private func showMfaOtpDialog() {
        DispatchQueue.main.async {
            self.mfaActivityIndicator?.stopAnimating()

            let alert = UIAlertController(
                title: "Verify Your Phone",
                message: "Enter the 6-digit code sent to your phone",
                preferredStyle: .alert
            )
            alert.addTextField { textField in
                textField.placeholder = "123456"
                textField.keyboardType = .numberPad
            }
            alert.addAction(UIAlertAction(title: "Verify", style: .default) { [weak self] _ in
                let otp = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !otp.isEmpty {
                    self?.verifyEnrollmentOtp(otp: otp)
                } else {
                    self?.showAlert(message: "Please enter the verification code.")
                    self?.showMfaOtpDialog()
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.enrollMfaButton?.isEnabled = true
            })
            alert.view.tintColor = .accent
            self.present(alert, animated: true)
        }
    }

    private func verifyEnrollmentOtp(otp: String) {
        guard let accessToken = currentMfaAccessToken,
              let challenge = currentEnrollmentChallenge else {
            showAlert(message: "Session expired. Please try again.")
            enrollMfaButton?.isEnabled = true
            return
        }

        DispatchQueue.main.async {
            self.mfaActivityIndicator?.startAnimating()
        }

        print("📤 Verifying enrollment OTP via SDK...")

        Auth0
            .myAccount(token: accessToken)
            .authenticationMethods
            .confirmPhoneEnrollment(id: challenge.authenticationId,
                                    authSession: challenge.authenticationSession,
                                    otpCode: otp)
            .start { [weak self] result in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.mfaActivityIndicator?.stopAnimating()
                    self.enrollMfaButton?.isEnabled = true
                }

                switch result {
                case .success(let authenticationMethod):
                    print("✅ MFA enrollment verified. Method ID: \(authenticationMethod.id)")
                    self.updateMfaUI(enrolled: true, methodId: authenticationMethod.id)
                    DispatchQueue.main.async {
                        self.showAlert(message: "SMS MFA enrolled successfully!")
                    }

                case .failure(let error):
                    print("❌ Verify error: \(error)")
                    DispatchQueue.main.async {
                        self.showAlert(message: "Invalid verification code. Please try again.")
                        self.showMfaOtpDialog()
                    }
                }
            }
    }

    private func confirmDeleteMfa() {
        let alert = UIAlertController(
            title: "Remove SMS MFA",
            message: "Are you sure you want to remove SMS verification from your account?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            // If biometrics enabled, require authentication first
            if self?.isBiometricEnabled == true {
                self?.authenticateWithBiometricsIfNeeded { success in
                    if success {
                        self?.deleteAuthenticationMethod()
                    } else {
                        self?.showAlert(message: "Biometric authentication required to remove MFA.")
                    }
                }
            } else {
                self?.deleteAuthenticationMethod()
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.view.tintColor = .accent
        present(alert, animated: true)
    }

    private func deleteAuthenticationMethod() {
        guard let accessToken = currentMfaAccessToken,
              let methodId = enrolledMfaMethodId else {
            showAlert(message: "Unable to delete MFA. Please try again.")
            return
        }

        DispatchQueue.main.async {
            self.deleteMfaButton?.isEnabled = false
            self.mfaActivityIndicator?.startAnimating()
        }

        print("📤 Deleting MFA method via SDK: \(methodId)")

        Auth0
            .myAccount(token: accessToken)
            .authenticationMethods
            .deleteAuthenticationMethod(by: methodId)
            .start { [weak self] result in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.mfaActivityIndicator?.stopAnimating()
                    self.deleteMfaButton?.isEnabled = true
                }

                switch result {
                case .success:
                    print("✅ MFA deleted successfully")
                    self.updateMfaUI(enrolled: false, methodId: nil)
                    DispatchQueue.main.async {
                        self.showAlert(message: "SMS MFA removed successfully.")
                    }

                case .failure(let error):
                    print("❌ Delete error: \(error)")
                    DispatchQueue.main.async {
                        self.showAlert(message: "Failed to remove MFA: \(error.localizedDescription)")
                    }
                }
            }
    }
}

