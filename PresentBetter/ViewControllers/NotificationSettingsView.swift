import Firebase
import SwiftUI
import UIKit
import UserNotifications

var alarmSet_NotificationHour = 0
var alarmSet_NotificationMinute = 0

class NotificationSettingsViewController: UIViewController {
    @IBOutlet var btnHome: UIButton!
    @IBOutlet var btnOnOffSwitch: UIButton!
    @IBOutlet var lblAlarmTime: UILabel!
    @IBOutlet var viewAlarm: UIView!
    
    var notificationOn = false
    var notificationHour = 9
    var notificationMinute = 30
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        if CheckNotificationPermission() == false {
            if RegisterNotification() == false {
                navigationController?.popViewController(animated: false)
            }
        }
        
        btnHome.layer.cornerRadius = 17.0
        btnOnOffSwitch.isSelected = false
        btnOnOffSwitch.setImage(UIImage(named: "SwitchOff"), for: .normal)
        btnOnOffSwitch.setImage(UIImage(named: "SwitchOn"), for: .selected)
        
        viewAlarm.isUserInteractionEnabled = true
        viewAlarm.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewAlarmClicked)))
        
        LoadingViewController.showView(self)
        getNotificationSettings() {
            self.presentedViewController?.dismiss(animated: true, completion: nil)
            self.btnOnOffSwitch.isSelected = self.notificationOn
            self.refreshAlarmDisplay()
        }
    }
    
    func getNotificationSettings(completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        guard let userid = Auth.auth().currentUser?.uid else {
            return
        }
        
        db.collection("settings").document(userid)
            .getDocument { (document, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    if let data = document?.data() {
                        self.notificationOn = data["notificationOn"] as? Bool ?? false
                        self.notificationHour = data["notificationHour"] as? Int ?? 9
                        self.notificationMinute = data["notificationMinute"] as? Int ?? 30
                    }
                }
                completion()
            }
    }
    
    func setNotificationSettings() {
        guard let userid = Auth.auth().currentUser?.uid else {
            return
        }
        let db = Firestore.firestore()
        
        db.collection("settings").document(userid).setData([
            "notificationOn": notificationOn,
            "notificationHour": notificationHour,
            "notificationMinute": notificationMinute
        ]) { err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                //print("Write settings successfully!")
            }
        }
    }
    
    @objc func alarmSet() {
        NotificationCenter.default.removeObserver(self)
        
        notificationHour = alarmSet_NotificationHour
        notificationMinute = alarmSet_NotificationMinute
        alarmSet_NotificationHour = 0
        alarmSet_NotificationMinute = 0
        
        RemoveAllNotifications()
        if notificationOn {
            if ScheduleNotificationForEveryday(hour: notificationHour, minute: notificationMinute) == false {
                print("Failed to set notification")
                notificationOn = false
            }
        }
        setNotificationSettings()
        refreshAlarmDisplay()
    }
    
    @objc func refreshAlarmDisplay() {
        lblAlarmTime.text = String(format: "%02d:%02d", notificationHour, notificationMinute)
    }
    
    @objc func viewAlarmClicked() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(alarmSet), name: Notification.localNotificationSet, object: nil)
        SetAlarmViewController.showView(self, hour: notificationHour, minute: notificationMinute)
    }
    
    @IBAction func btnOnOffSwitchClicked(_ sender: UIButton) {
        btnOnOffSwitch.isSelected.toggle()
        
        if btnOnOffSwitch.isSelected {
            if ScheduleNotificationForEveryday(hour: notificationHour, minute: notificationMinute) == false {
                print("Failed to set notification")
                RemoveAllNotifications()
                notificationOn = false
            } else {
                notificationOn = true
            }
        } else {
            RemoveAllNotifications()
            notificationOn = false
        }
        setNotificationSettings()
    }
    
    @IBAction func btnHomeClicked(_ sender: UIButton) {
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView().environmentObject(UserInfo()))
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromLeft, animations: nil, completion: nil)
        }
    }
}

