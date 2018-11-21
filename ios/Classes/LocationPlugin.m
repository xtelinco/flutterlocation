#import "LocationPlugin.h"
#import "BackgroundHandler.h"

@import CoreLocation;

@interface LocationPlugin() <FlutterPlugin, FlutterStreamHandler, CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *clLocationManager;
@property (copy, nonatomic)   FlutterResult      flutterResult;
@property (assign, nonatomic) BOOL               locationWanted;

@property (copy, nonatomic)   FlutterEventSink   flutterEventSink;
@property (assign, nonatomic) BOOL               flutterListening;
@property (assign, nonatomic) BOOL               backgroundListening;
@property (assign, nonatomic) BOOL               hasInit;
@end

@implementation LocationPlugin {
    NSUserDefaults *_persistentState;
}

+(void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"lyokone/location" binaryMessenger:registrar.messenger];
    FlutterEventChannel *stream = [FlutterEventChannel eventChannelWithName:@"lyokone/locationstream" binaryMessenger:registrar.messenger];

    LocationPlugin *instance = [[LocationPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    [stream setStreamHandler:instance];
    
    [registrar addApplicationDelegate:instance];
    
    [BackgroundHandler register:registrar];
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"LAUNCH");

  // Check to see if we're being launched due to a location event.
  if (launchOptions[UIApplicationLaunchOptionsLocationKey] != nil) {
        NSLog(@"LAUNCH with options");
        self.hasInit = YES;
        self.clLocationManager = [[CLLocationManager alloc] init];
        self.clLocationManager.delegate = self;

        self.clLocationManager.pausesLocationUpdatesAutomatically =
          [self getPausesLocationUpdatesAutomatically];
        if (@available(iOS 11.0, *)) {
          self.clLocationManager.showsBackgroundLocationIndicator =
              [self getShowsBackgroundLocationIndicator];
        }
        if (@available(iOS 9.0, *)) {
              self.clLocationManager.allowsBackgroundLocationUpdates = YES;
        }

        self.backgroundListening = YES;
        if(self.clLocationManager.location != nil) {
            [self updateLocation:self.clLocationManager.location];
        }
        // Finally, restart monitoring for location changes to get our location.
        [self.clLocationManager startMonitoringSignificantLocationChanges];

        [BackgroundHandler sharedInstance].wasStartByLocationManager = YES;
        FlutterViewController *root = (FlutterViewController *)[[[[UIApplication sharedApplication] delegate] window] rootViewController];
        [root viewWillAppear:NO];
  }

  // Note: if we return NO, this vetos the launch of the application.
  return YES;
}


-(instancetype)init {
    self = [super init];

    if (self) {
        self.locationWanted = NO;
        self.flutterListening = NO;
        self.hasInit = NO;
        self.backgroundListening = NO;
        _persistentState = [NSUserDefaults standardUserDefaults];
  
    }
    return self;
}
    
-(void)initLocation {
    if (!(self.hasInit)) {
        self.hasInit = YES;
        
        if ([CLLocationManager locationServicesEnabled]) {
            self.clLocationManager = [[CLLocationManager alloc] init];
            self.clLocationManager.delegate = self;
            if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"] != nil) {
                [self.clLocationManager requestWhenInUseAuthorization];
            }
            else if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] != nil) {
                [self.clLocationManager requestAlwaysAuthorization];
            }
            else {
                [NSException raise:NSInternalInconsistencyException format:@"To use location in iOS8 you need to define either NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription in the app bundle's Info.plist file"];
            }
            
            self.clLocationManager.desiredAccuracy = kCLLocationAccuracyBest;
        }
    }
}

