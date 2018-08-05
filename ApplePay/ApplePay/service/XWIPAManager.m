//
//  XWIPAManager.m
//  ZhengXinChaXun
//
//  Created by xinwang on 2018/6/20.
//  Copyright © 2018年 xinwang2. All rights reserved.
//

#import "XWIPAManager.h"

#define SelfProductID @"selfProductID"
#define NetWrong @"selfNetWrong"
typedef void (^XWSKPaymentTransactionSuccessBlock)(SKPaymentTransaction *transaction, NSString *selfProductId);
typedef void (^XWSKPaymentTransactionFailureBlock)(SKPaymentTransaction *transaction, NSError *error);

@interface XWIPAManager() <SKPaymentTransactionObserver, SKProductsRequestDelegate>

@property (nonatomic, copy) NSString *productIdentifier; // 价格ID
@property (nonatomic, copy) NSString *selfProductId; // 商品订单号
@property (nonatomic, copy) XWSKPaymentTransactionSuccessBlock successBlock;
@property (nonatomic, copy) XWSKPaymentTransactionFailureBlock failureBlock;

@end

@implementation XWIPAManager

#pragma mark- ------------ 公有方法

+ (XWIPAManager *)ShareManager {
    static XWIPAManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}

- (BOOL)canMakePayments {
    return [SKPaymentQueue canMakePayments];
}

// 开始购买
- (void)startBuyRequest:(NSString *)productIdentifier selfProductId:(NSString *)selfProductId success:(void (^)(SKPaymentTransaction *transaction, NSString *selfProductId))successBlock failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failureBlock {
    // 添加观察者为自己
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    _productIdentifier = productIdentifier;
    _selfProductId = selfProductId;
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    
    if ([SKPaymentQueue canMakePayments]) {
        [self requestProductData:productIdentifier];
    } else {
        NSLog(@"不允许程序内付费");
    }
}

// 恢复购买
- (void)restoreBuyRequestSuccess:(void (^)(SKPaymentTransaction *transaction, NSString *selfProductId))successBlock failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failureBlock {
//    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SelfProductID];
//    [[NSUserDefaults standardUserDefaults] removeObjectForKey:NetWrong];
    
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    
    // 漏单控制
    NSArray *selfProductIdArr = [[NSUserDefaults standardUserDefaults] valueForKey:SelfProductID];
    if (selfProductIdArr && selfProductIdArr.count > 0) {
        _selfProductId = selfProductIdArr.lastObject; // 妥协. 多次掉单无法对应订单信息, userName也会为nil, 所以取最后一次订单信息 其他全部关闭
        // 添加观察者为自己
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    
    // 重新校验所有订单
    NSArray *myProductIdArr = [[NSUserDefaults standardUserDefaults] objectForKey:NetWrong];
    if (myProductIdArr && myProductIdArr.count > 0) {
        if (_successBlock) {
            for (NSString *myProductId in myProductIdArr) {
                _successBlock(nil, [NSString stringWithFormat:@"%@", myProductId]);
            }
        }
    }
    
}

#pragma mark- ---------- 私有方法
#pragma mark- ---------- 商品列表流程
// 去苹果服务器请求商品
- (void)requestProductData:(NSString *)type {
    NSLog(@"-------------- 请求对应的产品信息");
    
    NSArray *product = [[NSArray alloc] initWithObjects:type,nil];
    NSSet *nsset = [NSSet setWithArray:product];
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
    request.delegate = self;
    [request start];
}

// 收到产品返回信息
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"-------------- 收到产品反馈消息");
    
    NSArray *product = response.products;
    if ([product count] == 0) {
        NSLog(@"-------------- 没有商品");
        
        if (_failureBlock) {
            _failureBlock(nil, nil);
        }
    } else {
    
        NSLog(@"productID:%@", response.invalidProductIdentifiers);
        NSLog(@"产品付费数量:%lu",(unsigned long)[product count]);
    
        SKProduct *p = nil;
        for (SKProduct *pro in product) {
            NSLog(@"%@", [pro description]);
            NSLog(@"%@", [pro localizedTitle]);
            NSLog(@"%@", [pro localizedDescription]);
            NSLog(@"%@", [pro price]);
            NSLog(@"%@", [pro productIdentifier]);
        
            if ([pro.productIdentifier isEqualToString:_productIdentifier]) {
                p = pro;
            }
        }
    
        SKPayment *payment = [SKPayment paymentWithProduct:p];
    
        // 苹果漏单控制
        NSArray *selfProductIdArr = [[NSUserDefaults standardUserDefaults] valueForKey:SelfProductID];
        NSMutableArray *selfProductIdMuArr = [NSMutableArray arrayWithArray:selfProductIdArr];
        if (!selfProductIdArr || selfProductIdArr.count < 1) {
            selfProductIdMuArr = [NSMutableArray array];
        }
        if (_selfProductId && ![_selfProductId isKindOfClass:[NSNull class]]) {
            [selfProductIdMuArr addObject: _selfProductId];
        }
        [[NSUserDefaults standardUserDefaults] setValue:selfProductIdMuArr forKey:SelfProductID];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        NSLog(@"发送购买请求");
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

// 请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"------------------ 错误:%@", error);
    
    if (_failureBlock) {
        _failureBlock(nil, nil);
    }
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"------------ 反馈信息结束");
}