extension NotificationSettingsViewController {
    func RegisterNotification() -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        var IsGranted = true
        UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
            if (!granted) {
                IsGranted = false
            }
        }
        return IsGranted
    }
    
    func CheckNotificationPermission() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var IsGranted = true
        UNUserNotificationCenter.current().getNotificationSettings() { (settings) in
            if settings.authorizationStatus != .authorized {
                IsGranted = false
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        return IsGranted
    }
    
    func ScheduleNotificationForEveryday(hour: Int, minute: Int) -> Bool {
        var success = true
        for i in 1...7 {
            success = ScheduleNotification(identifier: "\(i)_\(hour)_\(minute)", body: "It's time to practice presenting!", weekDay: i, hour: hour, minute: minute)
            if !success {
                return false
            }
        }
        return true
    }
    
    func ScheduleNotification(identifier: String, body: String, weekDay: Int, hour: Int, minute: Int) -> Bool {
        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.current
        dateComponents.weekday = weekDay
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        var HasError = false
        UNUserNotificationCenter.current().add(request) { (error) in
            if error != nil {
                HasError = true
                return
            }
        }
        
        return !HasError
    }
    
    func RemoveAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

class SetAlarmViewController: UIViewController {
    @IBOutlet var lblHour: UILabel!
    @IBOutlet var lblMinute: UILabel!
    @IBOutlet var backgroundView: UIView!
    @IBOutlet var btnOK: UIButton!
    
    var hour = 0
    var minute = 0
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        backgroundView.layer.cornerRadius = 10.0
        btnOK.layer.cornerRadius = 22.0
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        refreshAlarmDisplay()
    }
    
    func refreshAlarmDisplay() {
        lblHour.text = String(format: "%02d", hour)
        lblMinute.text = String(format: "%02d", minute)
    }
    
    func changeHour(increment: Int) {
        hour += increment
        hour = max(0, min(hour, 23))
        refreshAlarmDisplay()
    }
    
    func changeMinute(increment: Int) {
        minute += increment
        minute = max(0, min(minute, 59))
        refreshAlarmDisplay()
    }
    
    @IBAction func btnHourUpTouchDown(_ sender: Any) {
        changeHour(increment: 1)
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { _ in
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.changeHour(increment: 1)
            }
        }
    }
    @IBAction func btnHourUpTouchUp(_ sender: UIButton) {
        timer?.invalidate()
    }
    @IBAction func btnHourDownTouchDown(_ sender: UIButton) {
        changeHour(increment: -1)
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { _ in
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.changeHour(increment: -1)
            }
        }
    }
    @IBAction func btnHourDownTouchUp(_ sender: UIButton) {
        timer?.invalidate()
    }
    @IBAction func btnMinuteUpTouchDown(_ sender: Any) {
        changeMinute(increment: 1)
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { _ in
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.changeMinute(increment: 1)
            }
        }
    }
    @IBAction func btnMinuteUpTouchUp(_ sender: UIButton) {
        timer?.invalidate()
    }
    @IBAction func btnMinuteDownTouchDown(_ sender: UIButton) {
        changeMinute(increment: -1)
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { _ in
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.changeMinute(increment: -1)
            }
        }
    }
    @IBAction func btnMinuteDownTouchUp(_ sender: UIButton) {
        timer?.invalidate()
    }
    
    @IBAction func btnOKClicked(_ sender: UIButton) {
        alarmSet_NotificationMinute = minute
        alarmSet_NotificationHour = hour
        
        dismiss(animated: true, completion: nil)
        NotificationCenter.default.post(name: Notification.localNotificationSet, object: nil)
    }
}

extension SetAlarmViewController {
    static func showView(_ parentViewController: UIViewController, hour: Int, minute: Int) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let viewController = storyboard.instantiateViewController(identifier: "SetAlarmViewController") as? SetAlarmViewController {
            viewController.modalTransitionStyle = .crossDissolve
            viewController.modalPresentationStyle = .overFullScreen
            viewController.hour = hour
            viewController.minute = minute
        
            parentViewController.present(viewController, animated: true, completion: nil)
        }
    }
}
