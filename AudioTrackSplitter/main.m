//
//  main.m
//  AudioTrackSplitter
//
//  Created by Armen Karamian on 1/28/16.
//  Copyright © 2016 Armen Karamian. All rights reserved.
//	application to create multiple audio stems from an MOV

#import <Foundation/Foundation.h>
@import AVFoundation;

int main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		NSLog(@"Audio Stem Creation Starting Now");
		//fetch args
		NSArray *args = [[NSProcessInfo processInfo] arguments];
		if ([args count] < 2)
		{
			NSLog(@" Add a file to process");
			exit(1);
		}
		//get the incoming path and destination and create a URL for incoming
		NSString *incomingFilepath = args[1];
		NSURL *incomingURL = [NSURL fileURLWithPath:incomingFilepath];
		
		//get the filename and create a path at the destination
		NSString *incoming_Directory = [[incomingURL path] stringByDeletingLastPathComponent];
		NSString *incoming_Filename = [[incomingURL lastPathComponent] stringByDeletingPathExtension];
		
		//setup sourcefile and asset
		AVURLAsset *sourceFile = [[AVURLAsset alloc] initWithURL:incomingURL options:nil];
		NSArray<AVAssetTrack *> *tracks = [sourceFile tracksWithMediaType:AVMediaTypeAudio];
		
		NSArray<NSString *> *STEM_LABELS = @[@"_L",@"_R",@"_C",@"_LFE",@"_LS",@"_RS",@"_LT",@"_RT",@"_LMnE",@"_RMnE"];
		
		//setup export URL and create folder if it does not exist
		NSString *trackExportDestination = [incoming_Directory stringByAppendingPathComponent:@"AudioStems"];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if (![fileManager fileExistsAtPath:trackExportDestination])
		{
			[fileManager createDirectoryAtPath:trackExportDestination withIntermediateDirectories:true attributes:nil error:nil];
		}
		
		NSUInteger trackCount = tracks.count;
		dispatch_group_t trackGroup = dispatch_group_create();
		dispatch_queue_t trackQ = dispatch_queue_create("com.mvf.trackexportq", DISPATCH_QUEUE_CONCURRENT);
		
		//create 5.1 comp and export
		for (int i = 0; i < trackCount; i++)
		{
			//assign each track to a async thread in the track export dispatch group.
			dispatch_group_async(trackGroup, trackQ, ^{
				AVAssetTrack *currentTrack = tracks[i];
				CMTimeRange timeRange = currentTrack.timeRange;
				
				//create mono tracks for the 5.1
				if (i < 6)
				{
					
					//get track and setup composition
					AVMutableComposition *monoTrackComposition = [[AVMutableComposition alloc] init];
					AVMutableCompositionTrack *compTrack = [monoTrackComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
					[compTrack insertTimeRange:timeRange ofTrack:currentTrack atTime:kCMTimeZero error:nil];
					
					//create file xport url
					NSString *exportFilename = [[trackExportDestination stringByAppendingPathComponent:[incoming_Filename stringByAppendingString:STEM_LABELS[i]]] stringByAppendingPathExtension:@"wav"];
					NSURL *exportFile = [[NSURL alloc] initFileURLWithPath:exportFilename];
					if([fileManager fileExistsAtPath:exportFilename])
					{
						NSLog(@"File %@ already exists", exportFilename);
						exit(1);
					}
					
					//create composition export session
					AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:monoTrackComposition presetName:AVAssetExportPresetPassthrough];
					exportSession.outputFileType = AVFileTypeWAVE;
					exportSession.outputURL = exportFile;
					exportSession.shouldOptimizeForNetworkUse = false;
					CMTimeValue val = monoTrackComposition.duration.value;
					CMTime duration = CMTimeMake(val, monoTrackComposition.duration.timescale);
					exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
					
					NSLog(@"Exporting to %@", exportFile);
					//export and signal semaphore when async export is complete on this thread
					dispatch_semaphore_t exportDone = dispatch_semaphore_create(0);
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
								NSLog(@"Track %@ Completed", STEM_LABELS[i]);
								dispatch_semaphore_signal(exportDone);
							}
							default:
								break;
						}
					}];
					dispatch_semaphore_wait(exportDone, DISPATCH_TIME_FOREVER);
					
					
				}
				//create stereo tracks for lt/rt and mne
				if (i == 6 || i == 8)
				{
					//get stereo pair track
					AVAssetTrack *matchingTrack = tracks[i+1];
					CMTimeRange matchingTrackTimeRange = matchingTrack.timeRange;
					
					//create stereo comp
					AVMutableComposition *stereoComposition = [[AVMutableComposition alloc] init];
					AVMutableCompositionTrack *stereoTrackComp = [stereoComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
					[stereoTrackComp insertTimeRange:timeRange ofTrack:currentTrack atTime:kCMTimeZero error:nil];
					[stereoTrackComp insertTimeRange:matchingTrackTimeRange ofTrack:matchingTrack atTime:kCMTimeZero error:nil];
					
					//create file xport url
					NSString *stereoPairExportName = [STEM_LABELS[i] stringByAppendingString:STEM_LABELS[i+1]];
					NSString *exportFilename = [[trackExportDestination stringByAppendingPathComponent:[incoming_Filename stringByAppendingString:stereoPairExportName]] stringByAppendingPathExtension:@"wav"];
					NSURL *stereoExportFile = [[NSURL alloc] initFileURLWithPath:exportFilename];
					if([fileManager fileExistsAtPath:exportFilename])
					{
						NSLog(@"File %@ already exists", exportFilename);
						exit(1);
					}
					
					//create export session
					AVAssetExportSession *stereoExportSession = [[AVAssetExportSession alloc] initWithAsset:stereoComposition presetName:AVAssetExportPresetPassthrough];
					stereoExportSession.outputFileType = AVFileTypeWAVE;
					stereoExportSession.outputURL = stereoExportFile;
					stereoExportSession.shouldOptimizeForNetworkUse = false;
					CMTimeValue val = stereoComposition.duration.value;
					CMTime duration = CMTimeMake(val, stereoComposition.duration.timescale);
					stereoExportSession.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
					
					//create semaphore for export session and start export
					NSLog(@"Exporting to %@", stereoExportFile);
					dispatch_semaphore_t exportDone = dispatch_semaphore_create(0);
					[stereoExportSession exportAsynchronouslyWithCompletionHandler:^{
						switch ([stereoExportSession status])
						{
							case AVAssetExportSessionStatusFailed:
							{
								NSLog(@"Failed");
								NSLog(@"%@", stereoExportSession.error.localizedDescription);
								NSLog(@"%@", stereoExportSession.error.localizedFailureReason);
								dispatch_semaphore_signal(exportDone);
							}
							case AVAssetExportSessionStatusCompleted:
							{
								NSLog(@"Stereo Completed");
								dispatch_semaphore_signal(exportDone);
							}
							default:
								dispatch_semaphore_signal(exportDone);
						}
					}];
					dispatch_semaphore_wait(exportDone, DISPATCH_TIME_FOREVER);
				}
			});
		}
		dispatch_group_wait(trackGroup, DISPATCH_TIME_FOREVER);
	}
	NSLog(@"Done");
	return 0;
}
