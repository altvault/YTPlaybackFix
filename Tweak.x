%hook NSError

- (id)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict {
    // Non cancelliamo più l'errore (return nil), lasciamo che esista
    // ma agiamo solo quando è il codice 14 che rompe le scatole
    if ([domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] && code == 14) {
        
        NSLog(@"[YTPlaybackFix] Errore 14 rilevato, avvio procedura di invisibilità...");
        
        // Invece di distruggere l'errore, inviamo solo il comando di retry
        // senza toccare la struttura dell'errore originale.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sharedPlaybackController) {
                [sharedPlaybackController performSelector:@selector(retry)];
            }
        });
        
        // Non ritorniamo nil, restituiamo l'errore originale così YouTube è felice
        // ma nel frattempo il 'retry' ha già ricaricato il video sotto.
        return %orig;
    }
    return %orig;
}

%end
