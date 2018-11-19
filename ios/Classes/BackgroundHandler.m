#import "BackgroundHandler.h"

@implementation BackgroundHandler {
    FlutterEventSink _eventSink;
    NSDictionary<NSString*,NSNumber*>* _lastLocation;
};

+ (BackgroundHandler *)sharedInstance
{
    static BackgroundHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

+(void)register:(NSObject<FlutterPluginRegistrar>*)registrar {
    BackgroundHandler *handler = [BackgroundHandler sharedInstance];
    FlutterEventChannel *eventChannel = [FlutterEventChannel eventChannelWithName:@"lyokone/backgroundlocation" binaryMessenger: [registrar messenger]];

    [eventChannel setStreamHandler:handler];
}

-(instancetype)init {
    self = [super init];
    
    if (self) {
        self->_eventSink = nil;
        self->_lastLocation = nil;
        self.wasStartByLocationManager = NO;
    }
    return self;
}

-(void)notify:(NSDictionary<NSString*,NSNumber*>*)location {
    if(_eventSink != nil) {
        _eventSink(location);
    }
    _lastLocation = location;
}

// @override by derived StreamHandler
-(NSString*) event {
    return @"background_location";
}

// @override by derived StreamHandler
- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    _eventSink = events;
    if( _lastLocation ) {
        events(_lastLocation);
    }
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    _eventSink = nil;
    return nil;
}

@end
