//
//  PlayerViewController.h
//  AudioFilePlayerSample
//
//  Created by DongYi on 14-11-19.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PlayerViewController : UIViewController

@property (nonatomic, retain) NSString *audioFilePath;
@property (nonatomic, retain) IBOutlet UISlider *startTimeSlider;
@property (nonatomic, retain) IBOutlet UISwitch *loopSwitch;
@property (nonatomic, retain) IBOutlet UISlider *variSpeedSlider;
@property (nonatomic, retain) IBOutlet UISlider *reverbMixSlider;
@property (nonatomic, retain) IBOutlet UILabel *timeLabel;

@end
