#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (id)eventWithFirstResponder:(id)arg1;
- (void)send;
@end

@interface YTPlayerViewController : UIViewController
- (CGFloat)currentVideoMediaTime;
- (void)seekToTime:(CGFloat)time;
@end

@interface YTMainAppVideoPlayerOverlayViewController : UIViewController
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

static NSTimeInterval gLastRetry = 0;

%hook YTMainAppVideoPlayerOverlayViewController

- (void)handleError:(NSError *)error
{
    if (error &&
        [error.domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] &&
        error.code == 14)
    {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

        if (now - gLastRetry < 3.0) {
            return;
        }

        gLastRetry = now;

        YTPlayerViewController *pvc = nil;

        @try {
            pvc = [self parentViewController];
        } @catch (...) {}

        CGFloat oldTime = 0.0;

        if (pvc) {
            @try {
                oldTime = [pvc currentVideoMediaTime];
            } @catch (...) {}
        }

        id responder = nil;

        if ([self respondsToSelector:@selector(parentResponder)]) {
            @try {
                responder = [self performSelector:@selector(parentResponder)];
            } @catch (...) {}
        }

        if (responder) {
            id event =
                [%c(YTPlayerTapToRetryResponderEvent)
                    eventWithFirstResponder:responder];

            if (event) {
                [event send];
            }
        }

        if (pvc) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                           (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{

                @try {
                    [pvc seekToTime:oldTime];
                } @catch (...) {}

            });
        }

        return;
    }

    %orig;
}

%end
