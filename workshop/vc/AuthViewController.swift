//
//  AuthViewController.swift
//  workshop
//
//  Created by Juan Quintero on 11/17/25.
//

import UIKit
import Auth0
import LocalAuthentication

class AuthViewController: UIViewController {
    
    private var credentialsManager = CredentialsManager(authentication: Auth0.authentication())
    
    var onAuthSuccess: (() -> Void)?
    
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

    

    @IBOutlet weak var welcomeLabel: UILabel!
    
    @IBOutlet weak var signInBtnStackView: UIStackView!
    
    @IBOutlet weak var signInUntextField: UITextField!
    @IBOutlet weak var signInPwdtextField: UITextField!
    
    
    
    @IBAction func signInBtnTapped(_ sender: UIButton) {
        signInWithPassword()
    }
    
    @IBAction func forgotPwdBtnTapped(_ sender: UIButton) {
        forgotPassword()
    }
    
    
    @IBAction func noAccountBtnTapped(_ sender: UIButton) {
        signInBtnStackView.isHidden.toggle()
        signUpBtnStackView.isHidden.toggle()
        
        welcomeLabel.text = "New to Workshop? Please create an account below."
    }
    
    
    
    @IBOutlet weak var signUpBtnStackView: UIStackView!
   
    
    @IBAction func signUpBtnTapped(_ sender: UIButton) {
        signUp()
    }
    
