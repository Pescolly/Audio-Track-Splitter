//
//  main.m
//  AudioTrackSplitter
//
//  Created by Armen Karamian on 1/28/16.
//  Copyright © 2016 Armen Karamian. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

Byte *createWavHeader(UInt16 channels, UInt16 bitDepth, UInt32 sampleRate, UInt32 fileSize);
int HEADER_SIZE = 44;

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSString *testFile = @"/Users/akaramian/Desktop/testfiles/catinthehatSnip.mov";///Users/akaramian/Desktop/testfiles/HOUSE_OF_CARDS_101_es-ES_DiscreteMultipleTracks.mov";
        NSString *testFileOutput = @"/Users/akaramian/Desktop/testfiles/catinthehatSnipSurround.wav";
        NSURL *testfileURL = [NSURL fileURLWithPath:testFile];
        
        //setup source
        AVURLAsset *sourceAsset = [[AVURLAsset alloc] initWithURL:testfileURL options:nil];
        NSArray<AVAssetTrack *> *tracks = [sourceAsset tracksWithMediaType:AVMediaTypeAudio];
        
        //create new file name
        NSURL *surroundExportfile = [NSURL fileURLWithPath:testFileOutput];//[testFile stringByAppendingString:@"surround.wav"]];
   
        int TRACK_COUNT = tracks.count;
        int SAMPLE_SIZE = 24;
       
        
        if (TRACK_COUNT == 8)
        {
            //            setup output assets
            NSLog(@"5.1 + Stereo");
            
            
            //create 5.1 comp and export
            NSMutableData *channel0Data = [NSMutableData data];
            NSMutableData *channel1Data = [NSMutableData data];
            NSMutableData *channel2Data = [NSMutableData data];
            NSMutableData *channel3Data = [NSMutableData data];
            NSMutableData *channel4Data = [NSMutableData data];
            NSMutableData *channel5Data = [NSMutableData data];

            NSArray<NSMutableData *> *dataArray = [NSArray arrayWithObjects:channel0Data, channel1Data, channel2Data, channel3Data, channel4Data, channel5Data, nil];
            //get sample data
            for (int i = 0; i < 6; i++)
            {
                NSLog(@"Get track %d",i);
                AVAssetTrack *currentTrack = tracks[i];
                
                //create reader and output for track
                AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:sourceAsset error:nil];
                AVAssetReaderOutput *trackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:currentTrack outputSettings:nil];
                if ([assetReader canAddOutput:trackOutput])
                {
                    [assetReader addOutput:trackOutput];
                    [assetReader startReading];
                    
                    while (assetReader.status == AVAssetReaderStatusReading)
                    {
                        //get sample buffer
                        CMSampleBufferRef sampleBuffer = [trackOutput copyNextSampleBuffer];
                        if (sampleBuffer)
                        {
                            //copy to new file
                            CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                            size_t blockBufferSize = CMBlockBufferGetDataLength(blockBuffer);
                            SInt16 sampleBytes[blockBufferSize];
                            
                            CMBlockBufferCopyDataBytes(blockBuffer, 0, blockBufferSize, sampleBytes);
                            
                            NSMutableData *data = [dataArray  objectAtIndex:i];
                            [data appendBytes:sampleBytes length:blockBufferSize];
                            
                            CMSampleBufferInvalidate(sampleBuffer);
                            CFRelease(sampleBuffer);
                            
                        }
                    }
                }
            }

            
            
            //setup file output
            NSFileManager *outputFileManager = [NSFileManager defaultManager];
            if ([outputFileManager fileExistsAtPath:testFileOutput] == false)
            {
                [outputFileManager createFileAtPath:testFileOutput contents:nil attributes:nil];
            }
            
            NSError *err;
            NSFileHandle *surroundFile = [NSFileHandle fileHandleForWritingToURL:surroundExportfile error:&err];
            //write file header
            if (surroundFile == nil)
            {
                NSLog(@"Could not create output file URL:\n %@", surroundExportfile);
                exit(1);
            }
            
            //get data size
            int16_t *channel0 = (int16_t*)[channel0Data bytes];
            int16_t *channel1 = (int16_t*)[channel1Data bytes];
            int16_t *channel2 = (int16_t*)[channel2Data bytes];
            int16_t *channel3 = (int16_t*)[channel3Data bytes];
            int16_t *channel4 = (int16_t*)[channel4Data bytes];
            int16_t *channel5 = (int16_t*)[channel5Data bytes];
            
            //create wav header
            UInt32 datasize = (uint32)[channel0Data length] * TRACK_COUNT;
            
            Byte* header = createWavHeader(6, 24, 48000, datasize);
            
            //write header to file
            NSData *headerData = [NSData dataWithBytes:header length:HEADER_SIZE];
            [surroundFile writeData:headerData];
            
            //write sample data to a file
            int counter = 0;
            while(1)
            {
                Byte packet[18];
                packet[0] = channel0[counter];
                packet[1] = channel0[counter];
                packet[2] = channel0[counter];
                
                packet[3] = channel1[counter];
                packet[4] = channel1[counter];
                packet[5] = channel1[counter];
                
                packet[6] = channel2[counter];
                packet[7] = channel2[counter];
                packet[8] = channel2[counter];
                
                packet[9] = channel3[counter];
                packet[10] = channel3[counter];
                packet[11] = channel3[counter];
                
                packet[12] = channel4[counter];
                packet[13] = channel4[counter];
                packet[14] = channel4[counter];
                
                packet[15] = channel5[counter];
                packet[16] = channel5[counter];
                packet[17] = channel5[counter];
                
                
//                NSLog(@"data length: %lu",(unsigned long)[channel0Data length]);
                if (counter == ( [channel0Data length] / 2) )
                    break;

                [surroundFile seekToFileOffset:((counter * TRACK_COUNT) * 3) + HEADER_SIZE];
                NSData *dataToWrite = [NSData dataWithBytes:packet length:sizeof(packet)];
                
                [surroundFile writeData:dataToWrite];
                
                counter++;
            }
            
            [surroundFile closeFile];
            
            NSLog(@"data collected");
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

