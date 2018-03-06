//
//  NSObject+YPCategory.m
//  YPCategory
//
//  Created by 喻平 on 15/4/3.
//  Copyright (c) 2015年 com.yp.YPCategory All rights reserved.
//

#import "NSObject+YPCategory.h"
#import "NSString+YPCategory.h"
#import <objc/runtime.h>

NSString * const YPNightModelSwitchedNotification = @"YPNightModelSwitchedNotification";

static const int kvo_block_key;

@interface YPNSObjectKVOBlockTarget : NSObject

@property (nonatomic, copy) void (^block)(__weak id obj, id oldVal, id newVal);

- (id)initWithBlock:(void (^)(__weak id obj, id oldVal, id newVal))block;

@end

@implementation YPNSObjectKVOBlockTarget

- (id)initWithBlock:(void (^)(__weak id obj, id oldVal, id newVal))block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (!self.block) return;
    
    BOOL isPrior = [[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue];
    if (isPrior) return;
    
    NSKeyValueChange changeKind = [[change objectForKey:NSKeyValueChangeKindKey] integerValue];
    if (changeKind != NSKeyValueChangeSetting) return;
    
    id oldVal = [change objectForKey:NSKeyValueChangeOldKey];
    if (oldVal == [NSNull null]) oldVal = nil;
    
    id newVal = [change objectForKey:NSKeyValueChangeNewKey];
    if (newVal == [NSNull null]) newVal = nil;
    
    self.block(object, oldVal, newVal);
}

@end


@implementation NSObject (YPCategory)

#pragma mark - Swap method (Swizzling)

+ (BOOL)swizzleInstanceMethod:(SEL)originalSel with:(SEL)newSel {
    Method originalMethod = class_getInstanceMethod(self, originalSel);
    Method newMethod = class_getInstanceMethod(self, newSel);
    if (!originalMethod || !newMethod) return NO;
    
    class_addMethod(self,
                    originalSel,
                    class_getMethodImplementation(self, originalSel),
                    method_getTypeEncoding(originalMethod));
    class_addMethod(self,
                    newSel,
                    class_getMethodImplementation(self, newSel),
                    method_getTypeEncoding(newMethod));
    
    method_exchangeImplementations(class_getInstanceMethod(self, originalSel),
                                   class_getInstanceMethod(self, newSel));
    return YES;
}

+ (BOOL)swizzleClassMethod:(SEL)originalSel with:(SEL)newSel {
    Class class = object_getClass(self);
    Method originalMethod = class_getInstanceMethod(class, originalSel);
    Method newMethod = class_getInstanceMethod(class, newSel);
    if (!originalMethod || !newMethod) return NO;
    method_exchangeImplementations(originalMethod, newMethod);
    return YES;
}

#pragma mark - Associate value

