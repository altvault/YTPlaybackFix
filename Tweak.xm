#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MLHAMQueuePlayer : NSObject
@property(nonatomic, weak) id delegate;
@end

@interface YTSingleVideoController : NSObject
@property(nonatomic, weak) id delegate;
@end

@interface YTLocalPlaybackController : NSObject
- (id)parentResponder;
@end

@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (instancetype)eventWithFirstResponder:(id)firstResponder;
- (void)send;
@end

static NSTimer *gTimer = nil;
static __weak MLHAMQueuePlayer *gPlayer = nil;

%hook MLHAMQueuePlayer

- (void)internalSetRate:(float)rate
{
    %orig;

    gPlayer = self;

    if (rate > 0.0 && !gTimer)
    {
        gTimer =
        [NSTimer scheduledTimerWithTimeInterval:25.0
                                        repeats:YES
                                          block:^(NSTimer *timer)
        {
            if (!gPlayer)
                return;

            YTSingleVideoController *video =
                (YTSingleVideoController *)gPlayer.delegate;

            if (!video)
                return;

            YTLocalPlaybackController *playback =
                (YTLocalPlaybackController *)video.delegate;

            if (!playback)
                return;

            id responder = [playback parentResponder];

            if (!responder)
                return;

            [[[objc_getClass("YTPlayerTapToRetryResponderEvent")
                eventWithFirstResponder:responder]
                send];
        }];
    }
}

%end
