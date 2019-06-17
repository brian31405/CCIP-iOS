//
//  CheckinCardView.swift
//  OPass
//
//  Created by 腹黒い茶 on 2019/6/17.
//  Copyright © 2019 OPass. All rights reserved.
//

import Foundation
import UIKit

class CheckinCardView: UIView {
    @IBOutlet public var checkinSmallCard: UIView?
    @IBOutlet public var checkinDate: UILabel?
    @IBOutlet public var checkinTitle: UILabel?
    @IBOutlet public var checkinText: UILabel?
    @IBOutlet public var checkinBtn: UIButton?
    @IBOutlet public var checkinIcon: UIImageView?

    public var delegate: CheckinViewController?
    public var scenario = Dictionary<String, NSObject>()
    public var id: String = ""
    public var used: Int = 0
    public var disabled: String = ""

    override class func awakeFromNib() {
        super.awakeFromNib()
    }

    override func layoutSubviews() {
        self.checkinBtn?.sizeGradientToFit()
    }

    func showCountdown() {
        let date = Date.init(timeIntervalSince1970: TimeInterval(self.scenario["used"] as! Int))
        let stopDate = date.addingTimeInterval(TimeInterval(self.scenario["countdown"] as! Int))
        let now = Date.init()
        NSLog("\(date) ~ \(stopDate) == \(now)")
        // always display countdown for t-shirt view
        // if ([now timeIntervalSince1970] - [stopDate timeIntervalSince1970] < 0) {
        self.delegate?.showCountdown(self.scenario as NSDictionary)
        // }
    }

    func updateScenario(_ scenarios: Array<Dictionary<String, NSObject>>) -> Dictionary<String, NSObject> {
        for scenario in scenarios {
            let id = scenario["id"] as! String
            if id == self.id {
                self.scenario = scenario
                break
            }
        }
        return self.scenario
    }