- (void)setAssociateValue:(id)value withKey:(void *)key {
    objc_setAssociatedObject(self, key, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setAssociateWeakValue:(id)value withKey:(void *)key {
    objc_setAssociatedObject(self, key, value, OBJC_ASSOCIATION_ASSIGN);
}

- (void)setAssociateCopyValue:(id)value withKey:(void *)key {
    objc_setAssociatedObject(self, key, value, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)removeAssociatedValues {
    objc_removeAssociatedObjects(self);
}

- (id)getAssociatedValueForKey:(void *)key {
    return objc_getAssociatedObject(self, key);
}

#pragma mark - KVO

- (void)addObserverBlockForKeyPath:(NSString *)keyPath block:(void (^)(__weak id obj, id oldVal, id newVal))block {
    if (!keyPath || !block) return;
    YPNSObjectKVOBlockTarget *target = [[YPNSObjectKVOBlockTarget alloc] initWithBlock:block];
    NSMutableDictionary *dic = [self allNSObjectObserverBlocks];
    NSMutableArray *arr = dic[keyPath];
    if (!arr) {
        arr = [NSMutableArray new];
        dic[keyPath] = arr;
    }
    [arr addObject:target];
    [self addObserver:target forKeyPath:keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)removeObserverBlocksForKeyPath:(NSString *)keyPath {
    if (!keyPath) return;
    NSMutableDictionary *dic = [self allNSObjectObserverBlocks];
    NSMutableArray *arr = dic[keyPath];
    [arr enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
        [self removeObserver:obj forKeyPath:keyPath];
    }];
    
    [dic removeObjectForKey:keyPath];
}

- (void)removeObserverBlocks {
    NSMutableDictionary *dic = [self allNSObjectObserverBlocks];
    [dic enumerateKeysAndObjectsUsingBlock: ^(NSString *key, NSArray *arr, BOOL *stop) {
        [arr enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
            [self removeObserver:obj forKeyPath:key];
        }];
    }];
    
    [dic removeAllObjects];
}

- (NSMutableDictionary *)allNSObjectObserverBlocks {
    NSMutableDictionary *targets = objc_getAssociatedObject(self, &kvo_block_key);
    if (!targets) {
        targets = [NSMutableDictionary new];
        objc_setAssociatedObject(self, &kvo_block_key, targets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return targets;
}


#pragma mark - Others

+ (NSString *)className {
    return NSStringFromClass(self);
}

- (NSString *)className {
    return [NSString stringWithUTF8String:class_getName([self class])];
}

- (id)deepCopy {
    id obj = nil;
    @try {
        obj = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self]];
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception);
    }
    return obj;
}

- (id)deepCopyWithArchiver:(Class)archiver unarchiver:(Class)unarchiver {
    id obj = nil;
    @try {
        obj = [unarchiver unarchiveObjectWithData:[archiver archivedDataWithRootObject:self]];
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception);
    }
    return obj;
}

- (void)addNightModelSwitchedObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nightModelSwitched:) name:YPNightModelSwitchedNotification object:nil];
}

- (void)removeNightModelSwitchedObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YPNightModelSwitchedNotification object:nil];
}

- (void)nightModelSwitched:(NSNotification *)notification {
}

+ (NSString *)stringByReplaceUnicode:(NSString *)string {
    NSMutableString *convertedString = [string mutableCopy];
    [convertedString replaceOccurrencesOfString:@"\\U" withString:@"\\u" options:0 range:NSMakeRange(0, convertedString.length)];
    CFStringRef transform = CFSTR("Any-Hex/Java");
    CFStringTransform((__bridge CFMutableStringRef)convertedString, NULL, transform, YES);
    return convertedString;
}

