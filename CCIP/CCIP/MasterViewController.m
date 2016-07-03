//
//  MasterViewController.m
//  textmv
//
//  Created by FrankWu on 2016/6/25.
//  Copyright © 2016年 FrankWu. All rights reserved.
//

#import "AppDelegate.h"
#import "GatewayWebService/GatewayWebService.h"
#import "MasterViewController.h"
#import "scenarioCell.h"
#import "DetailViewController.h"
#import "UIAlertController+additional.h"
#import "RoomLocationViewController.h"

@interface MasterViewController ()

@property NSMutableArray *objects;
@property (strong, nonatomic) AppDelegate *appDelegate;
@property (strong, nonatomic) NSDictionary *userInfo;
@property (strong, nonatomic) NSArray *scenarios;

@end

@implementation MasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(refreshData)
                  forControlEvents:UIControlEventValueChanged];
}

- (void)refreshData {
    [self.refreshControl beginRefreshing];
    self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    GatewayWebService *ws = [[GatewayWebService alloc] initWithURL:CC_STATUS(self.appDelegate.accessToken)];
    [ws sendRequest:^(NSDictionary *json, NSString *jsonStr) {
        if (json != nil) {
            NSLog(@"%@", json);
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:json];
            [userInfo removeObjectForKey:@"scenarios"];
            self.userInfo = [NSDictionary dictionaryWithDictionary:userInfo];
            self.scenarios = [json objectForKey:@"scenarios"];
            [self.tableView reloadData];
        }
        [self.refreshControl endRefreshing];
    }];
    
    GatewayWebService *roome_ws = [[GatewayWebService alloc] initWithURL:ROOM_DATA_URL];
    [roome_ws sendRequest:^(NSArray *json, NSString *jsonStr) {
        if (json != nil) {
            NSLog(@"%@", json);
            self.roomsJsonArray = json;
        }
    }];
    
    GatewayWebService *program_ws = [[GatewayWebService alloc] initWithURL:PROGRAM_DATA_URL];
    [program_ws sendRequest:^(NSArray *json, NSString *jsonStr) {
        if (json != nil) {
            NSLog(@"%@", json);
            self.programsJsonArray = json;
        }
    }];
}


