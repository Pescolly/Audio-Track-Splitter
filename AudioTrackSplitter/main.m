//
//  main.m
//  AudioTrackSplitter
//
//  Created by Armen Karamian on 1/28/16.
//  Copyright © 2016 Armen Karamian. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSString *testFile = @"/Users/akaramian/Desktop/catinthehat.mov";
        NSURL *testfileURL = [NSURL fileURLWithPath:testFile];
        
        
        AVURLAsset *sourceFile = [[AVURLAsset alloc] initWithURL:testfileURL options:nil];
        NSArray<AVAssetTrack *> *tracks = [sourceFile tracksWithMediaType:AVMediaTypeAudio];
        
        if (tracks.count == 8)
        {
            NSLog(@"5.1 + Stereo");
//            AVAsset *surroundAsset = [[AVAsset alloc] init];
  //          AVAsset *stereoAsset = [[AVAsset alloc] init];

            AVMutableComposition *surroundComposition = [[AVMutableComposition alloc] init];
            AVMutableComposition *stereoComposition = [[AVMutableComposition alloc] init];
            
            //create 5.1 comp and export
            for (int i = 0; i < 6; i++)
            {
                AVAssetTrack *currentTrack = tracks[i];
                AVMutableCompositionTrack *compTrack = [surroundComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                CMTimeRange timeRange = currentTrack.timeRange;
                [compTrack insertTimeRange:timeRange ofTrack:currentTrack atTime:kCMTimeZero error:nil];
                
                NSLog(@"test");
            }
            NSLog(@"5.1 composition created");
            NSLog(@"tracks: %@", surroundComposition.tracks);
        
            //create new file name
            NSURL *surroundExportfile = [NSURL fileURLWithPath:[testFile stringByAppendingString:@"surround.mov"]];
            //create stereo comp and export
            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:surroundComposition presetName:AVAssetExportPresetPassthrough];
            
            dispatch_queue_t exportQ = dispatch_queue_create("exportQueue", DISPATCH_QUEUE_CONCURRENT);
            
            exportSession.outputFileType = AVFileTypeQuickTimeMovie;
            exportSession.outputURL = surroundExportfile;
            exportSession.shouldOptimizeForNetworkUse = false;
            
            CMTimeValue val = surroundComposition.duration.value;
            CMTime duration = CMTimeMake(val, surroundComposition.duration.timescale);
            exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
            
            dispatch_semaphore_t semaphores[1];
            dispatch_semaphore_t surroundSemaphore = dispatch_semaphore_create(0);
            semaphores[0] = surroundSemaphore;
            
            
            [exportSession exportAsynchronouslyWithCompletionHandler:^{
                switch ([exportSession status])
                {
                    case AVAssetExportSessionStatusFailed:
                    {
                        NSLog(@"Failed");
                        NSLog(@"%@", exportSession.error.localizedDescription);
                        NSLog(@"%@", exportSession.error.localizedFailureReason);
                        break;
                    }
                    case AVAssetExportSessionStatusCompleted:
                    {
                        NSLog(@"Completed");
                        dispatch_semaphore_signal(surroundSemaphore);
                    }
                    default:
                        break;
                }
            }];
            
            dispatch_semaphore_wait(surroundSemaphore, DISPATCH_TIME_FOREVER);
        }
        else if (tracks.count == 2)
        {
            NSLog(@"Stereo");
        }
        else
        {
            NSLog(@"unspecified audio configuration");
        }
        
    }
    return 0;
}
