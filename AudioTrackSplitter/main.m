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
        //fetch args
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        if ([args count] < 3)
        {
            NSLog(@" Add a file to process and a destination");
            exit(1);
        }
        NSString *incomingFilepath = args[1];
        NSString *destination = args[2];
        NSURL *incomingURL = [NSURL fileURLWithPath:incomingFilepath];
        NSString *incomingFilename = [[incomingURL lastPathComponent] stringByDeletingPathExtension];
        NSString *destinationFullPathFilename = [destination stringByAppendingPathComponent:incomingFilename];
 //       NSString *testFile
   //     NSURL *testfileURL = [NSURL fileURLWithPath:testFile];
        
        //setup sourcefile and asset
        AVURLAsset *sourceFile = [[AVURLAsset alloc] initWithURL:incomingURL options:nil];
        NSArray<AVAssetTrack *> *tracks = [sourceFile tracksWithMediaType:AVMediaTypeAudio];
        
        //setup export files
        NSURL *surroundExportfile = [NSURL fileURLWithPath:[destinationFullPathFilename stringByAppendingString:@"_SURROUND.mov"]];
        NSURL *stereoExportfile = [NSURL fileURLWithPath:[destinationFullPathFilename stringByAppendingString:@"_STEREO.mov"]];

        //check if export files exist
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[surroundExportfile path]])
        {
            NSLog(@"File %@ already exists", [surroundExportfile path]);
            exit(999);
        }

        if ([[NSFileManager defaultManager] fileExistsAtPath:[stereoExportfile path]])
        {
            NSLog(@"File %@ already exists", [stereoExportfile path]);
            exit(999);
        }

        
        if (tracks.count == 8)
        {
            AVMutableComposition *surroundComposition = [[AVMutableComposition alloc] init];
            //create semaphore array
            dispatch_semaphore_t semaphores[2];
        
            //create 5.1 comp and export
            for (int i = 0; i < 6; i++)
            {
                AVAssetTrack *currentTrack = tracks[i];
                AVMutableCompositionTrack *compTrack = [surroundComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                CMTimeRange timeRange = currentTrack.timeRange;
                [compTrack insertTimeRange:timeRange ofTrack:currentTrack atTime:kCMTimeZero error:nil];
            }
            
            //create stereo comp and export
            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:surroundComposition presetName:AVAssetExportPresetPassthrough];
            
            exportSession.outputFileType = AVFileTypeQuickTimeMovie;
            exportSession.outputURL = surroundExportfile;
            exportSession.shouldOptimizeForNetworkUse = false;
            
            CMTimeValue val = surroundComposition.duration.value;
            CMTime duration = CMTimeMake(val, surroundComposition.duration.timescale);
            exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
            
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
                        NSLog(@"Surround Completed");
                        dispatch_semaphore_signal(surroundSemaphore);
                    }
                    default:
                        break;
                }
            }];
            
            dispatch_semaphore_wait(surroundSemaphore, DISPATCH_TIME_FOREVER);

            
            //create stero output
            AVMutableComposition *stereoComposition = [[AVMutableComposition alloc] init];
            for (int i = 6; i < 8; i++)
            {
                AVAssetTrack *currentTrack = tracks[i];
                AVMutableCompositionTrack *compTrack = [stereoComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                CMTimeRange timeRange = currentTrack.timeRange;
                [compTrack insertTimeRange:timeRange ofTrack:currentTrack atTime:kCMTimeZero error:nil];
            }
            //create stereo comp and export
            AVAssetExportSession *stereoExportSession = [[AVAssetExportSession alloc] initWithAsset:stereoComposition presetName:AVAssetExportPresetPassthrough];
            
            stereoExportSession.outputFileType = AVFileTypeQuickTimeMovie;
            stereoExportSession.outputURL = stereoExportfile;
            stereoExportSession.shouldOptimizeForNetworkUse = false;
            
            val = stereoComposition.duration.value;
            duration = CMTimeMake(val, stereoComposition.duration.timescale);
            stereoExportSession.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
            
            dispatch_semaphore_t stereoSemaphore = dispatch_semaphore_create(0);
            semaphores[1] = stereoSemaphore;
            
            
            [stereoExportSession exportAsynchronouslyWithCompletionHandler:^{
                switch ([exportSession status])
                {
                    case AVAssetExportSessionStatusFailed:
                    {
                        NSLog(@"Failed");
                        NSLog(@"%@", stereoExportSession.error.localizedDescription);
                        NSLog(@"%@", stereoExportSession.error.localizedFailureReason);
                        break;
                    }
                    case AVAssetExportSessionStatusCompleted:
                    {
                        NSLog(@"Stereo Completed");
                        dispatch_semaphore_signal(stereoSemaphore);
                    }
                    default:
                        break;
                }
            }];
            
            dispatch_semaphore_wait(stereoSemaphore, DISPATCH_TIME_FOREVER);
        }
        else if (tracks.count == 2)
        {

            NSLog(@"MOV is already a stereo file. Skipping");
            exit(888);
        }
        else
        {
            NSLog(@"unspecified audio configuration");
        }
        
    }
    return 0;
}
