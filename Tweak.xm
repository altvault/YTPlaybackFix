#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface YTSingleVideoController : NSObject
@property (nonatomic, weak, readonly) id delegate;
@end

@interface YTLocalPlaybackController : NSObject
- (id)parentResponder;
@end

@interface MLHAMQueuePlayer : NSObject
@property (nonatomic, weak, readonly) id delegate;
@end

@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (instancetype)eventWithFirstResponder:(id)firstResponder;
- (void)send;
@end

%hook MLHAMQueuePlayer

- (void)internalSetRate
{
    %orig;

    NSLog(@"[YTPlaybackFix] internalSetRate");
}

- (void)maybeSwitchToAVPlayer
{
    %orig;

    NSLog(@"[YTPlaybackFix] maybeSwitchToAVPlayer");

    id video = self.delegate;

    if (![video respondsToSelector:@selector(delegate)])
        return;

    id playback = [video delegate];

    if (![playback respondsToSelector:@selector(parentResponder)])
        return;

    id responder = [playback parentResponder];

    if (!responder)
        return;

    [[objc_getClass("YTPlayerTapToRetryResponderEvent")
        eventWithFirstResponder:responder]
        send];
}

%end
