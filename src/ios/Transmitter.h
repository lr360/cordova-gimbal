#import <Foundation/Foundation.h>

@interface Transmitter : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSNumber *rssi;
@property (nonatomic, strong) NSNumber *previousRSSI;
@property (nonatomic, strong) NSDate *lastSighted;
@property (nonatomic, strong) NSNumber *batteryLevel;
@property (nonatomic, strong) NSNumber *temperature;

@end
