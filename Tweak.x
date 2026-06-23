#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Dichiarazione delle interfacce necessarie di YouTube per consentire la compilazione senza errori
@interface YTWatchViewController : UIViewController
- (id)currentVideoID;
- (void)playVideoWithID:(id)videoID;
@end

@interface YTPlayerViewController : UIViewController
- (void)retryPlayback;
@end

%hook YTPlayerViewController

- (void)showPlaybackError:(NSError *)error {
    // Verifichiamo se l'errore appartiene al dominio di riproduzione YouTube ed è il codice 14
    if ([error.domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] && error.code == 14) {
        
        NSLog(@"[YTPlaybackFix] Rilevato Errore 14 (Si è verificato un problema). Avvio ricaricamento automatico...");
        
        // Tentativo 1: Esegue il retry nativo (equivalente a premere nuovamente Play)
        if ([self respondsToSelector:@selector(retryPlayback)]) {
            [self retryPlayback];
            NSLog(@"[YTPlaybackFix] Eseguito retryPlayback sul player.");
        } else {
            // Tentativo 2: Forza la re-inizializzazione del video risalendo al controller della vista
            UIResponder *responder = self;
            while (responder && ![responder isKindOfClass:%c(YTWatchViewController)]) {
                responder = [responder nextResponder];
            }
            
            if (responder) {
                YTWatchViewController *watchVC = (YTWatchViewController *)responder;
                id currentID = [watchVC currentVideoID];
                
                if (currentID) {
                    NSLog(@"[YTPlaybackFix] Ricarico forzatamente il video con ID: %@", currentID);
                    [watchVC playVideoWithID:currentID];
                }
            }
        }
        
        // Interrompiamo l'esecuzione originale per evitare che compaia il popup nero di errore a schermo
        return;
    }

    // Per qualsiasi altro tipo di errore, lasciamo che l'applicazione si comporti normalmente
    %orig;
}

%end
