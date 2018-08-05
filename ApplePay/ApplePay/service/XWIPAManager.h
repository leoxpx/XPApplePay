//
//  XWIPAManager.h
//  ZhengXinChaXun
//
//  Created by xinwang on 2018/6/20.
//  Copyright © 2018年 xinwang2. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface XWIPAManager : NSObject

/** 单利 */
+ (XWIPAManager *)ShareManager;

/** 购买单个 不包含二次验证 成功后需配合 deledateSelfProductId */
- (void)startBuyRequest:(NSString *)productIdentifier selfProductId:(NSString *)selfProductId success:(void (^)(SKPaymentTransaction *transaction, NSString *selfProductId))successBlock failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failureBlock;

/** 异常退出 恢复购买 成功后需配合deledateSelfProductId */
- (void)restoreBuyRequestSuccess:(void (^)(SKPaymentTransaction *transaction, NSString *selfProductId))successBlock failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failureBlock;

/** 交易成功/恢复订单 结束, 删除凭证备份 */
- (void)deledateSelfProductIdForNet:(NSString *)myProductId;

/** 删除监听(不用添加) */
- (void)removeXWObserver;

@end
