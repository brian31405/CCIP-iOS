//
//  CheckinViewController.swift
//  OPass
//
//  Created by 腹黒い茶 on 2019/6/16.
//  Copyright © 2019 OPass. All rights reserved.
//

import Foundation
import UIKit
import AudioToolbox
import MBProgressHUD
import iCarousel
import ScanditBarcodeScanner

@objc enum HideCheckinViewOverlay: Int {
    case Guide
    case Status
    case InvalidNetwork
}

@objc class CheckinViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate , InvalidNetworkRetryDelegate, iCarouselDataSource, iCarouselDelegate, SBSScanDelegate, SBSProcessFrameDelegate {
    @objc public var controllerTopStart: CGFloat = 0

    @IBOutlet private var cards: iCarousel?
    @IBOutlet private var ivRectangle: UIImageView?
    @IBOutlet private var ivUserPhoto: UIImageView?
    @IBOutlet private var lbHi: UILabel?
    @IBOutlet private var lbUserName: UILabel?

    private var pageControl: UIPageControl = UIPageControl.init()

    private var _userInfo = Dictionary<String, NSObject>()
    private var userInfo: Dictionary<String, NSObject> {
        get {
            return self._userInfo
        }
        set {
            self._userInfo = newValue
            AppDelegate.delegateInstance().userInfo = newValue
        }
    }
    private var scenarios = Array<Dictionary<String, NSObject>>()

    private var scanditBarcodePicker: SBSBarcodePicker?
    private var qrButtonItem: UIBarButtonItem?

    private var guideViewController: GuideViewController?
    private var statusViewController: StatusViewController?
    private var invalidNetworkMsgViewController: InvalidNetworkMessageViewController?

    private var progress: MBProgressHUD?

