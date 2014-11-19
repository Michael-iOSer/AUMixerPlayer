//
//  KTVAURender.m
//  AudioFilePlayerSample
//
//  Created by DongYi on 14-11-19.
//
//

#import "KTVAURender.h"

@implementation KTVAURender

+ (NSString *)destPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"recordedFile.caf"];
}

+ (NSString *)demoVoicePath {
    return [[[NSBundle mainBundle] pathsForResourcesOfType:@"caf" inDirectory:nil] objectAtIndex:0];
}

+ (NSString *)demoMusicPath {
    return [[[NSBundle mainBundle] pathsForResourcesOfType:@"mp3" inDirectory:nil] objectAtIndex:0];
}

@end
