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
        NSString *testFile = @"/Users/akaramian/Desktop/testfiles/catinthehat.mov";///Users/akaramian/Desktop/testfiles/HOUSE_OF_CARDS_101_es-ES_DiscreteMultipleTracks.mov";
        NSURL *testfileURL = [NSURL fileURLWithPath:testFile];
        
        //setup source
        AVURLAsset *sourceAsset = [[AVURLAsset alloc] initWithURL:testfileURL options:nil];
        NSArray<AVAssetTrack *> *tracks = [sourceAsset tracksWithMediaType:AVMediaTypeAudio];
        
        //create new file name
        NSURL *surroundExportfile = [NSURL fileURLWithPath:[testFile stringByAppendingString:@"surround.mov"]];

        //setup reader
        AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:sourceAsset error:nil];

        //setup asset writer
        AVAssetWriter *assetWriter = [[AVAssetWriter alloc] initWithURL:surroundExportfile fileType:AVFileTypeWAVE error:nil];
        AudioChannelLayout surroundLayout = {
            .mChannelLayoutTag = kAudioChannelLayoutTag_AudioUnit_5_1,
            .mChannelBitmap = 0,
            .mNumberChannelDescriptions = 0
        };
        
        
        if (tracks.count == 8)
        {
//            setup output assets
            NSLog(@"5.1 + Stereo");

            
            //create 5.1 comp and export
            for (int i = 0; i < 6; i++)
            {
                AVAssetTrack *currentTrack = tracks[i];
                
                //create output for track
                AVAssetReaderOutput *trackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:currentTrack outputSettings:nil];
                if ([assetReader canAddOutput:trackOutput])
                {
                    [assetReader addOutput:trackOutput];
                }

                //create writer for track
                NSDictionary *writerSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                                [NSNumber numberWithFloat:48000], AVSampleRateKey,
                                                [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
                                               nil];
                
                AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:nil];
                if ([assetWriter canAddInput:writerInput])
                {
                    [assetWriter addInput:writerInput];
                    [assetReader startReading];
                    [assetWriter startWriting];
                    [assetWriter startSessionAtSourceTime:kCMTimeZero];
                    
                    dispatch_queue_t q = dispatch_queue_create("com.mvf.wavMaker", NULL);
                    
                    [writerInput requestMediaDataWhenReadyOnQueue:q usingBlock:^{
                        while (assetReader.status == AVAssetReaderStatusReading)
                        {
                            //get sample buffer
                            CMSampleBufferRef sampleBuffer = [trackOutput copyNextSampleBuffer];
                            if (sampleBuffer)
                            {
                                //copy to new file
                                [writerInput appendSampleBuffer:sampleBuffer];
                                
                                
                                //release buffer and continue
                                CFRelease(sampleBuffer);
                                
                            }
                            else
                            {
                                [writerInput markAsFinished];
                            }
                        }
                    }];

                }
                else
                {
                    NSLog(@"Cannot add writer input");
                    NSLog(@"%@", assetWriter.error);
                }
                
            }

        
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
