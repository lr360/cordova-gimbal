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

@end

@implementation CBGimbal

- (void)startService:(CDVInvokedUrlCommand*)command
{
    NSString *appId = [[command arguments] objectAtIndex:0];
    NSString *appSecret = [[command arguments] objectAtIndex:1];
    NSString *callbackUrl = [[command arguments] objectAtIndex:2];

    [FYX setAppId:appId
        appSecret:appSecret
      callbackUrl:callbackUrl];

    [FYX startService:self];

    self.visitManager = [FYXVisitManager new];
    self.visitManager.delegate = self;
    [self.visitManager start];

    [FYXLogging setLogLevel:FYX_LOG_LEVEL_INFO];
    [FYX startService:self];

    self._startCallbackId = command.callbackId;

    self.lastAlertSent = nil;
}

- (void)dealloc
{
    [self.visitManager stop];
}

- (BOOL)isProximityEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"fyx_service_started_key"];
}

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

#pragma mark - FYX Delegate methods

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
