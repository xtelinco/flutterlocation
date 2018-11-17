#import "LocationPlugin.h"

@import CoreLocation;

@interface LocationPlugin() <FlutterStreamHandler, CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *clLocationManager;
@property (strong, nonatomic) CLLocation *lastLocation;
@property (copy, nonatomic)   FlutterResult      flutterResult;
@property (copy, nonatomic)   FlutterEventSink   flutterEventSink;
@property (assign, nonatomic) BOOL               flutterListening;
@property (assign, nonatomic) BOOL               autoAuthorize;
@property (assign, nonatomic) BOOL               locationUpdating;
@property (assign, nonatomic) int                locationAccuracy;
@property (copy, nonatomic)   FlutterResult      authorizeResult;
@end

static bool launchedByLocationManager = false;

@implementation LocationPlugin

+(void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"lyokone/location" binaryMessenger:registrar.messenger];
    FlutterEventChannel *stream = [FlutterEventChannel eventChannelWithName:@"lyokone/locationstream" binaryMessenger:registrar.messenger];

    LocationPlugin *instance = [[LocationPlugin alloc] init];
    [registrar addApplicationDelegate:instance];
    [registrar addMethodCallDelegate:instance channel:channel];
    [stream setStreamHandler:instance];
}

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if([launchOptions objectForKey:UIApplicationLaunchOptionsLocationKey] != nil) {
        launchedByLocationManager = true;
        CLLocationManager *manager = [self getSharedLocationManager];
        if(manager != nil && manager.location != nil) {
            self.lastLocation = manager.location;
        }
    } else{
        launchedByLocationManager = false;
    }
    
    return YES;
}

-(void)applicationDidEnterBackground:(UIApplication *)application {
    NSLog(@"Enter background");
}

-(instancetype)init {
    self = [super init];
    if (self) {
        self.flutterListening = NO;
        self.autoAuthorize = YES;
        self.locationUpdating = NO;
        self.locationAccuracy = 1;
        self.lastLocation = nil;
    }
    return self;
}

-(CLLocationManager *)getSharedLocationManager {
    if(self.clLocationManager == nil) {
        self.clLocationManager = [[CLLocationManager alloc] init];
        self.clLocationManager.delegate = self;
        self.clLocationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
        //self.clLocationManager.showsBackgroundLocationIndicator = YES;
    }
    return self.clLocationManager;
}

-(void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"getLocation"]) {
        if ([CLLocationManager locationServicesEnabled]) {
            [self getSharedLocationManager];
            
            if( self.autoAuthorize ) {
                if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"] != nil) {
                    [self.clLocationManager requestWhenInUseAuthorization];
                }
                else if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] != nil) {
                    [self.clLocationManager requestAlwaysAuthorization];
                }
                else {
                    [NSException raise:NSInternalInconsistencyException format:@"To use location in iOS8 you need to define either NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription in the app bundle's Info.plist file"];
                }
            }

            if( self.lastLocation != nil ) {
                NSDictionary<NSString*,NSNumber*>* coordinatesDict = @{
                   @"latitude": @(self.lastLocation.coordinate.latitude),
                   @"longitude": @(self.lastLocation.coordinate.longitude),
                   @"accuracy": @(self.lastLocation.horizontalAccuracy),
                   @"altitude": @(self.lastLocation.altitude),
                   @"ts": @(self.lastLocation.timestamp.timeIntervalSince1970),
                 };
                result( coordinatesDict );
            }else{
                self.flutterResult = result;
            }

            NSLog(@"Sending request");
            [self.clLocationManager requestLocation];
        }
    }else if ([call.method isEqualToString:@"getAuthorizationStatus"]) {
        self.autoAuthorize = NO;
        
        if( ![CLLocationManager locationServicesEnabled] ) {
            result( @"Off" );
            return;
        }
        
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        NSString *ret;
        switch(status) {
            default:       ret = @"NotDetermined"; break;
            case kCLAuthorizationStatusDenied:              ret = @"Denied";        break;
            case kCLAuthorizationStatusRestricted:          ret = @"NotAuthorized"; break;
            case kCLAuthorizationStatusAuthorizedAlways:    ret = @"Always";        break;
            case kCLAuthorizationStatusAuthorizedWhenInUse: ret = @"InUse";         break;
        }
        result( ret );
    }else if ([call.method isEqualToString:@"authorize"]) {
        self.autoAuthorize = NO;

        if( [CLLocationManager locationServicesEnabled] ) {
            [self getSharedLocationManager];
            CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
            NSLog(@"args: %@", call.arguments);
            if( status == kCLAuthorizationStatusNotDetermined ) {
              self.authorizeResult = result;
              if([ call.arguments[@"type"] isEqualToString:@"Always"]) {
                 [self.clLocationManager requestAlwaysAuthorization];
              }else{
                 [self.clLocationManager requestWhenInUseAuthorization];
              }
            }else{
              if([ call.arguments[@"type"] isEqualToString:@"Always"]) {
                if( status == kCLAuthorizationStatusAuthorizedAlways ) {
                  result(@"Always");
                }else{
                  result(@"Denied");
                } 
              } else {
                if( status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse ) {
                  result(@"InsUse");
                }else{
                  result(@"Denied");
                } 
              }
            }
        }else{
            result(@"Off");
        }
    }else if ([call.method isEqualToString:@"wasStartedByLocationManager"]) {
        if(launchedByLocationManager) {
            result( [[NSNumber alloc] initWithInt:2] );
        }else{
            result( [[NSNumber alloc] initWithInt:0] );
        }
    }else if ([call.method isEqualToString:@"startMonitoringSignificant"]) {
        [self getSharedLocationManager];
        [self.clLocationManager startMonitoringSignificantLocationChanges];
        result( [[NSNumber alloc] initWithInt:1] );
    }else if ([call.method isEqualToString:@"stopMonitoringSignificant"]) {
        [self getSharedLocationManager];
        [self.clLocationManager stopMonitoringSignificantLocationChanges];
        result( [[NSNumber alloc] initWithInt:1] );
    }else if ([call.method isEqualToString:@"getLastSignificantLocation"]) {
        [self getSharedLocationManager];
        if( self.clLocationManager.location != nil ) {
            NSDictionary<NSString*,NSNumber*>* coordinatesDict = @{
               @"latitude": @(self.clLocationManager.location.coordinate.latitude),
               @"longitude": @(self.clLocationManager.location.coordinate.longitude),
               @"accuracy": @(self.clLocationManager.location.horizontalAccuracy),
               @"altitude": @(self.clLocationManager.location.altitude),
               @"ts": @(self.clLocationManager.location.timestamp.timeIntervalSince1970),
            };
            result( coordinatesDict );
        }else{
            result( nil );
        }
    }else if ([call.method isEqualToString:@"start"]) {
        [self getSharedLocationManager];
        [self startWithArguments:call.arguments];
        result( [[NSNumber alloc] initWithInt:1] );
    }else if ([call.method isEqualToString:@"stop"]) {
        [self getSharedLocationManager];
        [self stop];
        result( [[NSNumber alloc] initWithInt:1] );
    } else {
        result(FlutterMethodNotImplemented);
    }
}
    
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if( self.authorizeResult != nil ) {
        NSString *ret;
        bool send = true;
        switch(status) {
            default:       ret = @"NotDetermined"; send = false; break;
            case kCLAuthorizationStatusDenied:              ret = @"Denied";        break;
            case kCLAuthorizationStatusRestricted:          ret = @"NotAuthorized"; break;
            case kCLAuthorizationStatusAuthorizedAlways:    ret = @"Always";        break;
            case kCLAuthorizationStatusAuthorizedWhenInUse: ret = @"InUse";         break;
        }
        if( send ) {
            self.authorizeResult( ret );
            self.authorizeResult = nil;
        }
    }
}

