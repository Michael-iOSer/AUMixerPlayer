//
//  AudioFilePlayer.m
//  AudioFilePlayerSample
//
//  Created by DongYi on 14-11-19.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "AudioFilePlayer.h"
#import <mach/mach.h>
#import <mach/mach_time.h>

static uint64_t ConvertNanoSecToMachTime(uint64_t nanoSec) {
    mach_timebase_info_data_t timebaseInfo;
    mach_timebase_info(&timebaseInfo);
    return nanoSec * timebaseInfo.denom / timebaseInfo.numer;
}

//OSStatus recordRenderNotify(void                        *inRefCon,
//                            AudioUnitRenderActionFlags  *ioActionFlags,
//                            const AudioTimeStamp        *inTimeStamp,
//                            UInt32                      inBusNumber,
//                            UInt32                      inNumberFrames,
//                            AudioBufferList             *ioData);

@interface AudioFilePlayer()
- (void)createAUGraph;
- (void)disposeAUGraph;
@end

@implementation AudioFilePlayer {
    
    ExtAudioFileRef _extAudioFile;
    ExtAudioFileRef _humanExtAudioFile;
    
    AudioFileID _audioFileID;
    AudioFileID _humanAudioFileID;
    
    ExtAudioFileRef _destExtAudioFile;
    AudioFileID _destFileID;
    
    AudioStreamBasicDescription _audioFileFormat;
    UInt32 _audioFileFrames;
    
    AudioStreamBasicDescription _humanAudioFileFormat;
    UInt32 _humanAudioFileFrames;
    
    AUGraph _auGraph;
    AUNode _ioNode;
    
    //混响结点
    AUNode _reverbNode;
    
    AUNode _mixerNode;
    
    AUNode _variSpeedNode;
    AUNode _playerNode;
    AUNode _humanPlayerNode;
    
    AUNode _pitchNode;
    
    AudioStreamBasicDescription _ioFormat;
}
@synthesize isLoop = _isLoop;
@dynamic length;
@synthesize startTime = _startTime;
@dynamic reverbMix, variSpeed, currentPlayTime;

#pragma mark - Memory Management

static AudioFilePlayer *_sharedAudioFilePlayer = nil;

+ (id)sharedAudioFilePlayer
{
    if (!_sharedAudioFilePlayer) {
        _sharedAudioFilePlayer = [[self alloc] init];
    }
    return _sharedAudioFilePlayer;
}