#pragma mark- --------- 购买流程
// 监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction {
    for(SKPaymentTransaction *tran in transaction) {
        NSLog(@"监听购买结果");
        
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"商品添加进列表");
                
                break;
            case SKPaymentTransactionStatePurchased:{
                NSLog(@"交易完成");
                
                [self deledateSelfProductIdForAppleStep];
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                
                // 自己校验票据控制
                NSArray *selfProductIdArr = [[NSUserDefaults standardUserDefaults] valueForKey:NetWrong];
                NSMutableArray *selfProductIdMuArr = [NSMutableArray arrayWithArray:selfProductIdArr];
                if (!selfProductIdArr || selfProductIdArr.count < 1) {
                    selfProductIdMuArr = [NSMutableArray array];
                }
                if (_selfProductId && ![_selfProductId isKindOfClass:[NSNull class]]) {
                    [selfProductIdMuArr addObject: _selfProductId];
                }
                
                [[NSUserDefaults standardUserDefaults] setValue:selfProductIdMuArr forKey:NetWrong];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // 发送到苹果服务器验证凭证
                [self verifyPurchaseWithPaymentTransaction:tran];
            }
                break;
            case SKPaymentTransactionStateFailed:{
                NSLog(@"交易失败");
                
                [self deledateSelfProductIdForAppleStep];
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                if (_failureBlock) {
                    _failureBlock(tran, tran.error);
                }
            }
                break;
            case SKPaymentTransactionStateRestored:{
                NSLog(@"已经购买过商品");
                
                [self deledateSelfProductIdForAppleStep];
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                if (_failureBlock) {
                    _failureBlock(tran, tran.error);
                }
            }
                break;
            
            case SKPaymentTransactionStateDeferred:
                NSLog(@"等待外部操作");
                break;
            default:
//                // 其他情况 统统结束
//                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
//                // 删除
//                [self deledateSelfProductIdForAppleStep];
                break;
        }
    }
}

/** 交易成功/恢复订单 结束, 删除凭证备份 */
- (void)deledateSelfProductIdForAppleStep {
    // 漏单控制 应该全删除 否则匹配最后一次订单 其他订单下次校验还会成功 容易刷单 但为保证避免多次漏单特殊情况...FUCK APPLE
    //    NSArray *selfProductIdArr = [[NSUserDefaults standardUserDefaults] valueForKey:SelfProductID];
    //    NSMutableArray *selfProductIdMuArr = [NSMutableArray arrayWithArray:selfProductIdArr];
    //    if (selfProductIdMuArr && selfProductIdMuArr.count > 0) {
    //        for (NSString *selfProductId in selfProductIdMuArr) {
    //            if ([selfProductId isEqualToString:_selfProductId]) { // 当支付确认终止时,重启恢复订单没有_selfProductId 所以全删
    //
    //                [selfProductIdMuArr removeObject:selfProductId];
    //                [[[UIAlertView alloc] initWithTitle:@"删除凭证备份" message:selfProductId delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
    //            }
    //        }
    //        [[NSUserDefaults standardUserDefaults] setValue:selfProductIdMuArr forKey:SelfProductID];
    //    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SelfProductID];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/** 交易成功/恢复订单 结束, 删除凭证备份 */
- (void)deledateSelfProductIdForNet:(NSString *)myProductId {
    
    NSArray *selfProductIdArr = [[NSUserDefaults standardUserDefaults] valueForKey:NetWrong];
    NSMutableArray *selfProductIdMuArr = [NSMutableArray arrayWithArray:selfProductIdArr];
    if (selfProductIdMuArr && selfProductIdMuArr.count > 0) {
        for (NSString *selfProductId in selfProductIdMuArr) {
            if ([selfProductId isEqualToString:myProductId]) {
                
                [selfProductIdMuArr removeObject:selfProductId];
                break;
            }
        }
        [[NSUserDefaults standardUserDefaults] setValue:selfProductIdMuArr forKey:NetWrong];
        if (selfProductIdMuArr.count < 1 && [selfProductIdMuArr.firstObject length] < 1) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey: NetWrong];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/** 验证购买 避免越狱软件模拟苹果请求达到非法购买问题 */
- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)tran {
    // 从沙盒中获取交易凭证并且拼接成请求体数据
//    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
//    NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
//    NSString *receiptStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    
    // 需服务端二次验证
    if (_successBlock) {
        _successBlock(tran, [NSString stringWithFormat:@"%@", _selfProductId]);
    }
}


- (void)removeXWObserver {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}


@end
