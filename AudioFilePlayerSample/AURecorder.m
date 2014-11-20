//
//  AURecorder.m
//  AudioFilePlayerSample
//
//  Created by DongYi on 14-11-19.
//
//

#import "AURecorder.h"

OSStatus AURecordRenderCallback (void *inRefCon,
                                 AudioUnitRenderActionFlags *actionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    OSStatus result = noErr;
    ExtAudioFileRef file = (ExtAudioFileRef)inRefCon;
    if (*actionFlags & kAudioUnitRenderAction_PostRender) {
        result = ExtAudioFileWrite(file, inNumberFrames, ioData);
    }
    return result;
}

@implementation AURecorder {
    BOOL _isRecording;
    AUGraph _graph;
    
    AUNode _ioNode;
    AUNode _reverbNode;
    AUNode _eqNode;
    
    AudioStreamBasicDescription _streamDescription;
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
    if (result != noErr) {
        printf("NewAUGraph failed!!");
    }
    AudioComponentDescription acd;
    
    //RemoteIO Unit
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;   //ios上此值写死
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    
    
}

- (void)startRecord:(BOOL)resume {
    AUGraphStart(_graph);
}

- (void)pauseRecord {
    
}

- (void)stopRecord {
    AUGraphStop(_graph);
}

@end
