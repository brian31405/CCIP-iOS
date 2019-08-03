//
//  MoreTableViewController.swift
//  OPass
//
//  Created by 腹黒い茶 on 2019/2/9.
//  Copyright © 2019 OPass. All rights reserved.
//

import Foundation
import UIKit
import AudioToolbox
import AFNetworking
import FontAwesome_swift
import Nuke

class MoreTableViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var moreTableView: UITableView?
    var shimmeringLogoView: FBShimmeringView = FBShimmeringView.init(frame: CGRect(x: 0, y: 0, width: 500, height: 50))
    var userInfo: ScenarioStatus?
    var moreItems: NSArray?
    var webViews: [EventFeatures] = []
    var webViewIndex = 0
    var switchEventButton: UIBarButtonItem?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destination = segue.destination
        let cell = sender as! UITableViewCell
        let title = cell.textLabel?.text
        Constants.SendFib("MoreTableView", WithEvents: [ "MoreTitle": title ])
        destination.title = title
        cell.setSelected(false, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // set logo on nav title
        self.shimmeringLogoView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(navSingleTap))
        tapGesture.numberOfTapsRequired = 1
        self.shimmeringLogoView.addGestureRecognizer(tapGesture)
        self.navigationItem.titleView = self.shimmeringLogoView

        let nvBar = self.navigationController?.navigationBar
        nvBar!.setBackgroundImage(UIImage.init(), for: .default)
        nvBar!.shadowImage = UIImage.init()
        nvBar!.backgroundColor = UIColor.clear
        nvBar!.isTranslucent = false
        let frame = CGRect.init(x: 0, y: 0, width: self.view.frame.size.width, height: UIApplication.shared.statusBarFrame.size.height + self.navigationController!.navigationBar.frame.size.height)
        let headView = UIView.init(frame: frame)
        headView.setGradientColor(from: Constants.appConfigColor("MoreTitleLeftColor"), to: Constants.appConfigColor("MoreTitleRightColor"), startPoint: CGPoint(x: -0.4, y: 0.5), toPoint: CGPoint(x: 1, y: 0.5))
        let naviBackImg = headView.layer.sublayers?.last?.toImage()
        nvBar?.setBackgroundImage(naviBackImg, for: .default)

        Constants.SendFib("MoreTableViewController")

        if self.switchEventButton == nil {
            let attribute = [
                NSAttributedString.Key.font: UIFont.fontAwesome(ofSize: 20, style: .solid)
            ]
            self.switchEventButton = UIBarButtonItem.init(title: "", style: .plain, target: self, action: #selector(CallSwitchEventView))
            self.switchEventButton!.setTitleTextAttributes(attribute, for: .normal)
            self.switchEventButton!.title = String.fontAwesomeIcon(code: "fa-sign-out-alt")
        }

        self.navigationItem.rightBarButtonItem = self.switchEventButton
        
        let emptyButton = UIBarButtonItem.init(title: "　", style: .plain, target: nil, action: nil)
        self.navigationItem.leftBarButtonItem = emptyButton;
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Constants.LoadDevLogoTo(view: self.shimmeringLogoView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.userInfo = OPassAPI.userInfo
        self.webViews = OPassAPI.eventInfo?.Features.filter({
            $0.Feature == OPassKnownFeatures.WebView.rawValue
        }) ?? []
        let web = self.webViews.map({ _ -> String in
            return "MoreWeb"
        })
        self.moreItems = ([
            OPassAPI.eventInfo?.Features[OPassKnownFeatures.Puzzle]?.Url != nil
                ? "Puzzle"
                : "",
            OPassAPI.eventInfo?.Features[OPassKnownFeatures.FastPass] != nil
                ? "Ticket"
                : "",
            OPassAPI.eventInfo?.Features[OPassKnownFeatures.Telegram]?.Url != nil
                ? "Telegram"
                : "",
            OPassAPI.eventInfo?.Features[OPassKnownFeatures.Venue]?.Url != nil
                ? "VenueWeb"
                : "",
            OPassAPI.eventInfo?.Features[OPassKnownFeatures.Staffs]?.Url != nil
                ? "StaffsWeb"
                : "",
            OPassAPI.eventInfo?.Features[OPassKnownFeatures.Sponsors]?.Url != nil
                ? "SponsorsWeb"
                : "",
            OPassAPI.eventInfo?.Features[OPassKnownFeatures.Partners]?.Url != nil
                ? "PartnersWeb"
                : "",
            ].filter({ $0.count > 0 }) + web + [
                "Acknowledgements",
            ]) as NSArray
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func CallSwitchEventView() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func navSingleTap() {
        //NSLog(@"navSingleTap");
        self.handleNavTapTimes()
    }

    func handleNavTapTimes() {
        struct tap {
            static var tapTimes: Int = 0
            static var oldTapTime: Date?
            static var newTapTime: Date?
        }

        tap.newTapTime = Date.init()
        if (tap.oldTapTime == nil) {
            tap.oldTapTime = tap.newTapTime
        }

        if (tap.newTapTime!.timeIntervalSince(tap.oldTapTime!) <= 0.25) {
            tap.tapTimes += 1
            if (tap.tapTimes >= 10) {
                NSLog("--  Success tap 10 times  --")
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                if !Constants.isDevMode {
                    NSLog("-- Enable DEV_MODE --")
                    Constants.isDevMode = true
                } else {
                    NSLog("-- Disable DEV_MODE --")
                    Constants.isDevMode = false
                }
                Constants.LoadDevLogoTo(view: self.shimmeringLogoView)
                tap.tapTimes = 1
            }
        } else {
            NSLog("--  Failed, just tap %2d times  --", tap.tapTimes)
            NSLog("-- Failed to trigger DEV_MODE --")
            tap.tapTimes = 1
        }
        tap.oldTapTime = tap.newTapTime
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return (self.moreTableView?.frame.size.height)! / CGFloat(self.moreItems!.count + 1)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.moreItems!.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section:NSInteger) -> String? {
        return (self.userInfo?.UserId.count ?? 0) > 0 ? String(format: NSLocalizedString("Hi", comment: ""), self.userInfo!.UserId as CVarArg) : nil;
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId = self.moreItems!.object(at: indexPath.row) as! String
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! MoreCell
        let brands = [
            NSAttributedString.Key.font: Constants.fontOfAwesome(withSize: 24, inStyle: .brands),
        ]
        let solid = [
            NSAttributedString.Key.font: Constants.fontOfAwesome(withSize: 24, inStyle: .solid),
        ]
        let cellIconId = NSLocalizedString("icon-\(cellId)", comment: "");
        var cellIcon = NSMutableAttributedString.init(string: cellIconId, attributes: solid)
        var cellText = NSLocalizedString(cellId, comment: "")
        if (cellIcon.size().width > 40) {
            cellIcon = NSMutableAttributedString.init(string: cellIconId, attributes: brands)
        }
        // cell.textLabel!.text = cellText
        if (cellId == "MoreWeb") {
            let feature = self.webViews[self.webViewIndex]
            cell.Feature = feature
            cellText = feature.DisplayText[Constants.shortLangUI]
            self.webViewIndex += 1
        }
        cell.textLabel!.attributedText = NSAttributedString.init(attributedString: cellIcon + "  \t  " + cellText)
        return cell;
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! MoreCell
        let url = cell.Feature?.Url
        if (url != nil) {
            Constants.OpenInAppSafari(forURL: url!)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    /*
     // Override to support conditional editing of the table view.
     - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
         // Return NO if you do not want the specified item to be editable.
         return YES;
     }
     */

    /*
     // Override to support editing the table view.
     - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
         if (editingStyle == UITableViewCellEditingStyleDelete) {
             // Delete the row from the data source
             [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
         } else if (editingStyle == UITableViewCellEditingStyleInsert) {
             // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
         }
     }
     */

    /*
     // Override to support rearranging the table view.
     - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
     }
     */

    /*
     // Override to support conditional rearranging of the table view.
     - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
         // Return NO if you do not want the item to be re-orderable.
         return YES;
     }
     */

    //#pragma mark - Table view delegate
    //- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //    [tableView deselectRowAtIndexPath:indexPath
    //                             animated:YES];
    //    NSDictionary *item = [self.moreItems objectAtIndex:indexPath.row];
    //    NSString *title = [[[tableView cellForRowAtIndexPath:indexPath] textLabel] text];
    //    ((void(^)(NSString *))[item objectForKey:@"detailViewController"])(title);
    //    SEND_FIB_EVENT(@"MoreTableView", title);
    //}

    /*
     #pragma mark - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
         // Get the new view controller using [segue destinationViewController].
         // Pass the selected object to the new view controller.
     }
     */
}
