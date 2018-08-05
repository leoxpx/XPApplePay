//
//  ViewController.m
//  ApplePay
//
//  Created by 许墨 on 2018/8/3.
//  Copyright © 2018年 XTeam. All rights reserved.
//

#import "ViewController.h"
#import "XWIPAManager.h"

@interface ViewController ()

@property(nonatomic, strong) NSString *appleStoreOrderId; // 价格ID
@property(nonatomic, strong) NSString *localOrderId; // 服务器订单ID

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)payClickNew {
    // 请勿重复提交
        
        [[XWIPAManager ShareManager] startBuyRequest:self.appleStoreOrderId selfProductId:self.localOrderId success:^(SKPaymentTransaction *transaction, NSString *selfProductId) {
            
            
            
        } failure:^(SKPaymentTransaction *transaction, NSError *error) {
            if (!error) {
                // 未找到商品信息, 请稍后再试
            } else {
                // 交易未能完成
            }
        }];
}

// 给后台校验
- (void)passThePayment {
    
    // 校验成功
    [[XWIPAManager ShareManager] deledateSelfProductIdForNet:self.localOrderId];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
