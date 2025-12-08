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
    
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication()) // <-- handles and store credentials. https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#credentials-manager-ios--macos--tvos--watchos--visionos
    private let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
    
    private var isBiometricEnabled: Bool = false
    private var isNativeFlowEnabled: Bool = false
    
    
    
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
            //.useEphemeralSession() // <-- Use an ephemeral session. Hide the 3rd party SSO popup. 
            //.provider(WebAuthentication.webViewProvider()) // <-- https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#use-wkwebview-instead-of-aswebauthenticationsession
            //.useDPoP() // <-- https://auth0.com/docs/secure/sender-constraining/configure-sender-constraining
            //.parameters(["screen_hint": "signup"]) <-- Direct the user to a specifc screen within UL. https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#web-auth-signup
            .parameters(["prompt": "login"])
            .logging(enabled: true)
            .audience("https://mobile-workshop-jq.cic-demo-platform.auth0app.com/api/v2/")
            .scope("openid profile email offline_access")
            .start { result in
                switch result {
                case .success(let credentials):
                    print("Obtained credentials: \(credentials)")
                    
                    _ = self.credentialsManager.store(credentials: credentials)
                    
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
}
