#import <UIKit/UIKit.h>
#import <objc/message.h>

static __weak id sharedPlaybackController = nil;
static __weak id sharedPlayerViewController = nil;
static double lastKnownTime = 0.0;
static BOOL IsFixingRightNow = NO;

// --- SEGUIMENTO DEI MODULI DI YOUTUBE ---
%hook YTPlaybackController

- (id)init {
    id instance = %orig;
    sharedPlaybackController = instance;
    return instance;
}

- (void)play {
    sharedPlaybackController = self;
    %orig;
}

- (void)setCurrentTime:(double)time {
    if (!IsFixingRightNow && time > 0.1) {
        lastKnownTime = time;
    }
    %orig;
}

%end

%hook YTPlayerViewController

- (id)init {
    id instance = %orig;
    sharedPlayerViewController = instance;
    return instance;
}

- (void)viewWillAppear:(BOOL)animated {
    sharedPlayerViewController = self;
    %orig;
}

- (void)setCurrentTime:(double)time {
    if (!IsFixingRightNow && time > 0.1) {
        lastKnownTime = time;
    }
    %orig;
}

%end

// --- SOLUZIONE AUTOMATICA ERRORE 14 ---
%hook NSError

- (id)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict {
    if ([domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] && code == 14) {
        
        if (!IsFixingRightNow) {
            IsFixingRightNow = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                __block double targetTime = lastKnownTime;
                
                // Tenta di recuperare il secondo esatto dal player
                if (sharedPlayerViewController && [sharedPlayerViewController respondsToSelector:@selector(currentTime)]) {
                    double cTime = ((double (*)(id, SEL))objc_msgSend)(sharedPlayerViewController, @selector(currentTime));
                    if (cTime > 0.1) targetTime = cTime;
                }
                
                // Eseguiamo il refresh simulando l'azione del tasto overlay
                BOOL didReload = NO;
                if (sharedPlaybackController) {
                    if ([sharedPlaybackController respondsToSelector:@selector(retry)]) {
                        ((void (*)(id, SEL))objc_msgSend)(sharedPlaybackController, @selector(retry));
                        didReload = YES;
                    } else if ([sharedPlaybackController respondsToSelector:@selector(reload)]) {
                        ((void (*)(id, SEL))objc_msgSend)(sharedPlaybackController, @selector(reload));
                        didReload = YES;
                    }
                }
                
                if (sharedPlayerViewController && !didReload) {
                    if ([sharedPlayerViewController respondsToSelector:@selector(retryPlayback)]) {
                        ((void (*)(id, SEL))objc_msgSend)(sharedPlayerViewController, @selector(retryPlayback));
                    }
                }
                
                // Riposiziona la barra temporale dopo il micro-refresh del chunk
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (targetTime > 0.1) {
                        if (sharedPlayerViewController && [sharedPlayerViewController respondsToSelector:@selector(seekToTime:)]) {
                            ((void (*)(id, SEL, double))objc_msgSend)(sharedPlayerViewController, @selector(seekToTime:), targetTime);
                        } else if (sharedPlaybackController && [sharedPlaybackController respondsToSelector:@selector(seekToTime:)]) {
                            ((void (*)(id, SEL, double))objc_msgSend)(sharedPlaybackController, @selector(seekToTime:), targetTime);
                        }
                    }
                    IsFixingRightNow = NO;
                });
            });
        }
        // Ritorniamo un errore nullo per distruggere l'interfaccia di blocco
        return nil;
    }
    return %orig;
}

%end
