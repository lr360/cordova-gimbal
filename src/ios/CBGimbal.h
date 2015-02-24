#ifndef Beacon_gimbal_h
#define Beacon_gimbal_h

#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>

@interface CBGimbal : CDVPlugin

- (void)deviceready:(CDVInvokedUrlCommand*)command;
- (void)startService:(CDVInvokedUrlCommand*)command;

@end

#endif