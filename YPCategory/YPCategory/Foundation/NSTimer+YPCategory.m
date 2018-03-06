//
//  NSTimer+YPCategory.m
//  YPCategory
//
//  Created by 喻平 on 16/7/6.
//  Copyright © 2016年 YPCategory. All rights reserved.
//

#import "NSTimer+YPCategory.h"
#import "UIDevice+YPCategory.h"

@implementation NSTimer (YPCategory)

+ (void)yp_ExecBlock:(NSTimer *)timer {
    if ([timer userInfo]) {
        void (^block)(NSTimer *timer) = (void (^)(NSTimer *timer))[timer userInfo];
        block(timer);
    }
}

+ (NSTimer *)yp_scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
                                       repeats:(BOOL)repeats
                                         block:(void (^)(NSTimer *timer))block {
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
        return [NSTimer scheduledTimerWithTimeInterval:seconds repeats:repeats block:block];
    } else {
        return [NSTimer scheduledTimerWithTimeInterval:seconds
                                                target:self
                                              selector:@selector(yp_ExecBlock:)
                                              userInfo:[block copy]
                                               repeats:repeats];
    }
}

+ (NSTimer *)yp_timerWithTimeInterval:(NSTimeInterval)seconds
                              repeats:(BOOL)repeats
                                block:(void (^)(NSTimer *timer))block {
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
        return [NSTimer timerWithTimeInterval:seconds repeats:repeats block:block];
    } else {
        return [NSTimer timerWithTimeInterval:seconds
                                       target:self
                                     selector:@selector(yp_ExecBlock:)
                                     userInfo:[block copy]
                                      repeats:repeats];
    }
}

@end