Byte *createWavHeader(UInt16 channels, UInt16 bitDepth, UInt32 sampleRate, UInt32 fileSize)
{
    int RIFF_HEADER_SIZE = 8;
    
    Byte header[44];
    char riffField[4] = {'R','I','F','F'};
    memcpy(&header[0], riffField, sizeof(riffField));
 
    UInt32 riffChunkSize = fileSize + HEADER_SIZE - RIFF_HEADER_SIZE;
    memcpy(&header[4], &riffChunkSize, sizeof(UInt32));
    
    char waveField[4] = {'W','A','V','E'};
    memcpy(&header[8], waveField, sizeof(waveField));
    
    char fmt[4] = {'f','m','t', ' '};
    memcpy(&header[12], fmt, sizeof(fmt));
           
    Byte chunkSize[4] = {16, 0, 0, 0};
    memcpy(&header[16], chunkSize, sizeof(chunkSize));
    
    UInt16 formatType = 1;
    memcpy(&header[20], &formatType, sizeof(formatType));

    memcpy(&header[22], &channels, sizeof(channels));
    
    memcpy(&header[24], &sampleRate, sizeof(sampleRate));
    
    UInt32 bitRate = (sampleRate * bitDepth * channels) / 8;
    memcpy(&header[28], &bitRate, sizeof(bitRate));
    
    memcpy(&header[34], &bitDepth, sizeof(bitDepth));
    
    char data[4] = {'d','a','t','a'};
    memcpy(&header[36], &data, sizeof(data));
    
    memcpy(&header[40], & fileSize, sizeof(fileSize));
    
    Byte *retHeader = malloc(44);
    memcpy(retHeader, header, 44);
    return retHeader;
}
