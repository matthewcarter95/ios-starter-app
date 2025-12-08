//
//  SettingViewController.swift
//  workshop
//
//  Created by Juan Quintero on 11/17/25.
//

import UIKit

class SettingViewController: UIViewController {
    
    private var isNativeFlowEnabled: Bool = false
    
    @IBOutlet weak var nativeFlowStackView: UIStackView!
    
    @IBOutlet weak var enableNativeFlowSwitch: UISwitch!
    
    
    @IBAction func enableNativeFlowSwitchTapped(_ sender: UISwitch) {
        
        setNativeFlowEnabled(sender.isOn)
        
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        nativeFlowStackView.layer.cornerRadius = 16
        nativeFlowStackView.clipsToBounds = true
        
        isNativeFlowEnabled = UserDefaults.standard.bool(forKey: "isNativeFlowEnabled")
        
        enableNativeFlowSwitch.isOn = isNativeFlowEnabled
        
    }
    
    private func setNativeFlowEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "isNativeFlowEnabled")
 
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