-(void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    [self initLocation];
    NSArray *arguments = call.arguments;
    if ([call.method isEqualToString:@"getLocation"]) {
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied && [CLLocationManager locationServicesEnabled])
        {
            // Location services are requested but user has denied
            result([FlutterError errorWithCode:@"PERMISSION_DENIED"
                                   message:@"The user explicitly denied the use of location services for this app or location services are currently disabled in Settings."
                                   details:nil]);
            return;
        }
        
        self.flutterResult = result;
        self.locationWanted = YES;
        [self.clLocationManager startUpdatingLocation];
    } else if ([call.method isEqualToString:@"start"]) {
        [self.clLocationManager startUpdatingLocation];
    } else if ([call.method isEqualToString:@"stop"]) {
        [self.clLocationManager stopUpdatingLocation];
    } else if ([call.method isEqualToString:@"hasPermission"]) {
        NSLog(@"Do has permissions");
        if ([CLLocationManager locationServicesEnabled]) {
            
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied)
            {
                // Location services are requested but user has denied
                result(@(0));
            } else {
                // Location services are available
                result(@(1));
            }
            
            
        } else {
            // Location is not yet available
            result(@(0));
        }
    } else if ([@"monitorLocationChanges" isEqualToString:call.method]) {
        NSAssert(arguments.count == 3, @"Invalid argument count for 'monitorLocationChanges'");
        [self monitorLocationChanges:call.arguments];
        result(@(YES));
    } else if ([@"cancelLocationUpdates" isEqualToString:call.method]) {
        NSAssert(arguments.count == 0, @"Invalid argument count for 'cancelLocationUpdates'");
        [self stopUpdatingLocation];
        result(nil);
    } else if ([@"wasStartedByLocationManager" isEqualToString:call.method]) {
            result( @( [BackgroundHandler sharedInstance].wasStartByLocationManager ? 1 : 0 ) );
    } else {
        result(FlutterMethodNotImplemented);
    }
}

-(FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.flutterEventSink = events;
    self.flutterListening = YES;
    [self.clLocationManager startUpdatingLocation];
    return nil;
}

-(FlutterError*)onCancelWithArguments:(id)arguments {
    self.flutterListening = NO;
    return nil;
}

-(void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray<CLLocation*>*)locations {
    [self updateLocation: locations.firstObject];
}

-(void)updateLocation:(CLLocation*)location {
    NSDictionary<NSString*,NSNumber*>* coordinatesDict = @{
                                                          @"latitude": @(location.coordinate.latitude),
                                                          @"longitude": @(location.coordinate.longitude),
                                                          @"accuracy": @(location.horizontalAccuracy),
                                                          @"altitude": @(location.altitude),
                                                          @"timestamp": @(location.timestamp.timeIntervalSince1970),
                                                          @"speed": @(location.speed),
                                                          @"speed_accuracy": @(0.0),
                                                          };

    if (self.locationWanted) {
        self.locationWanted = NO;
        self.flutterResult(coordinatesDict);
    }
    if (self.flutterListening) {
        self.flutterEventSink(coordinatesDict);
        [[BackgroundHandler sharedInstance] notify:coordinatesDict];
    } else {
        if( ! [[BackgroundHandler sharedInstance] notify:coordinatesDict] ) {
            if(!self.backgroundListening) {
                NSLog(@"Background stop listening");
                [self.clLocationManager stopUpdatingLocation];
            }
        }
    }
}

// Start receiving location updates.
- (void)monitorLocationChanges:(NSArray *)arguments {
  self.clLocationManager.pausesLocationUpdatesAutomatically = arguments[0];
  if (@available(iOS 11.0, *)) {
    self.clLocationManager.showsBackgroundLocationIndicator = arguments[1];
  }
  self.clLocationManager.activityType = [arguments[2] integerValue];
  self.clLocationManager.activityType = CLActivityTypeOther;
  if (@available(iOS 9.0, *)) {
        self.clLocationManager.allowsBackgroundLocationUpdates = YES;
  }

  [self setPausesLocationUpdatesAutomatically:self.clLocationManager.pausesLocationUpdatesAutomatically];
  if (@available(iOS 11.0, *)) {
        [self setShowsBackgroundLocationIndicator:self.clLocationManager.showsBackgroundLocationIndicator];
  }
  self.backgroundListening = YES;
  [self.clLocationManager startMonitoringSignificantLocationChanges];
}

// Stop the location updates.
- (void)stopUpdatingLocation {
  self.backgroundListening = NO;
  [self.clLocationManager stopUpdatingLocation];
}

- (BOOL)getPausesLocationUpdatesAutomatically {
    return [_persistentState boolForKey:@"pauses_location_updates_automatically"];
}

- (void)setPausesLocationUpdatesAutomatically:(BOOL)pause {
    [_persistentState setBool:pause forKey:@"pauses_location_updates_automatically"];
}

- (BOOL)getShowsBackgroundLocationIndicator {
    return [_persistentState boolForKey:@"shows_background_location_indicator"];
}

- (void)setShowsBackgroundLocationIndicator:(BOOL)pause {
    [_persistentState setBool:pause forKey:@"shows_background_location_indicator"];
}


@end