- (id)init {
    self = [super init];
    if (self) {
        
        _isLoop = NO;
        _startTime = 0;
        
        [self createAUGraph];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    [self close];
    [self disposeAUGraph];
    [super dealloc];
}

- (Float32)length
{
    Float32 result = 0;
    if (_audioFileID) {
        result = (Float32)_audioFileFrames / _audioFileFormat.mSampleRate;
    }
    return result;
}

#pragma mark - Audio

+ (NSString *)getHumanVoicePath {
    return [[[NSBundle mainBundle] pathsForResourcesOfType:@"caf" inDirectory:nil] objectAtIndex:0];
}

- (void)createAUGraph
{
    OSStatus err = noErr;
    
    err = NewAUGraph(&_auGraph);
    require_noerr(err, bail);
    
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    err = AUGraphAddNode(_auGraph, &acd, &_ioNode);
    require_noerr(err, bail);
//    err = AUGraphAddNode(_auGraph, &acd, &_humanIONode);
//    require_noerr(err, bail);
    
    acd.componentType = kAudioUnitType_Effect;
    acd.componentSubType = kAudioUnitSubType_Reverb2;
    err = AUGraphAddNode(_auGraph, &acd, &_reverbNode);
    require_noerr(err, bail);
    
    
    acd.componentType = kAudioUnitType_Mixer;
    acd.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    err = AUGraphAddNode(_auGraph, &acd, &_mixerNode);
    require_noerr(err, bail);
    
    acd.componentType = kAudioUnitType_FormatConverter;
    acd.componentSubType = kAudioUnitSubType_NewTimePitch;
    err = AUGraphAddNode(_auGraph, &acd, &_pitchNode);
    require_noerr(err, bail);
    
    acd.componentType = kAudioUnitType_FormatConverter;
    acd.componentSubType = kAudioUnitSubType_Varispeed;
    err = AUGraphAddNode(_auGraph, &acd, &_variSpeedNode);
    require_noerr(err, bail);
    
    acd.componentType = kAudioUnitType_Generator;
    acd.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    
    err = AUGraphAddNode(_auGraph, &acd, &_playerNode);
    require_noerr(err, bail);
    
    err = AUGraphAddNode(_auGraph, &acd, &_humanPlayerNode);
    require_noerr(err, bail);
    
    err = AUGraphOpen(_auGraph);
    require_noerr(err, bail);
    
    //RemoteIOのインプットのフォーマットをFloat32非インターリーブにする
    AudioUnit unit;
    GetEffectFormat(&_ioFormat);
    
    err = AUGraphNodeInfo(_auGraph, _ioNode, NULL, &unit);
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    
    err = AUGraphNodeInfo(_auGraph, _mixerNode, NULL, &unit);
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    
    //[self createDestFile];
//    AudioUnitAddRenderNotify(unit, &MyAURenderCallback, &_destExtAudioFile);
    
    err = AUGraphNodeInfo(_auGraph, _reverbNode, NULL, &unit);
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    AudioUnitParameterValue reverbTime = 2.5;
    err = AudioUnitSetParameter(unit, 4, kAudioUnitScope_Global, 0, reverbTime, 0);
    require_noerr(err, bail);
    err = AudioUnitSetParameter(unit, 5, kAudioUnitScope_Global, 0, reverbTime, 0);
    require_noerr(err, bail);
    
    err = AUGraphNodeInfo(_auGraph, _pitchNode, NULL, &unit);
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    AudioUnitParameterValue pitchRate = 1.0f;
    err = AudioUnitSetParameter(unit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitchRate, 0);
    require_noerr(err, bail);
    AudioUnitParameterValue overlap = 8.0f;
    err = AudioUnitSetParameter(unit, kNewTimePitchParam_Overlap, kAudioUnitScope_Global, 0, overlap, 0);
    require_noerr(err, bail);
    
    err = AUGraphNodeInfo(_auGraph, _variSpeedNode, NULL, &unit);
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    
    err = AUGraphNodeInfo(_auGraph, _playerNode, NULL, &unit);
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    
    err = AUGraphNodeInfo(_auGraph, _humanPlayerNode, NULL, &unit);
    require_noerr(err, bail);
    err = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_ioFormat, sizeof(AudioStreamBasicDescription));
    require_noerr(err, bail);
    
    //humanPlayerNode -> _reverbNode -> _mixerNode
    //musicPlayerNode -> _mixerNode
    
    err = AUGraphConnectNodeInput(_auGraph, _humanPlayerNode, 0, _pitchNode, 0);
    require_noerr(err, bail);
    
    //err = AUGraphConnectNodeInput(_auGraph, _playerNode, 0, _mixerNode, 0);
    require_noerr(err, bail);
    
    err = AUGraphConnectNodeInput(_auGraph, _pitchNode, 0, _mixerNode, 1);
    require_noerr(err, bail);
    
    err = AUGraphConnectNodeInput(_auGraph, _mixerNode, 0, _ioNode, 0);
    require_noerr(err, bail);
    
//    err = AUGraphConnectNodeInput(_auGraph, _variSpeedNode, 0, _reverbNode, 0);
//    require_noerr(err, bail);
//    
//    err = AUGraphConnectNodeInput(_auGraph, _mixerNode, 0, _variSpeedNode, 0);
//    require_noerr(err, bail);
//    
//    err = AUGraphConnectNodeInput(_auGraph, _playerNode, 0, _mixerNode, 0);
//    require_noerr(err, bail);
//    
//    err = AUGraphConnectNodeInput(_auGraph, _humanPlayerNode, 0, _mixerNode, 1);
//    require_noerr(err, bail);
    
    err = AUGraphInitialize (_auGraph);
    require_noerr(err, bail);
    
//    err = AUGraphStart (_auGraph);
//    require_noerr(err, bail);
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
        if (_auGraph) DisposeAUGraph(_auGraph);
    }
}

- (void)disposeAUGraph
{
    AUGraphStop(_auGraph);
    AUGraphUninitialize(_auGraph);
    AUGraphClose(_auGraph);
}

#pragma mark - AudioFile

- (BOOL)openWithURL:(NSURL *)url
{
    [self stop];
    [self close];
    
    _startTime = 0;
    _audioFileFrames = 0;
    
    OSStatus err = noErr;
    UInt32 size;
    
    err = ExtAudioFileOpenURL((CFURLRef)url, &_extAudioFile);
    require_noerr(err, bail);
    
    size = sizeof(_audioFileID);
    ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_AudioFile, &size, &_audioFileID);
    require_noerr(err, bail);
    
    size = sizeof(AudioStreamBasicDescription);
    err = AudioFileGetProperty(_audioFileID, kAudioFilePropertyDataFormat, &size, &_audioFileFormat);
    require_noerr(err, bail);
    
    SInt64 fileLengthFrames;
    size = sizeof(SInt64);
    err = ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &fileLengthFrames);
    require_noerr(err, bail);
    
    _audioFileFrames = fileLengthFrames;
    
