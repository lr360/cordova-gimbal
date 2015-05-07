#import "CBGimbal.h"
#import "Transmitter.h"

#import <Cordova/CDV.h>

#import <FYX/FYX.h>
#import <FYX/FYXVisitManager.h>
#import <FYX/FYXSightingManager.h>
#import <FYX/FYXTransmitter.h>
#import <FYX/FYXVisit.h>
#import <FYX/FYXLogging.h>

@interface CBGimbal () <FYXServiceDelegate, FYXVisitDelegate>

@property NSMutableArray *transmitters;
@property FYXVisitManager *visitManager;
@property BOOL isdeviceready;

@end

@implementation CBGimbal

- (id)settingForKey:(NSString*)key
{
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}

- (void) deviceready:(CDVInvokedUrlCommand*)command
{
    NSLog(@"INFO: Device ready now!");
    _isdeviceready = YES;
}

- (id) initWithWebView:(UIWebView*)theWebView
{
    self = [super initWithWebView:theWebView];

    [self registerInitialValuesForUserDefaults];

    NSString* appId = [self settingForKey:@"GimbalAppId"];
    NSLog(@"INFO: appId: %@", appId);

    NSString* appSecret = [self settingForKey:@"GimbalAppSecret"];
    NSLog(@"INFO: appSecret: %@", appSecret);

    NSString* callbackUrl = [self settingForKey:@"GimbalCallbackUrl"];
    NSLog(@"INFO: callbackUrl: %@", callbackUrl);

    [FYX setAppId:@"44dfcbbb3a3ba2fdb88faf0ba17c5f2f30da0e714072ba24880cdafc5c15625d"
        appSecret:@"b1a923e427ca1cabf915005dfba2ff3ec847dfb191181797a115127d2f18ca93"
      callbackUrl:@"comfidemappsdemomobile://fidemfans"];
    [FYXLogging setLogLevel:FYX_LOG_LEVEL_INFO];

    [FYX startService:self];

    if ([self isProximityEnabled])
    {
        NSLog(@"INFO: Proximity is enabled");
    }
    else
    {
        NSLog(@"ERROR: Proximity not enabled!!!");
    }

    return self;
}

- (void)dealloc
{
    [self.visitManager stop];
}

- (BOOL)isProximityEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"fyx_service_started_key"];
}

- (void)registerInitialValuesForUserDefaults {

    // Get the path of the settings bundle (Settings.bundle)
    NSString *settingsBundlePath = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if (!settingsBundlePath) {
        NSLog(@"ERROR: Unable to locate Settings.bundle within the application bundle!");
        return;
    }

    // Get the path of the settings plist (Root.plist) within the settings bundle
    NSString *settingsPlistPath = [[NSBundle bundleWithPath:settingsBundlePath] pathForResource:@"Root" ofType:@"plist"];
    if (!settingsPlistPath) {
        NSLog(@"ERROR: Unable to locate Root.plist within Settings.bundle!");
        return;
    }

    // Create a new dictionary to hold the default values to register
    NSMutableDictionary *defaultValuesToRegister = [NSMutableDictionary new];

    // Iterate over the preferences found in the settings plist
    NSArray *preferenceSpecifiers = [[NSDictionary dictionaryWithContentsOfFile:settingsPlistPath] objectForKey:@"PreferenceSpecifiers"];
    for (NSDictionary *preference in preferenceSpecifiers) {

        NSString *key = [preference objectForKey:@"Key"];
        id defaultValueObject = [preference objectForKey:@"DefaultValue"];

        if (key && defaultValueObject) {
            // If a default value was found, add it to the dictionary
            [defaultValuesToRegister setObject:defaultValueObject forKey:key];
        }
    }

    // Register the initial values in UserDefaults that were found in the settings bundle
    if (defaultValuesToRegister.count > 0) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults registerDefaults:defaultValuesToRegister];
        [userDefaults synchronize];
    }
}

#pragma mark - FYX Delegate methods

- (void)serviceStarted
{
    NSLog(@"#########Proximity service started!");

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"fyx_service_started_key"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.transmitters = [NSMutableArray new];

    self.visitManager = [[FYXVisitManager alloc] init];
    self.visitManager.delegate = self;

    [self.visitManager startWithOptions:@{FYXVisitOptionDepartureIntervalInSecondsKey:@15,
                                          FYXSightingOptionSignalStrengthWindowKey:@(FYXSightingOptionSignalStrengthWindowNone)}];
}

- (void)startServiceFailed:(NSError *)error
{
    NSLog(@"#########Proximity service failed to start! error is: %@", error);

    NSString *message = @"Service failed to start, please check to make sure your Application Id and Secret are correct.";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Proximity Service"
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - FYX visit delegate

- (void)didArrive:(FYXVisit *)visit
{
    NSLog(@"############## didArrive: %@", visit);
}

- (void)didDepart:(FYXVisit *)visit
{
    NSLog(@"############## didDepart: %@", visit);
}

- (void)receivedSighting:(FYXVisit *)visit updateTime:(NSDate *)updateTime RSSI:(NSNumber *)RSSI
{
    NSLog(@"############## receivedSighting: %@", visit);

    Transmitter *transmitter = [[self.transmitters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", visit.transmitter.identifier]] firstObject];
    if (transmitter == nil)
    {
        transmitter = [Transmitter new];
        transmitter.identifier = visit.transmitter.identifier;
        transmitter.name = visit.transmitter.name ? visit.transmitter.name : visit.transmitter.identifier;
        transmitter.lastSighted = [NSDate dateWithTimeIntervalSince1970:0];
        transmitter.rssi = [NSNumber numberWithInt:-100];
        transmitter.previousRSSI = transmitter.rssi;
        transmitter.batteryLevel = 0;
        transmitter.temperature = 0;

        [self.transmitters addObject:transmitter];
    }

   transmitter.lastSighted = updateTime;

   [self fireEvent:@"proximity" identifier:transmitter.identifier name:transmitter.name rssi:RSSI];

}

/**
 * Fires the given event.
 *
 * @param {NSString} event
 *      The Name of the event
 * @param {NSString} id
 *      The ID of the notification
 * @param {NSString} json
 *      A custom (JSON) string
 */
- (void) fireEvent:(NSString*)event identifier:(NSString*)identifier name:(NSString*)name rssi:(NSNumber*)rssi
{
    NSString* params = [NSString stringWithFormat:
                        @"\"%@\",\"%@\",%@",
                        identifier, name, rssi];

    NSString* js = [NSString stringWithFormat:
                    @"setTimeout('window.gimbal.on%@(%@)',0)",
                    event, params];

    [self.commandDelegate evalJs:js];

}

@end
