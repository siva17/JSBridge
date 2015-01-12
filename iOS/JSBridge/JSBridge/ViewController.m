//
//  ViewController.m
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

#import "ViewController.h"
#import "JSBridge.h"

@interface ViewController ()
@property(nonatomic,retain) UIWebView   *jsbWebView;
@property(nonatomic,retain) JSBridge    *bridge;
@end

@implementation ViewController

@synthesize jsbWebView;
@synthesize bridge;

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    if(jsbWebView.hidden == YES) {
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.0); //??? Open after 0 second loading is completed to avoid flicker
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            jsbWebView.hidden = NO;
        });
    }
}

-(void)loadIndexFile {
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"];
    NSString* appHtml = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
    [NSHTTPCookieStorage sharedHTTPCookieStorage].cookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    [jsbWebView loadHTMLString:appHtml baseURL:baseURL];
}

-(void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    jsbWebView = [[UIWebView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    jsbWebView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin |
                                  UIViewAutoresizingFlexibleTopMargin |
                                  UIViewAutoresizingFlexibleRightMargin |
                                  UIViewAutoresizingFlexibleLeftMargin |
                                  UIViewAutoresizingFlexibleHeight |
                                  UIViewAutoresizingFlexibleWidth;
    jsbWebView.hidden = YES;
    jsbWebView.scrollView.bounces = NO;
    [self.view addSubview:jsbWebView];
    
    bridge = [[JSBridge alloc]initWithWebView:jsbWebView webViewDelegate:self bundle:nil handler:^(id data, JSBResponseCallback responseCallback) {
        JSBLog(@"ObjC received message from JS after initialization: %@", data);
        responseCallback(@"Response for message from ObjC");
    }];
    [bridge registerEvent:@"testObjcCallback" handler:^(id data, JSBResponseCallback responseCallback) {
        JSBLog(@"testObjcCallback called: %@", data);
        responseCallback(@"Response from testObjcCallback");
    }];
    
    [bridge send:nil data:@"A string sent from ObjC before Webview has loaded." responseCallback:^(id responseData) {
        JSBLog(@"objc got response! %@", responseData);
    }];
    
    [bridge send:@"testJavascriptHandler" data:@{ @"foo":@"before ready" } responseCallback:nil];
    
    [self loadIndexFile];
    
    [bridge send:nil data:@"A string sent from ObjC after Webview has loaded." responseCallback:nil];    
}

-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