bail:
    
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
        [self close];
        return NO;
    }
    
    return YES;
}

- (BOOL)openHumanWithURL:(NSURL *)url
{
//    [self stop];
//    [self close];
    
//    _startTime = 0;
//    _audioFileFrames = 0;
    
    OSStatus err = noErr;
    UInt32 size;
    
    err = ExtAudioFileOpenURL((CFURLRef)url, &_humanExtAudioFile);
    require_noerr(err, bail);
    
    size = sizeof(_humanAudioFileID);
    ExtAudioFileGetProperty(_humanExtAudioFile, kExtAudioFileProperty_AudioFile, &size, &_humanAudioFileID);
    require_noerr(err, bail);
    
    size = sizeof(AudioStreamBasicDescription);
    err = AudioFileGetProperty(_humanAudioFileID, kAudioFilePropertyDataFormat, &size, &_humanAudioFileFormat);
    require_noerr(err, bail);
    
    SInt64 fileLengthFrames;
    size = sizeof(SInt64);
    err = ExtAudioFileGetProperty(_humanExtAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &fileLengthFrames);
    require_noerr(err, bail);
    
//    [self createDestFile];
//    AudioUnit unit;
//    err = AUGraphNodeInfo(_auGraph, _ioNode, NULL, &unit);
//    require_noerr(err, bail);
//    AudioUnitAddRenderNotify(unit, &MyAURenderCallback, _destExtAudioFile);
    
    _humanAudioFileFrames = fileLengthFrames;
    
bail:
    
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
        [self close];
        return NO;
    }
    return YES;
}

- (void)close
{
    [self stop];
    
    if (_extAudioFile) {
        ExtAudioFileDispose(_extAudioFile);
        _extAudioFile = NULL;
        _audioFileID = NULL;
    }
    
    
    if (_humanExtAudioFile) {
        ExtAudioFileDispose(_humanExtAudioFile);
        _humanExtAudioFile = NULL;
        _humanAudioFileID = NULL;
    }
    
    _startTime = 0;
}

- (void)play
{
    [self setupRegion];
    [self setupHumanRegion];
    AUGraphStart (_auGraph);
    [self startPlayerAfterSeconds:0];
    [self startHumanPlayerAfterSeconds:0];
    
}

- (void)stop
{
    OSStatus err = noErr;
    
    AudioUnit playerUnit;
    err = AUGraphNodeInfo(_auGraph, _playerNode, NULL, &playerUnit);
    require_noerr(err, bail);
    
    err = AudioUnitReset(playerUnit, kAudioUnitScope_Global, 0);
    require_noerr(err, bail);
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
}

- (void)setupRegion
{
    if (!_audioFileID) return;
    
    [self stop];
    
    OSStatus err = noErr;
    
    AudioUnit playerUnit;
    err = AUGraphNodeInfo(_auGraph, _playerNode, NULL, &playerUnit);
    require_noerr(err, bail);
    
    err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &_audioFileID, sizeof(AudioFileID));
    require_noerr(err, bail);
    
    ScheduledAudioFileRegion region = {0};
    region.mAudioFile = _audioFileID;
    region.mCompletionProc = NULL;
    region.mCompletionProcUserData = NULL;
    region.mLoopCount = 0;
    region.mStartFrame = _startTime * _audioFileFormat.mSampleRate;
    region.mFramesToPlay = _audioFileFrames - region.mStartFrame;
    region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    region.mTimeStamp.mSampleTime = 0;
    
    err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, sizeof(ScheduledAudioFileRegion));
    require_noerr(err, bail);
    
    if (_isLoop) {
        
        Float32 nextPlayFrame = _ioFormat.mSampleRate / _audioFileFormat.mSampleRate * region.mFramesToPlay;
        
        region.mAudioFile = _audioFileID;
        region.mCompletionProc = NULL;
        region.mCompletionProcUserData = NULL;
        region.mLoopCount = UINT32_MAX;
        region.mStartFrame = 0;
        region.mFramesToPlay = _audioFileFrames;
        region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
        region.mTimeStamp.mSampleTime = nextPlayFrame;
        
        err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, sizeof(ScheduledAudioFileRegion));
        require_noerr(err, bail);
    }
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
}

