//
//  TestAPIOne.m
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
#import "TestAPIOne.h"

@implementation TestAPIOne

-(void)APIOne {
    NSLog(@"Called APIOne. Function with No Config Parameter and no return value");
}
-(void)APITwo:(NSDictionary *)config {
    NSLog(@"Called APITwo. Function with Config Parameter and no return value");
    NSLog(@"Config : %@",config);
}

-(NSString *)APIThree:(NSDictionary *)config {
    NSLog(@"Called APIThree. Function with Config Parameter and has string return value");
    NSLog(@"Config : %@",config);
    return @"Success of APIThree";
}

-(void)APIFour:(NSDictionary *)config {
    NSLog(@"Called APIFour. Function with Config Parameter with call back and no return value");
    NSLog(@"Config : %@",config);
    NSMutableDictionary *returnConfig = [[NSMutableDictionary alloc]initWithDictionary:config];
    [returnConfig setObject:@"Returned Value" forKey:@"returned"];
    [self callCallback:returnConfig];
}

-(NSString *)APIFive:(NSDictionary *)config {
    NSLog(@"Called APIFive. Function with Config Parameter with call back and has string return value");
    NSLog(@"Config : %@",config);
    [self callCallback:config];
    return @"Success Of APIFive";
}

-(void)APISix:(NSDictionary *)config {
    NSLog(@"Called APISix. Function with Config Parameter with Async call back and no return value");
    NSLog(@"Config : %@",config);
    dispatch_queue_t myQueue = dispatch_queue_create("My Queue",NULL);
    dispatch_async(myQueue, ^{
        NSLog(@"Start of the Process");
        
        for (int i=0; i<50000; i++) {
//            NSString *temp = [NSString stringWithFormat:@"STR:%d",i];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callCallback:config];
            NSLog(@"End of the Process");
        });
    });
}

-(NSString *)APISeven:(NSDictionary *)config {
    NSLog(@"Called APISeven. Function with Config Parameter with Async call back and has string return value");
    NSLog(@"Config : %@",config);
    
    dispatch_queue_t myQueue = dispatch_queue_create("My Queue",NULL);
    dispatch_async(myQueue, ^{
        NSLog(@"Start of the Process");

        for (int i=0; i<50000; i++) {
//            NSString *temp = [NSString stringWithFormat:@"STR:%d",i];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callCallback:config];
            NSLog(@"End of the Process");
        });
    });
    
    NSLog(@"Returned Value");
    return @"Success Of APISeven";
}

@end
