//
//  CheckinView.h
//  CCIP
//
//  Created by 腹黒い茶 on 2016/06/26.
//  Copyright © 2016年 CPRTeam. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CheckinView : UIView

@property (strong, nonatomic) NSDictionary *scenario;

@property (weak, nonatomic) IBOutlet UILabel *checkinMessabeLabel;
@property (weak, nonatomic) IBOutlet UIButton *checkinBtn;

- (IBAction)checkinBtnEvent:(id)sender;

@end