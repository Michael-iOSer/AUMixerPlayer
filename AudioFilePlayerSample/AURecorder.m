//
//  AURecorder.m
//  AudioFilePlayerSample
//
//  Created by DongYi on 14-11-19.
//
//

#import "AURecorder.h"

OSStatus 

@implementation AURecorder {
    BOOL _isRecording;
    AUGraph _graph;
    AudioStreamBasicDescription _asbd;
    ExtAudioFileRef _recordedExtFile;
}


- (instancetype)init {
    self = [super init];
    if (self) {
        _isRecording = NO;
    }
    return self;
}

- (BOOL)isRecording {
    return _isRecording;
}

//初始化graph
- (void)initRecord {
    OSStatus result = noErr;
    result = NewAUGraph(&_graph);
    
}

- (void)startRecord:(BOOL)resume {
    AUGraphStart(_graph);
}

- (void)pauseRecord {
    
}

- (void)stopRecord {

}

@end