- (id)removeNullObjects {
    NSObject *objResult = nil;
    NSMutableArray *marrSearch = nil;
    if ([self isKindOfClass:NSNull.class]) {
        return nil;
    } else if ([self isKindOfClass:NSArray.class]) {
        objResult = [NSMutableArray arrayWithArray:(NSArray *)self];
        marrSearch = [NSMutableArray arrayWithObject:objResult];
    } else if ([self isKindOfClass:NSDictionary.class]) {
        objResult = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)self];
        marrSearch = [NSMutableArray arrayWithObject:objResult];
    } else {
        return self;
    }
    while (marrSearch.count > 0) {
        NSObject *header = marrSearch[0];
        if ([header isKindOfClass:NSMutableDictionary.class]) {
            // 遍历这个字典
            NSMutableDictionary *mdicTemp = (NSMutableDictionary *)header;
            for (NSString *strKey in mdicTemp.allKeys) {
                NSObject *objTemp = mdicTemp[strKey];
                if ([objTemp isKindOfClass:NSDictionary.class]) {
                    // 将NSDictionary替换为NSMutableDictionary
                    NSMutableDictionary *mdic = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)objTemp];
                    mdicTemp[strKey] = mdic;
                    [marrSearch addObject:mdic];
                } else if ([objTemp isKindOfClass:NSArray.class]) {
                    // 将NSArray替换为NSMutableArray
                    NSMutableArray *marr = [NSMutableArray arrayWithArray:(NSArray *)objTemp];
                    mdicTemp[strKey] = marr;
                    [marrSearch addObject:marr];
                } else if ([objTemp isKindOfClass:NSNull.class]) {
                    // 删除NSNull
                    mdicTemp[strKey] = nil;
                }
            }
        } else if ([header isKindOfClass:NSMutableArray.class]) {
            // 遍历这个数组
            NSMutableArray *marrTemp = (NSMutableArray *)header;
            for (NSInteger i = marrTemp.count - 1; i >= 0; i--) {
                NSObject *objTemp = marrTemp[i];
                
                if ([objTemp isKindOfClass:NSDictionary.class]) {
                    // 将NSDictionary替换为NSMutableDictionary
                    NSMutableDictionary *mdic = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)objTemp];
                    [marrTemp replaceObjectAtIndex:i withObject:mdic];
                    [marrSearch addObject:mdic];
                } else if ([objTemp isKindOfClass:NSArray.class]) {
                    // 将NSArray替换为NSMutableArray
                    NSMutableArray *marr = [NSMutableArray arrayWithArray:(NSArray *)objTemp];
                    [marrTemp replaceObjectAtIndex:i withObject:marr];
                    [marrSearch addObject:marr];
                } else if ([objTemp isKindOfClass:NSNull.class]) {
                    // 删除NSNull
                    [marrTemp removeObjectAtIndex:i];
                }
            }
        } else {
            // 到这里就出错了
        }
        [marrSearch removeObjectAtIndex:0];
    }
    return objResult;
}

- (NSArray *)yp_arrayForKey:(id)key {
    if (!key) {
        return nil;
    }
    if (![self respondsToSelector:@selector(objectForKey:)]) {
        return nil;
    }
    id obj = [(NSDictionary *)self objectForKey:key];
    if ([obj isKindOfClass:[NSArray class]]) {
        return (NSArray *)obj;
    }
    return nil;
}

- (NSDictionary *)yp_dictionaryForKey:(id)key {
    if (!key) {
        return nil;
    }
    if (![self respondsToSelector:@selector(objectForKey:)]) {
        return nil;
    }
    id obj = [(NSDictionary *)self objectForKey:key];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)obj;
    }
    return nil;
}

- (NSString *)yp_stringForKey:(id)key {
    if (!key) {
        return nil;
    }
    if (![self respondsToSelector:@selector(objectForKey:)]) {
        return nil;
    }
    id obj = [(NSDictionary *)self objectForKey:key];
    if ([obj isKindOfClass:[NSString class]]) {
        return (NSString *)obj;
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)obj stringValue];
    }
    return nil;
}

- (NSNumber *)yp_numberForKey:(id)key {
    if (!key) {
        return nil;
    }
    if (![self respondsToSelector:@selector(objectForKey:)]) {
        return nil;
    }
    id obj = [(NSDictionary *)self objectForKey:key];
    if ([obj isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)obj;
    } else if ([obj isKindOfClass:[NSString class]]) {
        return [(NSString *)obj numberValue];
    }
    return nil;
}

- (NSInteger)yp_integerForKey:(id)key {
    return [[self yp_numberForKey:key] integerValue];
}

- (BOOL)yp_boolForKey:(id)key {
    return [[self yp_numberForKey:key] boolValue];
}

- (float)yp_floatForKey:(id)key {
    return [[self yp_numberForKey:key] floatValue];
}

- (id)yp_objectAtIndex:(NSUInteger)index {
    if (![self respondsToSelector:@selector(objectAtIndex:)]) {
        return nil;
    }
    NSArray *array = (NSArray *)self;
    if (index < array.count) {
        return [array objectAtIndex:index];
    }
    return nil;
}

@end