- (void)setupHumanRegion
{
    
    if (!_humanAudioFileID) return;
    
//    [self stop];
    
    OSStatus err = noErr;
    
    AudioUnit playerUnit;
    err = AUGraphNodeInfo(_auGraph, _humanPlayerNode, NULL, &playerUnit);
    require_noerr(err, bail);
    
    err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &_humanAudioFileID, sizeof(AudioFileID));
    require_noerr(err, bail);
    
    ScheduledAudioFileRegion region = {0};
    region.mAudioFile = _humanAudioFileID;
    region.mCompletionProc = NULL;
    region.mCompletionProcUserData = NULL;
    region.mLoopCount = 0;
    region.mStartFrame = _startTime * _humanAudioFileFormat.mSampleRate;
    region.mFramesToPlay = _humanAudioFileFrames - region.mStartFrame;
    region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    region.mTimeStamp.mSampleTime = 0;
    
    err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, sizeof(ScheduledAudioFileRegion));
    require_noerr(err, bail);
    
    if (_isLoop) {
        
        Float32 nextPlayFrame = _ioFormat.mSampleRate / _humanAudioFileFormat.mSampleRate * region.mFramesToPlay;
        
        region.mAudioFile = _humanAudioFileID;
        region.mCompletionProc = NULL;
        region.mCompletionProcUserData = NULL;
        region.mLoopCount = UINT32_MAX;
        region.mStartFrame = 0;
        region.mFramesToPlay = _humanAudioFileFrames;
        region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
        region.mTimeStamp.mSampleTime = nextPlayFrame;
        
        err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, sizeof(ScheduledAudioFileRegion));
        require_noerr(err, bail);
    }
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
}

- (void)startPlayerAfterSeconds:(Float64)sec
{
    if (!_audioFileID) return;
    
    OSStatus err = noErr;
    
    AudioUnit playerUnit;
    err = AUGraphNodeInfo(_auGraph, _playerNode, NULL, &playerUnit);
    require_noerr(err, bail);
    
    UInt64 curHostTime = mach_absolute_time();
    UInt64 delayTime = ConvertNanoSecToMachTime(1000000000) * sec;
    
    AudioTimeStamp theTimeStamp = {0};
    theTimeStamp.mFlags = kAudioTimeStampHostTimeValid;
    if (0 < sec) {
        theTimeStamp.mHostTime = curHostTime + delayTime;
    } else {
        theTimeStamp.mHostTime = 0;
    }
    
	err = AudioUnitSetProperty(playerUnit,
                               kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0,
                               &theTimeStamp, sizeof(theTimeStamp));
    require_noerr(err, bail);
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
}

- (void)startHumanPlayerAfterSeconds:(Float64)sec {
    if (!_humanAudioFileID) return;
    
    OSStatus err = noErr;
    
    AudioUnit playerUnit;
    err = AUGraphNodeInfo(_auGraph, _humanPlayerNode, NULL, &playerUnit);
    require_noerr(err, bail);
    
    UInt64 curHostTime = mach_absolute_time();
    UInt64 delayTime = ConvertNanoSecToMachTime(1000000000) * sec;
    
    AudioTimeStamp theTimeStamp = {0};
    theTimeStamp.mFlags = kAudioTimeStampHostTimeValid;
    if (0 < sec) {
        theTimeStamp.mHostTime = curHostTime + delayTime;
    } else {
        theTimeStamp.mHostTime = 0;
    }
    
	err = AudioUnitSetProperty(playerUnit,
                               kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0,
                               &theTimeStamp, sizeof(theTimeStamp));
    require_noerr(err, bail);
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
}

#pragma mark - アクセサ

- (void)setReverbMix:(AudioUnitParameterValue)value
{
    AudioUnit reverbUnit;
    OSStatus err = AUGraphNodeInfo(_auGraph, _reverbNode, NULL, &reverbUnit);
    require_noerr(err, bail);
    
    err = AudioUnitSetParameter(reverbUnit, 0, kAudioUnitScope_Global, 0, value, 0);
    require_noerr(err, bail);
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
}

- (AudioUnitParameterValue)reverbMix
{
    AudioUnitParameterValue value = 0;
    
    AudioUnit reverbUnit;
    OSStatus err = AUGraphNodeInfo(_auGraph, _reverbNode, NULL, &reverbUnit);
    require_noerr(err, bail);
    
    err = AudioUnitGetParameter(reverbUnit, 0, kAudioUnitScope_Global, 0, &value);
    require_noerr(err, bail);
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
    
    return value;
}