    @IBAction func alreadyHaveAccountBtnTapped(_ sender: UIButton) {
        signInBtnStackView.isHidden.toggle()
        signUpBtnStackView.isHidden.toggle()
        
        welcomeLabel.text = "Welcome back. Please sign in below."

    }
    
//    @IBAction func dismissBtnTapped(_ sender: UIButton) {
//        
//        self.dismiss(animated: true)
//    }
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
//        signUpUntextField.layer.cornerRadius = 8
//        signUpUntextField.clipsToBounds = true
//        
//        signUpPwdtextField.layer.cornerRadius = 8
//        signUpPwdtextField.clipsToBounds = true
//
//        signInUntextField.layer.cornerRadius = 8
//        signInUntextField.clipsToBounds = true
//
//        signInPwdtextField.layer.cornerRadius = 8
//        signInPwdtextField.clipsToBounds = true

        
    }
    

   
    
    private func signInWithPassword() {
        guard let username = signInUntextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = signInPwdtextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty, !password.isEmpty else {
            print("Username and password required.")
            return
        }

        Auth0
            .authentication() // <-- Use the authentication API. https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#authentication-api-ios--macos--tvos--watchos--visionos
            //.useDPoP()
            .login(
                usernameOrEmail: username,
                password: password,
                realmOrConnection: "Username-Password-Authentication", // <-- the db you are authenticating the user against.
                audience: "https://\(domain)/api/v2/",
                scope: "openid profile email offline_access"
            )
            .start { result in
                switch result {
                case .success(let credentials):
                    print("✅ Login successful. Credentials: \(credentials)")
                    _ = self.credentialsManager.store(credentials: credentials)
                    
                    //We are all good here.
                    //self.onAuthSuccess?()
                    DispatchQueue.main.async {
                        self.dismiss(animated: true, completion: self.onAuthSuccess)
                    }

                case .failure(let error):
                    print("❌ Login failed: \(error)")

                    // Check for MFA enrollment required (user has no MFA set up)
                    if let authErr = error as? Auth0.AuthenticationError,
                       let code = authErr.info["error"] as? String,
                       code == "association_required",
                       let mfaToken = authErr.info["mfa_token"] as? String {

                        print("📱 MFA enrollment required. mfa_token: \(mfaToken)")
                        self.handleMfaEnrollment(mfaToken: mfaToken)
                        return
                    }

                    // MFA is required to continue (user already has MFA enrolled)
                    if let authErr = error as? Auth0.AuthenticationError,
                       let code = authErr.info["error"] as? String,
                       code == "mfa_required",
                       let mfaToken = authErr.info["mfa_token"] as? String {

                        print("🔐 MFA token: \(mfaToken)") // <-- MFA token needed in order to kickoff flow to identify and choose MFA factor and/or enroll.

                        self.fetchSMSAuthenticator(mfaToken: mfaToken) { authenticatorId in
                            guard let authenticatorId = authenticatorId else {
                                print("❌ No SMS authenticator found")
                                return
                            }

                            self.sendSMSChallenge(mfaToken: mfaToken, authenticatorId: authenticatorId) { oobCode in
                                guard let oobCode = oobCode else {
                                    print("❌ Failed to trigger SMS challenge")
                                    return
                                }

                                DispatchQueue.main.async {
                                    let alert = UIAlertController(
                                        title: "SMS Verification",
                                        message: "Enter the code sent to your phone",
                                        preferredStyle: .alert
                                    )
                                    alert.addTextField { $0.placeholder = "123456" }
                                    alert.addAction(UIAlertAction(title: "Verify", style: .default) { _ in
                                        let code = alert.textFields?.first?.text ?? ""
                                        self.verifySMSCode(mfaToken: mfaToken, oobCode: oobCode, userOTP: code)
                                    })
                                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                                        
                
                                    })
                                    self.present(alert, animated: true)
                                }
                            }
                        }
                    } else {
                        self.showAlert(message: error.localizedDescription)
                    }
                    
                }
            }
    }
    
    //Fetch authenticators, for the sake of simplicity we are looking for previously configured SMS. https://auth0.com/docs/secure/multi-factor-authentication/authenticate-using-ropg-flow-with-mfa
    
    private func fetchSMSAuthenticator(mfaToken: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://\(domain)/mfa/authenticators") else { // <-- REPLACE WITH YOIUR DOMAIN + /mfa/authenticators
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(mfaToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ Failed to fetch authenticators")
                completion(nil)
                return
            }

            for item in json {
                let type = item["authenticator_type"] as? String ?? "none"
                let channel = item["oob_channel"] as? String ?? "none"
                let id = item["id"] as? String ?? "unknown"

                print("→ ID: \(id), type: \(type), channel: \(channel)")

                if type == "oob", channel == "sms" {
                    print("✅ Using SMS authenticator: \(id)")
                    completion(id)
                    return
                }
            }

            print("❌ No SMS authenticator found.")
            completion(nil)
        }.resume()
    }

    //Send SMS challenge
    private func sendSMSChallenge(mfaToken: String, authenticatorId: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://\(domain)/mfa/challenge") else { // <-- REPLACE WITH YOIUR DOMAIN + /mfa/challenge
            print("❌ Invalid URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(mfaToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "client_id": clientId, // <-- replace with your app clientId
            "challenge_type": "oob",
            "authenticator_id": authenticatorId,
            "mfa_token": mfaToken
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("📤 Challenge request body: \(body)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Challenge request error: \(error)")
                completion(nil)
                return
            }
            if let httpRes = response as? HTTPURLResponse {
                print("🧮 HTTP Status Code: \(httpRes.statusCode)")
            }
            if let data = data,
               let raw = String(data: data, encoding: .utf8) {
                print("📨 Raw challenge response: \(raw)")
            }

            guard let data = data,
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oobCode = result["oob_code"] as? String else {
                print("❌ Could not extract oob_code from response.")
                completion(nil)
                return
            }

            print("✅ SMS challenge sent. oob_code: \(oobCode)")
            completion(oobCode)
        }.resume()
    }



    
    //Verify code
    private func verifySMSCode(mfaToken: String, oobCode: String, userOTP: String) {
        guard let url = URL(string: "https://\(domain)/oauth/token") else { // <-- REPLACE WITH YOIUR DOMAIN + /oauth/token
            print("❌ Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "grant_type": "http://auth0.com/oauth/grant-type/mfa-oob",
            "client_id": clientId, // <-- replace with your app clientId
            "mfa_token": mfaToken,
            "oob_code": oobCode,
            "binding_code": userOTP
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                print("❌ MFA verification failed: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            do {
                let credentials = try JSONDecoder().decode(Credentials.self, from: data)
                print("✅ MFA completed. Credentials: \(credentials)")
                
                // 🔐 Store in credentials manager
                let stored = self.credentialsManager.store(credentials: credentials)
                print("🔐 Credentials stored: \(stored)")
                
                // 👉 Navigate to main UI
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: self.onAuthSuccess)
                }

            } catch {
                print("❌ Failed to decode credentials: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) {
                    print("Raw response: \(json)")
                }
            }
        }.resume()
    }


    private func signUp(){
        
        guard let username = signInUntextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = signInPwdtextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty, !password.isEmpty else {
            print("Username and password required.")
            return
        }
        
        Auth0
            .authentication()
            .signup(email: username,
                    password: password,
                    connection: "Username-Password-Authentication")
                    //userMetadata: ["first_name": "John", "last_name": "Appleseed"]) // <-- Additional information about the user. https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md#sign-up-with-database-connection
            .start { result in
                switch result {
                case .success(let user):
                    print("User signed up: \(user)")
                    
                    DispatchQueue.main.async {
                        self.signInWithPassword()
                    }
                    
                   
                                        
                case .failure(let error):
                    print("Failed with: \(error)")
                    
                    self.showAlert(message: "Something went wrong. Please try again.")
                }
            }
    }
    
    private func forgotPassword(){
        
        
        guard let email = signInUntextField.text, !email.isEmpty else {
            // show error
            showAlert(message: "Please enter your email address into the username field and tap Forgot Password again.")
            return
            
        }
            Auth0
            .authentication()
            .resetPassword(email: email, connection: "Username-Password-Authentication")
            .start { [weak self] result in
                  DispatchQueue.main.async {
                    switch result {
                    case .success:
                        
                        self?.showAlert(message: "Check your inbox for next steps.")
                        
                    case .failure(let error):
                        // show error alert
                        print("Error: \(error)")
                    }
                  }
              }
        
    }
    
    private func showAlert(message: String) {

        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
            alert.view.tintColor = .accent
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }


    }

    // MARK: - MFA Enrollment (for users without MFA set up)

    private func handleMfaEnrollment(mfaToken: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Set Up SMS Verification",
                message: "Enter your phone number to receive verification codes (include country code, e.g. +1)",
                preferredStyle: .alert
            )
            alert.addTextField { textField in
                textField.placeholder = "+1 555 123 4567"
                textField.keyboardType = .phonePad
            }
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
                let phone = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !phone.isEmpty {
                    self.enrollPhoneNumber(mfaToken: mfaToken, phoneNumber: phone)
                } else {
                    self.showAlert(message: "Please enter a valid phone number.")
                    self.handleMfaEnrollment(mfaToken: mfaToken)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.showAlert(message: "MFA enrollment is required to sign in.")
            })
            alert.view.tintColor = .accent
            self.present(alert, animated: true)
        }
    }

    private func enrollPhoneNumber(mfaToken: String, phoneNumber: String) {
        guard let url = URL(string: "https://\(domain)/mfa/associate") else {
            print("❌ Invalid URL for /mfa/associate")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(mfaToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "authenticator_types": ["oob"],
            "oob_channels": ["sms"],
            "phone_number": phoneNumber
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("📤 Enrolling phone number: \(phoneNumber.prefix(4))****")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Enrollment request error: \(error)")
                DispatchQueue.main.async {
                    self.showAlert(message: "Enrollment failed: \(error.localizedDescription)")
                    self.handleMfaEnrollment(mfaToken: mfaToken)
                }
                return
            }

            if let httpRes = response as? HTTPURLResponse {
                print("🧮 /mfa/associate HTTP Status: \(httpRes.statusCode)")
            }

            if let data = data, let raw = String(data: data, encoding: .utf8) {
                print("📨 /mfa/associate response: \(raw)")
            }

            guard let data = data,
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oobCode = result["oob_code"] as? String else {
                print("❌ Could not extract oob_code from /mfa/associate response")
                DispatchQueue.main.async {
                    self.showAlert(message: "Enrollment failed. Please try again with a valid phone number.")
                    self.handleMfaEnrollment(mfaToken: mfaToken)
                }
                return
            }

            print("✅ SMS sent for enrollment. oob_code received.")
            self.showEnrollmentOtpDialog(mfaToken: mfaToken, oobCode: oobCode)
        }.resume()
    }

    private func showEnrollmentOtpDialog(mfaToken: String, oobCode: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Verify Your Phone",
                message: "Enter the 6-digit code sent to your phone",
                preferredStyle: .alert
            )
            alert.addTextField { textField in
                textField.placeholder = "123456"
                textField.keyboardType = .numberPad
            }
            alert.addAction(UIAlertAction(title: "Verify", style: .default) { _ in
                let otp = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !otp.isEmpty {
                    // Reuse existing verifySMSCode method
                    self.verifySMSCode(mfaToken: mfaToken, oobCode: oobCode, userOTP: otp)
                } else {
                    self.showAlert(message: "Please enter the verification code.")
                    self.showEnrollmentOtpDialog(mfaToken: mfaToken, oobCode: oobCode)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.showAlert(message: "MFA enrollment cancelled.")
            })
            alert.view.tintColor = .accent
            self.present(alert, animated: true)
        }
    }

}
