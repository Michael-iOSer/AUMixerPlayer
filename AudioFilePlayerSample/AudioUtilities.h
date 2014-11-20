//
//  AudioUtilities.h
//  AudioUnitTest
//
//  Created by DongYi on 14-11-19.
//  Copyright 2011 Yuki Yasoshima. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>


#define require_noerr(errorCode, exceptionLabel)           \
    do  {                                                  \
            if ( __builtin_expect(0 != (errorCode), 0) )   \
        {                                                  \
            goto exceptionLabel;                           \
        }                                                  \
    } while ( 0 )


void GetEffectFormat(AudioStreamBasicDescription *format);