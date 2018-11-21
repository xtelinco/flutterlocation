#import <Flutter/Flutter.h>

#import <CoreLocation/CoreLocation.h>

@interface LocationPlugin : NSObject<FlutterPlugin, CLLocationManagerDelegate>
-(void)updateLocation:(CLLocation*)location;

@end