    func buttonUpdate(_ intermediate: (() -> ())?, _ completeion: (() -> ())?, _ cleanup: (() -> ())?) {
        UIView.animate(withDuration: 0.75, animations: {
            intermediate?()
        }) { finished in
            if finished {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (DispatchTimeInterval.milliseconds(Int(750)))) {
                    UIView.animate(withDuration: 0.75, animations: {
                        completeion?()
                    }) { finished in
                        if finished {
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (DispatchTimeInterval.milliseconds(Int(750)))) {
                                UIView.animate(withDuration: 0.75) {
                                    cleanup?()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @IBAction func checkinBtnTouched(_ sender: Any) {
        var ac: UIAlertController? = nil
        var feedbackType: UIImpactFeedbackType? = UIImpactFeedbackType(rawValue: 0)
        let availableTime = Date.init(timeIntervalSince1970: TimeInterval(self.scenario["available_time"] as! Int))
        let expireTime = Date.init(timeIntervalSince1970: TimeInterval(self.scenario["expire_time"] as! Int))
        let nowTime = Date.init()
        let isCheckin = (AppDelegate.parseScenarioType(self.id)["scenarioType"] as! String) == "checkin"

        let use = {
            OPassAPI.UseScenario(OPassAPI.currentEvent, AppDelegate.accessToken(), self.id) { (success, obj, error) in
                DispatchQueue.main.async {
                    if success {
//                        [self updateScenario:[responseObject objectForKey:@"scenarios"]];
//                        [self showCountdown];
//                        [self.checkinBtn setGradientColorFrom:[AppDelegate AppConfigColor:@"DisabledButtonLeftColor"]
//                            to:[AppDelegate AppConfigColor:@"DisabledButtonRightColor"]
//                            startPoint:CGPointMake(.2, .8)
//                            toPoint:CGPointMake(1, .5)];
//                        if (isCheckin) {
//                            [self.checkinBtn setTitle:NSLocalizedString(@"CheckinViewButtonPressed", nil) forState:UIControlStateNormal];
//                            [[AppDelegate delegateInstance].checkinView reloadCard];
//                        } else {
//                            [self.checkinBtn setTitle:NSLocalizedString(@"UseButtonPressed", nil) forState:UIControlStateNormal];
//                        }
//                        [[AppDelegate delegateInstance] setDefaultShortcutItems];
                    } else {
                        func broken(_ msg: String = "Networking_Broken") {
                            self.delegate?.showInvalidNetworkMsg(NSLocalizedString(msg, comment: ""))

                        }
                        guard let sr = obj as? OPassNonSuccessDataResponse else {
                            broken()
                            return
                        }
                        switch (sr.Response?.statusCode) {
                        case 400:
                            guard let responseObject = sr.Obj as? NSDictionary else { return }
                            let msg = responseObject.object(forKey: "message") as! String
                            NSLog("msg: \(msg)")
                            switch (msg) {
                            case "invalid token":
                                self.buttonUpdate({
                                    self.checkinBtn?.setGradientColor(from: .red, to: AppDelegate.appConfigColor("CheckinButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
                                }, nil, nil)
                            case "has been used":
                                self.showCountdown()
                                self.buttonUpdate({
                                    self.checkinBtn?.setGradientColor(from: .orange, to: AppDelegate.appConfigColor("CheckinButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
                                }, {
                                    self.checkinBtn?.setGradientColor(from: AppDelegate.appConfigColor("UsedButtonLeftColor"), to: AppDelegate.appConfigColor("UsedButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
                                }, nil)
                            case "link expired/not available now":
                                self.buttonUpdate({
                                    self.checkinBtn?.setGradientColor(from: .orange, to: AppDelegate.appConfigColor("CheckinButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
                                }, {
                                    self.checkinBtn?.setGradientColor(from: AppDelegate.appConfigColor("CheckinButtonLeftColor"), to: AppDelegate.appConfigColor("CheckinButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
                                }) {
                                    self.checkinBtn?.setTitle(NSLocalizedString(isCheckin ? "CheckinViewButton" : "UseButton", comment: ""), for: .normal)
                                }
                            default:
                                break
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

        if self.disabled.count > 0 {
            UIView.animate(withDuration: 0.25, animations: {
                self.checkinBtn?.setGradientColor(from: .orange, to: AppDelegate.appConfigColor("CheckinButtonRightColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
            }) { finished in
                if finished {
                    UIView.animate(withDuration: 1.75) {
                        self.checkinBtn?.setGradientColor(from: AppDelegate.appConfigColor("DisabledButtonLeftColor"), to: AppDelegate.appConfigColor("DisabledButtonLeftColor"), startPoint: CGPoint(x: 0.2, y: 0.8), toPoint: CGPoint(x: 1, y: 0.5))
                    }
                }
            }
            Constants.SendFib("CheckinCardView", WithEvents: ["Click": "click_disabled"])
            feedbackType = .notificationFeedbackWarning
        } else {
            if nowTime.compare(availableTime) != .orderedAscending && nowTime.compare(expireTime) != .orderedDescending {
                // IN TIME
                if isCheckin {
                    use()
                } else {
                    ac = UIAlertController.alertOfTitle(NSLocalizedString("UseButton_\(self.id)", comment: ""), withMessage: NSLocalizedString("ConfirmAlertText", comment: ""), cancelButtonText: NSLocalizedString("Cancel", comment: ""), cancelStyle: .cancel, cancelAction: nil)
                    ac?.addActionButton(NSLocalizedString("CONFIRM", comment: ""), style: .destructive, handler: { action in
                        use()
                    })
                }
            } else {
                // OUT TIME
                if nowTime.compare(availableTime) == .orderedAscending {
                    ac = UIAlertController.alertOfTitle(NSLocalizedString("NotAvailableTitle", comment: ""), withMessage: NSLocalizedString("NotAvailableMessage", comment: ""), cancelButtonText: NSLocalizedString("NotAvailableButtonOk", comment: ""), cancelStyle: .destructive, cancelAction: nil)
                    feedbackType = .notificationFeedbackError
                }
                if nowTime.compare(expireTime) == .orderedDescending || self.used > 0 {
                    ac = UIAlertController.alertOfTitle(NSLocalizedString("ExpiredTitle", comment: ""), withMessage: NSLocalizedString("ExpiredMessage", comment: ""), cancelButtonText: NSLocalizedString("ExpiredButtonOk", comment: ""), cancelStyle: .destructive, cancelAction: nil)
                    feedbackType = .notificationFeedbackError
                }
            }
        }
        // only out time or need confirm will display alert controller
        let triggerFeedback = {
            if feedbackType != nil {
                UIImpactFeedback.triggerFeedback(feedbackType!)
            }
        }
        if (ac != nil) {
            ac?.showAlert {
                triggerFeedback()
            }
        } else {
            triggerFeedback()
        }
    }
}