- (void)viewWillAppear:(BOOL)animated {
    [self setClearsSelectionOnViewWillAppear:[self.splitViewController isCollapsed]];
    [super viewWillAppear:animated];
    
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"MasterView"];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self refreshData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSDate *object = self.objects[indexPath.row];
        DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        [controller setDetailItem:object];
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 2;
        case 1:
            return [self.scenarios count];
        case 2:
            return 1;
        default:
            return 0;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 66.0f;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"議程";
        case 1:
            return self.userInfo != nil ? [self.userInfo objectForKey:@"user_id"] : @"";
        case 2:
            return @"其他";
        default:
            return 0;
    }
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0) {
        // section 0 Start
        
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:NULL];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        
        switch (indexPath.row) {
            case 0:
                [cell.textLabel setText:@"人文館"];
                break;
            case 1:
                [cell.textLabel setText:@"活動中心"];
                break;
            default:
                [cell.textLabel setText:@"null"];
                break;
        }
        
        return cell;
        // section 0 End
    } else if (indexPath.section == 1) {
        // section 1 Start
        
        NSString *CellIdentifier = @"scenario";
        scenarioCell *cell = nil;
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            [tableView registerNib:[UINib nibWithNibName:@"scenarioCell"
                                                  bundle:nil]
            forCellReuseIdentifier:CellIdentifier];
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        }
        
        NSDictionary *scenario = [self.scenarios objectAtIndex:indexPath.row];
        NSDate *availableTime = [NSDate dateWithTimeIntervalSince1970:[[scenario objectForKey:@"available_time"] integerValue]];
        NSDate *expireTime = [NSDate dateWithTimeIntervalSince1970:[[scenario objectForKey:@"expire_time"] integerValue]];
        NSDateFormatter *formatter = [NSDateFormatter new];
        [formatter setDateFormat:@"MM/dd HH:mm"];
        NSDate *nowTime = [NSDate new];
        if ([nowTime compare:availableTime] != NSOrderedAscending && [nowTime compare:expireTime] != NSOrderedDescending) {
            // IN TIME
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        } else {
            // OUT TIME
            [cell setAccessoryType:UITableViewCellAccessoryDetailButton];
        }
        [cell.scenarioLabel setText:[scenario objectForKey:@"id"]];
        [cell.timeRangeLabel setText:[NSString stringWithFormat:@"%@ ~ %@", [formatter stringFromDate:availableTime], [formatter stringFromDate:expireTime]]];
        
        NSString *usedTimeString = @"";
        if ([[scenario allKeys] containsObject:@"disabled"]) {
            if ([[scenario objectForKey:@"disabled"] length] > 0) {
                [cell setAccessoryType:UITableViewCellAccessoryDetailButton];
                [cell.scenarioLabel setTextColor:[UIColor lightGrayColor]];
                [cell setBackgroundColor:[UIColor colorWithWhite:0.8f alpha:0.5f]];
                [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                [cell setUserInteractionEnabled:NO];
            }
        }
        if ([[scenario allKeys] containsObject:@"used"]) {
            NSInteger usedTime = [[scenario objectForKey:@"used"] integerValue];
            if (usedTime > 0) {
                [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
                [formatter setDateFormat:@"MM/dd HH:mm:ss"];
                usedTimeString = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:usedTime]];
                [formatter setDateFormat:@"MM/dd HH:mm"];
            }
        }
        [cell.usedTimeLabel setText:usedTimeString];
        
        return cell;
        // section 1 End
    } else if (indexPath.section == 2) {
        // section 0 Start
        
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:NULL];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        
        switch (indexPath.row) {
            case 0:
                [cell.textLabel setText:@"IRC"];
                break;
            default:
                [cell.textLabel setText:@"null"];
                break;
        }
        
        return cell;
        // section 0 End
    } else {
        // default
        
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:NULL];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0) {
        // section 0 Start
        RoomLocationViewController *roomLocationView = NULL;
        roomLocationView = [RoomLocationViewController new];
        [roomLocationView setTitle:[[[tableView cellForRowAtIndexPath:indexPath] textLabel] text]];
        
        NSMutableArray *rooms = [NSMutableArray new];
        NSString *roomKey = @"";
        
        switch (indexPath.row) {
            case 0:
                roomKey = @"R";
                break;
            case 1:
                roomKey = @"H";
                break;
            default:
                roomKey = @"";
                break;
        }
        
        for (NSDictionary *dict in self.roomsJsonArray) {
            if ([[[dict objectForKey:@"room"] substringToIndex:1] isEqualToString:roomKey]) {
                [rooms addObject:dict];
            }
        }
        
        SEL setRoomsValue = NSSelectorFromString(@"setRooms:");
        if ([roomLocationView canPerformAction:setRoomsValue withSender:nil]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [roomLocationView performSelector:setRoomsValue
                                   withObject:rooms];
#pragma clang diagnostic pop
        }
        
        SEL setProgramsValue = NSSelectorFromString(@"setRoomPrograms:");
        if ([roomLocationView canPerformAction:setProgramsValue withSender:nil]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [roomLocationView performSelector:setProgramsValue
                                   withObject:self.programsJsonArray];
#pragma clang diagnostic pop
        }
        
        [self.splitViewController showDetailViewController:roomLocationView
                                                    sender:self];
        
        // section 0 End
    } else if (indexPath.section == 1) {
        // section 1 Start
        
        NSDictionary *scenario = [self.scenarios objectAtIndex:indexPath.row];
        BOOL isUsed = [[scenario allKeys] containsObject:@"used"] ? [scenario objectForKey:@"used"] > 0 : NO;
        NSString *vcName = isUsed ? @"StatusViewController" : @"CheckinViewController";
        UIViewController *detailViewController = [[UIViewController alloc] initWithNibName:vcName
                                                                                    bundle:nil];
        [detailViewController.view setBackgroundColor:[UIColor whiteColor]];
        UIBarButtonItem *backButton = isUsed ? [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                             target:self
                                                                                             action:@selector(gotoTop)] : self.splitViewController.displayModeButtonItem;
        [detailViewController.navigationItem setLeftBarButtonItem:backButton];
        [detailViewController.navigationItem setLeftItemsSupplementBackButton:!isUsed];
        
        NSDate *availableTime = [NSDate dateWithTimeIntervalSince1970:[[scenario objectForKey:@"available_time"] integerValue]];
        NSDate *expireTime = [NSDate dateWithTimeIntervalSince1970:[[scenario objectForKey:@"expire_time"] integerValue]];
        NSDate *nowTime = [NSDate new];
        
        if ([nowTime compare:availableTime] != NSOrderedAscending && [nowTime compare:expireTime] != NSOrderedDescending) {
            // IN TIME Start
            SEL setScenarioValue = NSSelectorFromString(@"setScenario:");
            if ([detailViewController.view canPerformAction:setScenarioValue withSender:nil]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [detailViewController.view performSelector:setScenarioValue
                                                withObject:scenario];
#pragma clang diagnostic pop
            }
            [detailViewController setTitle:[scenario objectForKey:@"id"]];
            UINavigationController *detailNavigationController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
            [self.splitViewController showDetailViewController:detailNavigationController
                                                        sender:self];
            // for hack to toggle the master view in split view on portrait iPad
            UIBarButtonItem *barButtonItem = [self.splitViewController displayModeButtonItem];
            [[UIApplication sharedApplication] sendAction:[barButtonItem action]
                                                       to:[barButtonItem target]
                                                     from:nil
                                                 forEvent:nil];
            // IN TIME End
        } else {
            // OUT TIME Start
            UIAlertController *ac = nil;
            if ([nowTime compare:availableTime] == NSOrderedAscending) {
                ac = [UIAlertController alertOfTitle:NSLocalizedString(@"NotAvailableTitle", nil)
                                         withMessage:NSLocalizedString(@"NotAvailableMessage", nil)
                                    cancelButtonText:NSLocalizedString(@"NotAvailableButtonOk", nil)
                                         cancelStyle:UIAlertActionStyleDestructive
                                        cancelAction:^(UIAlertAction *action) {
                                            [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO
                                                                                            animated:YES];
                                        }];
            }
            if ([nowTime compare:expireTime] == NSOrderedDescending) {
                ac = [UIAlertController alertOfTitle:NSLocalizedString(@"ExpiredTitle", nil)
                                         withMessage:NSLocalizedString(@"ExpiredMessage", nil)
                                    cancelButtonText:NSLocalizedString(@"ExpiredButtonOk", nil)
                                         cancelStyle:UIAlertActionStyleDestructive
                                        cancelAction:^(UIAlertAction *action) {
                                            [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO
                                                                                            animated:YES];
                                        }];
            }
            if (ac != nil) {
                [ac showAlert:^{}];
            }
            // OUT TIME End
        }
        // section 1 End
    } else if (indexPath.section == 2) {
        // section 2 Start
        NSString *vcName = @"IRCViewController";
        UIViewController *detailViewController = [[UIViewController alloc] initWithNibName:vcName bundle:nil];
        
        SEL setScenarioValue = NSSelectorFromString(@"setURL:");
        if ([detailViewController.view canPerformAction:setScenarioValue withSender:nil]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [detailViewController.view performSelector:setScenarioValue withObject:@{@"url": LOG_BOT_URL}];
#pragma clang diagnostic pop
        }
        [detailViewController setTitle:[[[tableView cellForRowAtIndexPath:indexPath] textLabel] text]];
        UINavigationController *detailNavigationController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
        [self.splitViewController showDetailViewController:detailNavigationController
                                                    sender:self];
        // for hack to toggle the master view in split view on portrait iPad
        UIBarButtonItem *barButtonItem = [self.splitViewController displayModeButtonItem];
        [[UIApplication sharedApplication] sendAction:[barButtonItem action]
                                                   to:[barButtonItem target]
                                                 from:nil
                                             forEvent:nil];
        // section 2 End
    }
}

- (void)gotoTop {
    [((UINavigationController *)[self.appDelegate.splitViewController.viewControllers firstObject]) popToRootViewControllerAnimated:YES];
}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end