    // MARK: - View Events

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.setBackgroundImage(UIImage.init(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage.init()
        self.navigationController?.navigationBar.backgroundColor = .clear

        AppDelegate.delegateInstance().checkinView = self

        // Init configure pageControl
        self.pageControl.numberOfPages = 0
        // Init configure carousel
        self.cards?.addSubview(self.pageControl)
        self.cards?.type = .rotary
        self.cards?.isPagingEnabled = true
        self.cards?.bounceDistance = 0.3
        self.cards?.contentOffset = CGSize(width: 0, height: -5)

        Constants.SendFib("CheckinViewController")

        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(navSingleTap))

        let isHidden = !AppDelegate.haveAccessToken()

        self.lbUserName?.text = " "
        self.lbUserName?.isUserInteractionEnabled = true
        self.lbUserName?.addGestureRecognizer(tapGesture)
        self.lbUserName?.isHidden = isHidden

        self.lbHi?.isHidden = isHidden

        self.ivUserPhoto?.image = Constants.AssertImage(name: "StaffIconDefault", InBundleName: "PassAssets")
        self.ivUserPhoto?.isHidden = isHidden
        self.ivUserPhoto?.layer.cornerRadius = (self.ivUserPhoto?.frame.size.height ?? 0) / 2
        self.ivUserPhoto?.layer.masksToBounds = true

        self.ivRectangle?.setGradientColor(from: AppDelegate.appConfigColor("CheckinRectangleLeftColor"), to: AppDelegate.appConfigColor("CheckinRectangleRightColor"), startPoint: CGPoint(x: -0.4, y: 0.5), toPoint: CGPoint(x: 1, y: 0.5))

        NotificationCenter.default.addObserver(self, selector: #selector(appplicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        let beacon = AppDelegate.delegateInstance().beacon as! iBeacon
        beacon.checkAvailableAndRequestAuthorization()
        beacon.registerBeaconRegionWithUUID(uuidString: Constants.beaconUUID, identifier: Constants.beaconID, isMonitor: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.controllerTopStart = self.navigationController?.navigationBar.frame.size.height ?? 0
        self.handleQRButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.reloadCard()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.hideView(.Guide, nil)
        self.hideView(.Status, nil)
        self.hideView(.InvalidNetwork, nil)
        self.closeBarcodePickerOverlay()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.scenarios = []
        AppDelegate.delegateInstance().setScenarios(self.scenarios as [Any])
        self.cards?.reloadData()
        self.lbUserName?.text = ""
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func appplicationDidBecomeActive(_ notification: NSNotification) {
        self.reloadCard()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destination = segue.destination
        switch destination.className {
        case GuideViewController.className:
            self.guideViewController = destination as? GuideViewController
        case StatusViewController.className:
            self.statusViewController = destination as? StatusViewController
            self.statusViewController?.scenario = sender as? [AnyHashable : Any]
        case InvalidNetworkMessageViewController.className:
            let inmvc = destination as! InvalidNetworkMessageViewController
            inmvc.message = sender as! String
            inmvc.delegate = self
        default:
            break
        }
    }

    func refresh() {
        self.reloadCard()
    }

    // MARK: - Dev Mode

    @objc func navSingleTap() {
        struct tap {
            static var tapTimes: Int = 0
            static var oldTapTime: Date?
            static var newTapTime: Date?
        }
        //        NSLog("navSingleTap")

        tap.newTapTime = Date.init()
        if tap.oldTapTime == nil {
            tap.oldTapTime = tap.newTapTime
        }

        if AppDelegate.isDevMode() {
            //            NSLog("navSingleTap from MoreTab")
            if (tap.newTapTime?.timeIntervalSince(tap.oldTapTime!))! <= TimeInterval(0.25) {
                tap.tapTimes += 1
                if tap.tapTimes >= 10 {
                    NSLog("--  Success tap 10 times  --")
                    if AppDelegate.haveAccessToken() {
                        NSLog("-- Clearing the Token --")
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                        AppDelegate.setAccessToken("")
                        (AppDelegate.delegateInstance().checkinView as! CheckinViewController).reloadCard()
                    } else {
                        NSLog("-- Token is already clear --")
                    }
                    tap.tapTimes = 1
                }
            } else {
                NSLog("--  Failed, just tap \(tap.tapTimes) times  --")
                NSLog("-- Not trigger clean token --")
                tap.tapTimes = 1
            }
            tap.oldTapTime = tap.newTapTime
        }
    }

    // MARK: - hide custom view controller method

    func hideView(_ viewType: HideCheckinViewOverlay, _ completion: (() -> Void)?) {

        let isVisible = [
            HideCheckinViewOverlay.Guide: self.guideViewController?.isVisible,
            HideCheckinViewOverlay.Status: self.statusViewController?.isVisible,
            HideCheckinViewOverlay.InvalidNetwork: self.invalidNetworkMsgViewController?.isVisible
        ][viewType]! ?? false

        let _completion = {
            if completion != nil {
                completion!()
            }
        }

        if isVisible {
            [
                HideCheckinViewOverlay.Guide: {
                    self.guideViewController?.dismiss(animated: true, completion: {
                        self.guideViewController = nil
                        _completion()
                    })
                },
                HideCheckinViewOverlay.Status: {
                    self.statusViewController?.dismiss(animated: true, completion: {
                        self.statusViewController = nil
                        _completion()
                    })
                },
                HideCheckinViewOverlay.InvalidNetwork: {
                    self.invalidNetworkMsgViewController?.dismiss(animated: true, completion: {
                        self.invalidNetworkMsgViewController = nil
                        _completion()
                    })
                }
            ][viewType]!()
        } else {
            _completion()
        }
    }

    // MARK: - cards methods

    func goToCard() {
        if AppDelegate.haveAccessToken() {
            let checkinCard = UserDefaults.standard.object(forKey: "CheckinCard") as? NSDictionary
            if checkinCard != nil {
                let key = checkinCard?.object(forKey: "key") as! String
                for item in self.scenarios {
                    let id = item["id"] as! String
                    if id == key {
                        let index = self.scenarios.firstIndex(of: item)!
                        NSLog("index: \(index)")
                        self.cards?.scrollToItem(at: index, animated: true)
                    }
                }
                UserDefaults.standard.removeObject(forKey: "CheckinCard")
            } else {
                // force scroll to first selected item at first load
                if self.cards!.numberOfItems > 0 {
                    let scenarios = AppDelegate.delegateInstance().availableScenarios as! Array<NSDictionary>
                    for scenario in scenarios {
                        let used = scenario.object(forKey: "used") != nil
                        let disabled = scenario.object(forKey: "disabled") != nil
                        if !used && !disabled {
                            self.cards?.scrollToItem(at: scenarios.firstIndex(of: scenario)!, animated: true)
                            break
                        }
                    }
                }
            }
            UserDefaults.standard.synchronize()
        }
        self.progress?.hide(animated: true)
    }

    func reloadAndGoToCard() {
        self.cards?.reloadData()
        self.goToCard()
    }

    @objc func reloadCard() {
        if self.progress != nil {
            self.progress?.hide(animated: true)
        }
        self.progress = MBProgressHUD.showAdded(to: self.view, animated: true)
        self.progress?.mode = .indeterminate
        self.handleQRButton()

        let isHidden = !AppDelegate.haveAccessToken()
        self.lbHi?.isHidden = isHidden
        self.ivUserPhoto?.isHidden = isHidden
        self.lbUserName?.isHidden = isHidden
        self.lbUserName?.text = " "

        if !AppDelegate.haveAccessToken() {
            if self.scanditBarcodePicker == nil {
                if !(self.presentedViewController?.isKind(of: GuideViewController.self) ?? false) {
                    self.performSegue(withIdentifier: "ShowGuide", sender: self.cards)
                }
                self.userInfo.removeAll()
                self.scenarios.removeAll()
                AppDelegate.sendTag("user_id", value: "")
                AppDelegate.delegateInstance().setScenarios(self.scenarios as [Any])
                self.reloadAndGoToCard()
            }
        } else {
            OPassAPI.GetCurrentStatus { success, obj, error in
                if success {
                    self.hideView(.Guide, nil)
                    let userInfo = NSMutableDictionary.init(dictionary: obj as! NSDictionary)
                    userInfo.removeObject(forKey: "scenarios")
                    self.userInfo = userInfo as! [String : NSObject]
                    self.scenarios = (obj as! NSDictionary).object(forKey: "scenarios") as! [Dictionary<String, NSObject>]

                    let isHidden = !AppDelegate.haveAccessToken()
                    self.lbHi?.isHidden = isHidden
                    self.ivUserPhoto?.isHidden = isHidden
                    self.lbUserName?.isHidden = isHidden
                    self.lbUserName?.text = self.userInfo["user_id"] as? String
                    let userTags = NSMutableDictionary.init(dictionary: self.userInfo as [AnyHashable : Any])
                    userTags.removeObjects(forKeys: [
                        "_id",
                        "first_use",
                        "attr" // wait for cleanup
                    ])
                    AppDelegate.sendTags(userTags as! [AnyHashable : Any])
                    if AppDelegate.delegateInstance().isLoginSession {
                        AppDelegate.delegateInstance().displayGreetingsForLogin()
                    }
                    AppDelegate.delegateInstance().setScenarios(self.scenarios)
                    self.reloadAndGoToCard()
                } else {
                    func broken(_ msg: String = "Networking_Broken") {
                        self.performSegue(withIdentifier: "ShowInvalidNetworkMsg", sender: NSLocalizedString(msg, comment: ""))
                    }
                    guard let sr = obj as? OPassNonSuccessDataResponse else {
                        broken()
                        return
                    }
                    switch (sr.Response?.statusCode) {
                    case 400:
                        guard let responseObject = sr.Obj as? NSDictionary else { return }
                        let msg = responseObject.object(forKey: "message") as! String
                        if msg == "invalid token" {
                            NSLog("\(msg)")

                            AppDelegate.setAccessToken("")

                            let ac = UIAlertController.alertOfTitle(NSLocalizedString("InvalidTokenAlert", comment: ""), withMessage: NSLocalizedString("InvalidTokenDesc", comment: ""), cancelButtonText: NSLocalizedString("GotIt", comment: ""), cancelStyle: .cancel) { action in
                                self.reloadCard()
                            }
                            ac.showAlert {
                                UIImpactFeedback.triggerFeedback(.notificationFeedbackError)
                            }
                        }
                    case 403:
                        broken("Networking_WrongWiFi")
                    default:
                        broken()
                    }
                }
            }
        }
    }

    // MARK: - display messages

    @objc func showCountdown(_ json: NSDictionary) {
        NSLog("Show Countdown: \(json)")
        self.performSegue(withIdentifier: "ShowCountdown", sender: json)
    }

    @objc func showInvalidNetworkMsg(_ msg: String? = nil) {
        self.performSegue(withIdentifier: "ShowInvalidNetworkMsg", sender: msg)
    }

    // MARK: - QR Code Scanner

    func handleQRButton() {
        if self.qrButtonItem == nil {
            self.qrButtonItem = UIBarButtonItem.init(image: Constants.AssertImage(name: "QR_Code", InBundleName: "AssetsUI"), landscapeImagePhone: nil, style: .plain, target: self, action: #selector(callBarcodePickerOverlay))
        }
        self.navigationItem.rightBarButtonItem = nil
        if AppDelegate.isDevMode() || !AppDelegate.haveAccessToken() {
            self.navigationItem.rightBarButtonItem = self.qrButtonItem
        }
    }

    func hideQRButton() {
        if !AppDelegate.isDevMode() {
            self.navigationItem.rightBarButtonItem = nil
        }
    }

    public func barcodePicker(_ barcodePicker: SBSBarcodePicker, didProcessFrame frame: CMSampleBuffer, session: SBSScanSession) {
        //
    }

    //! [SBSBarcodePicker overlayed as a view]

    /**
     * A simple example of how the barcode picker can be used in a simple view of various dimensions
     * and how it can be added to any o ther view. This example scales the view instead of cropping it.
     */
    public func barcodePicker(_ picker: SBSBarcodePicker, didScan session: SBSScanSession) {
        session.pauseScanning()

        let recognized = session.newlyRecognizedCodes
        let code = recognized.first!
        // Add your own code to handle the barcode result e.g.
        NSLog("scanned \(code.symbologyName) barcode: \(String(describing: code.data))")

        OperationQueue.main.addOperation {
            OPassAPI.RedeemCode(forEvent: "", withToken: code.data!) { (success, obj, error) in
                if success {
                    self.perform(#selector(self.reloadCard), with: nil, afterDelay: 0.5)
                    self.perform(#selector(self.closeBarcodePickerOverlay), with: nil, afterDelay: 0.5)
                } else {
                    let ac = UIAlertController.alertOfTitle(NSLocalizedString("GuideViewTokenErrorTitle", comment: ""), withMessage: NSLocalizedString("GuideViewTokenErrorDesc", comment: ""), cancelButtonText: NSLocalizedString("GotIt", comment: ""), cancelStyle: .cancel) { action in
                        self.scanditBarcodePicker?.resumeScanning()
                    }
                    ac.showAlert {
                        UIImpactFeedback.triggerFeedback(.notificationFeedbackError)
                    }
                }
            }
        }
    }

    @objc func closeBarcodePickerOverlay() {
        if self.scanditBarcodePicker != nil {
            self.qrButtonItem?.image = Constants.AssertImage(name: "QR_Code", InBundleName: "AssetsUI")
            self.scanditBarcodePicker?.removeFromParent()
            self.scanditBarcodePicker?.view.removeFromSuperview()
            self.scanditBarcodePicker?.didMove(toParent: nil)
            self.scanditBarcodePicker = nil
            let isHidden = !AppDelegate.haveAccessToken()
            self.lbHi?.isHidden = isHidden
            self.lbUserName?.isHidden = isHidden
            self.ivUserPhoto?.isHidden = isHidden
        }
    }

    @objc func callBarcodePickerOverlay() {
        self.hideView(.Guide) {
            self.showBarcodePickerOverlay()
        }
    }

    func showBarcodePickerOverlay() {
        if self.scanditBarcodePicker != nil {
            self.closeBarcodePickerOverlay()

            if !AppDelegate.haveAccessToken() {
                self.performSegue(withIdentifier: "ShowGuide", sender: nil)
            } else {
                self.hideQRButton()
            }
        } else {
            self.lbHi?.isHidden = true
            self.ivUserPhoto?.isHidden = true
            self.qrButtonItem?.image = Constants.AssertImage(name: "QR_Code_Filled", InBundleName: "AssetsUI")
            // Configure the barcode picker through a scan settings instance by defining which
            // symbologies should be enabled.
            let scanSettings = SBSScanSettings.default()
            // prefer backward facing camera over front-facing cameras.
            scanSettings.cameraFacingPreference = .back
            // Enable symbologies that you want to scan
            scanSettings.setSymbology(.qr, enabled: true)

            self.scanditBarcodePicker = SBSBarcodePicker.init(settings: scanSettings)
            /* Set the delegate to receive callbacks.
             * This is commented out here in the demo app since the result view with the scan results
             * is not suitable for this overlay view */
            self.scanditBarcodePicker?.scanDelegate = self
            self.scanditBarcodePicker?.processFrameDelegate = self

            // Add a button behind the subview to close it.
            // self.backgroundButton.hidden = NO;

            self.addChild(self.scanditBarcodePicker!)
            self.view.addSubview(self.scanditBarcodePicker!.view)
            self.scanditBarcodePicker?.didMove(toParent: self)

            self.scanditBarcodePicker?.view.translatesAutoresizingMaskIntoConstraints = false

            // Add constraints to scale the view and place it in the center of the controller.
            self.view.addConstraint(NSLayoutConstraint.init(item: self.scanditBarcodePicker?.view as Any, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
            self.view.addConstraint(NSLayoutConstraint.init(item: self.scanditBarcodePicker?.view as Any, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1, constant: self.ViewTopStart))
            // Add constraints to set the width to 200 and height to 400. Since this is not the aspect ratio
            // of the camera preview some of the camera preview will be cut away on the left and right.
            self.view.addConstraint(NSLayoutConstraint.init(item: self.scanditBarcodePicker?.view as Any, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1, constant: 0))
            self.view.addConstraint(NSLayoutConstraint.init(item: self.scanditBarcodePicker?.view as Any, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1, constant: 0))

            let barcodePickerOverlay = self.scanditBarcodePicker?.view.subviews.first!
            let torchButton = barcodePickerOverlay?.subviews[2]
            let button = UIButton.init(type: .roundedRect)
            button.layer.masksToBounds = false
            button.layer.cornerRadius = 20
            button.frame = CGRect(x: 65, y: (self.navigationController?.navigationBar.frame.size.height)!, width: 60, height: 40)
            button.backgroundColor = UIColor.white.withAlphaComponent(0.35)
            button.setTitle(NSLocalizedString("OpenQRCodeFromFile", comment: ""), for: .normal)
            button.tintColor = .black
            button.addTarget(self, action: #selector(getImageFromLibrary), for: .touchUpInside)
            barcodePickerOverlay?.addSubview(button)
            barcodePickerOverlay?.addConstraint(NSLayoutConstraint.init(item: button, attribute: .top, relatedBy: .equal, toItem: torchButton, attribute: .top, multiplier: 1, constant: 0))
            barcodePickerOverlay?.addConstraint(NSLayoutConstraint.init(item: button, attribute: .leading, relatedBy: .equal, toItem: torchButton, attribute: .trailing, multiplier: 1, constant: 5))

            self.scanditBarcodePicker?.startScanning(inPausedState: true, completionHandler: {
                self.scanditBarcodePicker?.perform(#selector(SBSBarcodePicker.startScanning as (SBSBarcodePicker) -> () -> Void), with: nil, afterDelay: 0.5)
            })
        }
    }

    // MARK: - QR Code from Camera Roll Library

    @objc func getImageFromLibrary() {
        let imagePicker = UIImagePickerController.init()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        self.present(imagePicker, animated: true, completion: nil)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let mediaType = info[.mediaType] as! String

        if mediaType == "public.image" {
            let srcImage = info[.originalImage] as! CIImage
            let detector = CIDetector.init(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!

            let image = CIImage.init(cgImage: srcImage.cgImage!)
            let features = detector.features(in: image) as! [CIQRCodeFeature]
            for feature in features {
                NSLog("feature: \(String(describing: feature.messageString))")
            }
            let feature = features.first!
            let result = feature.messageString
            NSLog("QR: \(String(describing: result))")

            var ac: UIAlertController? = nil
            if result != nil {
                OPassAPI.RedeemCode(forEvent: "", withToken: result!) { (success, obj, error) in
                    if success {
                        picker.dismiss(animated: true) {
                            // self.reloadCard()
                        }
                    } else {
                        ac = UIAlertController.alertOfTitle(NSLocalizedString("GuideViewTokenErrorTitle", comment: ""), withMessage: NSLocalizedString("GuideViewTokenErrorDesc", comment: ""), cancelButtonText: NSLocalizedString("GotIt", comment: ""), cancelStyle: .cancel, cancelAction: nil)
                        ac?.showAlert {
                            UIImpactFeedback.triggerFeedback(.notificationFeedbackError)
                        }
                    }
                }
            } else {
                ac = UIAlertController.alertOfTitle(NSLocalizedString("QRFileNotAvailableTitle", comment: ""), withMessage: NSLocalizedString("QRFileNotAvailableDesc", comment: ""), cancelButtonText: NSLocalizedString("GotIt", comment: ""), cancelStyle: .cancel, cancelAction: nil)
                ac?.showAlert {
                    UIImpactFeedback.triggerFeedback(.notificationFeedbackError)
                }
            }
        }
    }

    // MARK: - iCarousel methods

    func carouselCurrentItemIndexDidChange(_ carousel: iCarousel) {
        guard let availableScenarios = AppDelegate.delegateInstance().availableScenarios else { return }
        if availableScenarios.count > 0 {
            self.pageControl.currentPage = carousel.currentItemIndex
        }
    }

    func numberOfItems(in carousel: iCarousel) -> Int {
        guard let availableScenarios = AppDelegate.delegateInstance().availableScenarios else { return 0 }
        let count = availableScenarios.count
        self.pageControl.numberOfPages = count
        return count
    }

    func carousel(_ carousel: iCarousel, viewForItemAt index: Int, reusing view: UIView?) -> UIView {
        struct card {
            static var cardRect = CGRect()
        }
        var view = view
        // Init configure pageControl
        self.pageControl.isHidden = true  // set page control to hidden
        if card.cardRect.isEmpty {
            let pageControlFrame = self.pageControl.frame
            self.pageControl.frame = CGRect(x: self.view.frame.size.width / 2, y: ((self.cards?.frame.size.height ?? 0) + (self.cards?.frame.size.height ?? 0) - (self.pageControl.isHidden ? 0 : 10)) / 2, width: pageControlFrame.size.width, height: pageControlFrame.size.height)
            // Init cardRect
            // x 0, y 0, left 30, up 40, right 30, bottom 50
            // self.cards.contentOffset = CGSizeMake(0, -5.0f); // set in viewDidLoad
            // 414 736
            card.cardRect = CGRect(x: 0, y: 0, width: (self.cards?.bounds.size.width ?? 0), height: (self.cards?.frame.size.height ?? 0) - (self.pageControl.isHidden ? 0 : 10))
        }

        // create new view if no view is available for recycling
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        guard let availableScenarios = AppDelegate.delegateInstance().availableScenarios else { return view! }
        let haveScenario = availableScenarios.count > 0
        if haveScenario {
            let temp = storyboard.instantiateViewController(withIdentifier: "CheckinCardReuseView") as! CheckinCardViewController
            temp.view.frame = card.cardRect
            view = temp.view

            let scenario = availableScenarios[index] as! Dictionary<String, NSObject>

            let id = scenario["id"] as! String
            let isCheckin = id.contains("checkin")
            let isLunch = id.contains("lunch")
            let isKit = id.lowercased().contains("kit")
            let isVipKit = id.lowercased().contains("vipkit")
            let isShirt = id.lowercased().contains("shirt")
            let isRadio = id.contains("radio")
            let isDisabled = (scenario["disabled"] as? String ?? "").count > 0
            let isUsed = (scenario["used"] as? Int) != nil
            temp.setId(id)

            let dateRange = AppDelegate.parseRange(scenario as [AnyHashable : Any])
            let availableRange = "\(dateRange!.first!)\n\(dateRange!.last!)"
            let dd = AppDelegate.parseScenarioType(id)
            let did = dd!["did"]
            let scenarioType = dd!["scenarioType"]
            let displayText = scenario["display_text"] as! Dictionary<String, String>
            let lang = AppDelegate.longLangUI()!
            let defaultIcon = Constants.AssertImage(name: "doc", InBundleName: "PassAssets")!
            let scenarioIcon = Constants.AssertImage(name: scenarioType as! String, InBundleName: "PassAssets") ?? defaultIcon
            temp.checkinTitle.textColor = AppDelegate.appConfigColor("CardTextColor")
            temp.checkinTitle.text = displayText[lang]
            temp.checkinDate.textColor = AppDelegate.appConfigColor("CardTextColor")
            temp.checkinDate.text = availableRange
            temp.checkinText.textColor = AppDelegate.appConfigColor("CardTextColor")
            temp.checkinText.text = NSLocalizedString("CheckinNotice", comment: "")
            temp.checkinIcon.image = scenarioIcon

            if isCheckin {
                temp.checkinIcon.image = Constants.AssertImage(name: "day\(did!)", InBundleName: "PassAssets")
                temp.checkinText.text = NSLocalizedString("CheckinText", comment: "")
            }
            if isLunch {
                // nothing to do
            }
            if isKit {
                // nothing to do
            }
            if isVipKit {
                temp.checkinText.text = NSLocalizedString("CheckinTextVipKit", comment: "")
            }
            if isShirt {
                temp.checkinText.text = NSLocalizedString("CheckinStaffShirtNotice", comment: "")
            }
            if isRadio {
                temp.checkinText.text = NSLocalizedString("CheckinStaffRadioNotice", comment: "")
            }
            if isDisabled {
                temp.disabled = scenario["disabled"] as! String
                temp.checkinBtn.setTitle(scenario["disabled"] as? String, for: .normal)
                temp.checkinBtn.setGradientColor(from: AppDelegate.appConfigColor("DisabledButtonLeftColor"), to: AppDelegate.appConfigColor("DisabledButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
            } else if isUsed {
                temp.used = scenario["used"] as! Int
                if isCheckin {
                    temp.checkinBtn.setTitle(NSLocalizedString("CheckinViewButtonPressed", comment: ""), for: .normal)
                } else {
                    temp.checkinBtn.setTitle(NSLocalizedString("UseButtonPressed", comment: ""), for: .normal)
                }
                temp.checkinBtn.setGradientColor(from: AppDelegate.appConfigColor("UsedButtonLeftColor"), to: AppDelegate.appConfigColor("UsedButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
            } else {
                temp.used = 0
                if isCheckin {
                    temp.checkinBtn.setTitle(NSLocalizedString("CheckinViewButton", comment: ""), for: .normal)
                } else {
                    temp.checkinBtn.setTitle(NSLocalizedString("UseButton", comment: ""), for: .normal)
                }
                temp.checkinBtn.setGradientColor(from: AppDelegate.appConfigColor("CheckinButtonLeftColor"), to: AppDelegate.appConfigColor("CheckinButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
            }
            temp.checkinBtn.tintColor = .white

            temp.delegate = self
            temp.setScenario(scenario)
        }

        return view!
    }

    func carousel(_ carousel: iCarousel, valueFor option: iCarouselOption, withDefault value: CGFloat) -> CGFloat {
        switch (option) {
        case .wrap:
            //normally you would hard-code this to YES or NO
            return 0
        case .spacing:
            //add a bit of spacing between the item views
            return value * 0.9
        case .fadeMax:
            return 0
        case .fadeMin:
            return 0
        case .fadeMinAlpha:
            return 0.65
        case .arc:
            return value * (CGFloat(carousel.numberOfItems) / 48)
        case .radius:
            return value
        case .showBackfaces, .angle, .tilt, .count, .fadeRange, .offsetMultiplier, .visibleItems:
            return value
        default:
            return value
        }
    }
}