- (void)setVariSpeed:(AudioUnitParameterValue)value
{
    AudioUnit pitchUnit;
    OSStatus err = AUGraphNodeInfo(_auGraph, _pitchNode, NULL, &pitchUnit);
    AudioUnitSetParameter(pitchUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, value, 0);
//    AudioUnit variUnit;
//    OSStatus err = AUGraphNodeInfo(_auGraph, _variSpeedNode, NULL, &variUnit);
//    require_noerr(err, bail);
//    
//    err = AudioUnitSetParameter(variUnit, 1, kAudioUnitScope_Global, 0, value, 0);
//    require_noerr(err, bail);
//    
//bail:
//    if (err) {
//        NSLog(@"%s %ld", __FUNCTION__, err);
//    }
}

- (void)setPitchOverlap:(AudioUnitParameterValue)value {
    AudioUnit pitchUnit;
    OSStatus err = AUGraphNodeInfo(_auGraph, _pitchNode, NULL, &pitchUnit);
    AudioUnitSetParameter(pitchUnit, kNewTimePitchParam_Overlap, kAudioUnitScope_Global, 0, value, 0);
}

- (void)setPitchRate:(AudioUnitParameterValue)value {
    AudioUnit pitchUnit;
    OSStatus err = AUGraphNodeInfo(_auGraph, _pitchNode, NULL, &pitchUnit);
    AudioUnitSetParameter(pitchUnit, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, value, 0);
}

- (AudioUnitParameterValue)variSpeed
{
    AudioUnitParameterValue value = 0;
    
    AudioUnit variUnit;
    OSStatus err = AUGraphNodeInfo(_auGraph, _variSpeedNode, NULL, &variUnit);
    require_noerr(err, bail);
    
    err = AudioUnitGetParameter(variUnit, 1, kAudioUnitScope_Global, 0, &value);
    require_noerr(err, bail);
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
    
    return value;
}

- (Float32)currentPlayTime
{
    Float32 result = 0;
    OSStatus err = noErr;
    
    AudioUnit playerUnit;
    err = AUGraphNodeInfo(_auGraph, _playerNode, NULL, &playerUnit);
    require_noerr(err, bail);
    
    AudioTimeStamp timeStamp = {0};
    UInt32 size = sizeof(AudioTimeStamp);
    err = AudioUnitGetProperty(playerUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, &timeStamp, &size);
    require_noerr(err, bail);
    
    if (timeStamp.mFlags & kAudioTimeStampSampleTimeValid) {
        result = timeStamp.mSampleTime / _ioFormat.mSampleRate;
    }
    
    if (result < 0) {
        result = 0;
    }
    
bail:
    if (err) {
        NSLog(@"%s %ld", __FUNCTION__, err);
    }
    
    return result;
}

#pragma mark - File control

//- (void)createDestFile {
//    
//    AudioStreamBasicDescription dstFormat;
////    size = sizeof(dstFormat);
//    dstFormat.mSampleRate = 44100;//myInfo.mDataFormat.mSampleRate;
//    dstFormat.mChannelsPerFrame = 1;//myInfo.mDataFormat.mChannelsPerFrame;
//    dstFormat.mBitsPerChannel = 16;
//    dstFormat.mBytesPerFrame = 4;
//    dstFormat.mBytesPerPacket = 4;
//    dstFormat.mFramesPerPacket = 1;
//    dstFormat.mFormatID = kAudioFormatAppleIMA4;
//    
//    NSURL *url = [NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingPathComponent:@"recordedFile.caf"]];
//    CFURLRef urlRef = (__bridge CFURLRef) url;
//    
//    AudioChannelLayout layout;
//    memset(&layout, 0, sizeof(AudioChannelLayout));
//    layout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
//    
//   ExtAudioFileCreateWithURL(urlRef, kAudioFileCAFType, &dstFormat, &layout, kAudioFileFlags_EraseFile, &_destExtAudioFile);
//}
//
//OSStatus MyAURenderCallback(void *inRefCon,
//                            AudioUnitRenderActionFlags *actionFlags,
//                            const AudioTimeStamp *inTimeStamp,
//                            UInt32 inBusNumber,
//                            UInt32 inNumberFrames,
//                            AudioBufferList *ioData) {
//    OSStatus res = noErr;
//    ExtAudioFileRef file = (ExtAudioFileRef)inRefCon;
//    if (*actionFlags & kAudioUnitRenderAction_PostRender) {
//       res = ExtAudioFileWrite(file, inNumberFrames, ioData);
//    }
//    return res;
//}

@end
