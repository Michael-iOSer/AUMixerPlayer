//
//  AudioFilePlayer.h
//  AudioFilePlayerSample
//
//  Created by DongYi on 14-11-19.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioUtilities.h"

@interface AudioFilePlayer : NSObject

@property (nonatomic, assign) BOOL isLoop;
@property (nonatomic, assign, readonly) Float32 length;
@property (nonatomic, assign) Float32 startTime;
@property (nonatomic, assign) AudioUnitParameterValue reverbMix;
@property (nonatomic, assign) AudioUnitParameterValue variSpeed;
@property (nonatomic, assign, readonly) Float32 currentPlayTime;

+ (AudioFilePlayer *)sharedAudioFilePlayer;

+ (NSString *)getHumanVoicePath;

- (BOOL)openWithURL:(NSURL *)url;
- (BOOL)openHumanWithURL:(NSURL *)url;

- (void)close;

- (void)setupRegion;
- (void)play;
- (void)stop;

@end
