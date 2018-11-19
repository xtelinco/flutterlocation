#import <Flutter/Flutter.h>

@interface BackgroundHandler : NSObject<FlutterStreamHandler>
@property (assign, nonatomic) BOOL               wasStartByLocationManager;


+(void)register:(NSObject<FlutterPluginRegistrar>*)registrar;
+(BackgroundHandler *)sharedInstance;

-(void)notify:(NSDictionary<NSString*,NSNumber*>*)location;


@end
