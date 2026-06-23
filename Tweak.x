#import <UIKit/UIKit.h>
#import <objc/message.h>

// Punti di ancoraggio deboli per seguire i moduli di YouTube in memoria
static __weak id sharedPlaybackController = nil;
static __weak id sharedPlayerViewController = nil;
static double lastKnownTime = 0.0;
static BOOL IsFixingRightNow = NO;

// --- TRACCIAMENTO IN LINEA ---
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


// --- INTERCETTAZIONE DI BASSO LIVELLO (CORE ERROR) ---
%hook NSError

- (id)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict {
    // Se il sistema sta creando esattamente l'errore 14 che hai incollato
    if ([domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] && code == 14) {
        NSLog(@"[YTPlaybackFix] 🎯 ERROR 14 INTERCETTATO ALLA RADICE!");
        
        if (!IsFixingRightNow) {
            IsFixingRightNow = YES;
            
            // Avviamo il ripristino rapido sul thread principale
            dispatch_async(dispatch_get_main_queue(), ^{
                double targetTime = lastKnownTime;
                
                // Recuperiamo il millisecondo esatto pre-blocco
                if (sharedPlayerViewController && [sharedPlayerViewController respondsToSelector:@selector(currentTime)]) {
                    double cTime = ((double (*)(id, SEL))objc_msgSend)(sharedPlayerViewController, @selector(currentTime));
                    if (cTime > 0.1) targetTime = cTime;
                }
                
                NSLog(@"[YTPlaybackFix] Forzo il riavvio immediato dello stream al secondo: %.2f", targetTime);
                
                BOOL didRetry = NO;
                
                // Proviamo a dare il comando di recupero (Forza il frame nero veloce come YTKillerPlus)
                if (sharedPlaybackController) {
                    if ([sharedPlaybackController respondsToSelector:@selector(retry)]) {
                        ((void (*)(id, SEL))objc_msgSend)(sharedPlaybackController, @selector(retry));
                        didRetry = YES;
                    } else if ([sharedPlaybackController respondsToSelector:@selector(reload)]) {
                        ((void (*)(id, SEL))objc_msgSend)(sharedPlaybackController, @selector(reload));
                        didRetry = YES;
                    }
                }
                
                if (sharedPlayerViewController && !didRetry) {
                    if ([sharedPlayerViewController respondsToSelector:@selector(retryPlayback)]) {
                        ((void (*)(id, SEL))objc_msgSend)(sharedPlayerViewController, @selector(retryPlayback));
                    } else if ([sharedPlayerViewController respondsToSelector:@selector(reload)]) {
                        ((void (*)(id, SEL))objc_msgSend)(sharedPlayerViewController, @selector(reload));
                    }
                }
                
                // Ripristiniamo la barra del tempo dopo una frazione di secondo per stabilizzare il buffer
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
        
        // Mossa fondamentale: restituiamo a YouTube un errore modificato con codice 0 e senza dati di blocco.
        // In questo modo l'app non mostrerà MAI la schermata "Si è verificato un problema".
        return %orig(@"com.google.ios.youtube.ErrorDomain.playback", 0, nil);
    }
    return %orig;
}

%end

__attribute__((constructor)) static void initYTUltimateLowLevelFix() {
    NSLog(@"[YTPlaybackFix] Sistema anti-Errore 14 pronto a intercettare.");
}