-(void)stop {
    if( self.locationUpdating == YES ) {
        [self.clLocationManager stopUpdatingLocation];
        self.locationUpdating = NO;
    }
}

-(void)startWithArguments:(id)arguments {
    NSDictionary *args = (NSDictionary *)arguments;
    bool start = true;
    NSLog(@"startWithArguments %@", args);
    if( args != nil && args[@"accuracy"] != nil ) {
        NSNumber *v = args[@"accuracy"];
        switch( v.intValue ) {
            default:
               self.clLocationManager.desiredAccuracy = kCLLocationAccuracyBest;
               self.locationAccuracy = 1;
               break;
            case 1:
               self.clLocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
               self.locationAccuracy = 2;
               break;
            case 2:
               self.clLocationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
               self.locationAccuracy = 3;
               break;
            case 3:
               self.clLocationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
               self.locationAccuracy = 4;
               break;
        }
    }
    if( args != nil && args[@"start"] != nil ) {
        NSNumber *v = args[@"start"];
        if( v != nil && v.intValue == 0) {
            start = false;
        }
    }
    if( start && self.locationUpdating == NO ) {
        [self.clLocationManager startUpdatingLocation];
        self.locationUpdating = YES;
    }
}

-(FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.flutterEventSink = events;
    self.flutterListening = YES;
    [self startWithArguments:arguments];
    return nil;
}

-(FlutterError*)onCancelWithArguments:(id)arguments {
    self.flutterListening = NO;
    return nil;
}

-(void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray<CLLocation*>*)locations {
    CLLocation *location = locations.firstObject;
    NSDictionary<NSString*,NSNumber*>* coordinatesDict = @{
                                                          @"latitude": @(location.coordinate.latitude),
                                                          @"longitude": @(location.coordinate.longitude),
                                                          @"accuracy": @(location.horizontalAccuracy),
                                                          @"altitude": @(location.altitude),
                                                          @"ts": @(location.timestamp.timeIntervalSince1970),
                                                          };
    NSLog(@"ios land %@", coordinatesDict);
    self.lastLocation = location;
    if(self.flutterResult != nil) {
        self.flutterResult(coordinatesDict);
        self.flutterResult = nil;
    }
    if (self.flutterListening) {
        self.flutterEventSink(coordinatesDict);
    } else {
        [self.clLocationManager stopUpdatingLocation];
        self.locationUpdating = NO;
    }
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"location error: %@", error);
}

@end
