//
//  Test.m
//  JSBridge
//
//  Created by Siva RamaKrishna Ravuri
//  Copyright (c) 2014 www.siva4u.com. All rights reserved.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//

#import "Test.h"

@interface Test()
@property(nonatomic,retain) MKMapView	*mapView;
@end

@implementation Test

@synthesize mapView;

-(void)initialize {
    if(mapView) mapView.delegate = nil;
    RELEASE_MEM(mapView);
}

-(void)dealloc {
    [self initialize];
#if __has_feature(objc_arc)
#else
    [super dealloc];
#endif
}

-(void)JSBEvent_showMap:(NSDictionary *)details responseCallback:(JSBResponseCallback)responseCallback {
    if(mapView == nil) {
        mapView = [[MKMapView alloc]initWithFrame:CGRectMake(0,0,0,0)];
        if(mapView) {
            [self.jsbWebView addSubview:mapView];
            mapView.hidden = YES;
        }
    }
    if(details) {
		NSDictionary *mapDetails = [[NSDictionary alloc]initWithDictionary:details];
        
        CGRect frame;
        NSDictionary *position = [mapDetails objectForKey:@"position"];
        if(position) {
            frame = CGRectMake([(NSString *)position[@"x"] integerValue],
                               [(NSString *)position[@"y"] integerValue],
                               [(NSString *)position[@"width"] integerValue],
                               [(NSString *)position[@"height"] integerValue]);
        } else {
            frame = CGRectMake(10, 10, 100, 100);
        }
        [mapView setFrame:frame];
    }
    if(mapView) mapView.hidden = NO;
}

-(void)JSBEvent_hideMap:(NSDictionary *)details responseCallback:(JSBResponseCallback)responseCallback {
    if(mapView) mapView.hidden = YES;
}

-(void)JSBAPI_APIOne {
    JSBLog(@"Called APIOne. Function with No Config Parameter and no return value");
}
-(void)JSBAPI_APITwo:(NSDictionary *)config {
    JSBLog(@"Called APITwo. Function with Config Parameter and no return value");
    JSBLog(@"Config : %@",config);
}

-(NSString *)JSBAPI_APIThree:(NSDictionary *)config {
    JSBLog(@"Called APIThree. Function with Config Parameter and has string return value");
    JSBLog(@"Config : %@",config);
    return @"Returned data from APIThree";
}

-(void)JSBAPI_APIFour:(NSDictionary *)config {
    JSBLog(@"Called APIFour. Function with Config Parameter with call back and no return value");
    JSBLog(@"Config : %@",config);
    NSMutableDictionary *returnConfig = [[NSMutableDictionary alloc]initWithDictionary:config];
    [returnConfig setObject:@"Returned Value" forKey:@"returned"];
    [JSBridge callCallbackForWebView:self.jsbWebView inJSON:config outJSON:[JSBridge putKeyValue:nil key:@"callBackData" value:@"Success from APIFour"]];
}

-(NSString *)JSBAPI_APIFive:(NSDictionary *)config {
    JSBLog(@"Called APIFive. Function with Config Parameter with call back and has string return value");
    JSBLog(@"Config : %@",config);
    [JSBridge callCallbackForWebView:self.jsbWebView inJSON:config outJSON:[JSBridge putKeyValue:nil key:@"callBackData" value:@"Success from APIFive"]];
    return @"Returned data from APIFive";
}

-(void)JSBAPI_APISix:(NSDictionary *)config {
    JSBLog(@"Called APISix. Function with Config Parameter with Async call back and no return value");
    JSBLog(@"Config : %@",config);
    dispatch_queue_t myQueue = dispatch_queue_create("My Queue",NULL);
    dispatch_async(myQueue, ^{
        JSBLog(@"Start of the Process");
        
        for (int i=0; i<50000; i++) {
//            NSString *temp = [NSString stringWithFormat:@"STR:%d",i];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [JSBridge callCallbackForWebView:self.jsbWebView inJSON:config outJSON:[JSBridge putKeyValue:nil key:@"callBackData" value:@"Success from APISix"]];
            JSBLog(@"End of the Process");
        });
    });
}

-(NSString *)JSBAPI_APISeven:(NSDictionary *)config {
    JSBLog(@"Called APISeven. Function with Config Parameter with Async call back and has string return value");
    JSBLog(@"Config : %@",config);
    
    dispatch_queue_t myQueue = dispatch_queue_create("My Queue",NULL);
    dispatch_async(myQueue, ^{
        JSBLog(@"Start of the Process");

        for (int i=0; i<50000; i++) {
//            NSString *temp = [NSString stringWithFormat:@"STR:%d",i];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [JSBridge callCallbackForWebView:self.jsbWebView inJSON:config outJSON:[JSBridge putKeyValue:nil key:@"callBackData" value:@"Success from APISeven"]];
            JSBLog(@"End of the Process");
        });
    });
    
    JSBLog(@"Returned Value");
    return @"Returned data from APISeven";
}

-(void)JSBEvent_testNativeEvent:(NSDictionary *)data responseCallback:(JSBResponseCallback)responseCallback {
    JSBLog(@"TestAPIOne.testNativeEvent called with data:%@ and responceCallback:%@",data,responseCallback);
    [JSBridge callEventCallback:responseCallback data:@"Response from TestAPIOne.testNativeEvent"];
}

@end
