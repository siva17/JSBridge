//
//  JSBridge.m
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

#import <objc/runtime.h>
#import "JSBridge.h"

@interface JSBridge()
@property(nonatomic,assign) UIWebView               *jsWebView;
@property(nonatomic,assign) id<UIWebViewDelegate>   jsWebViewDelegate;
@property(nonatomic,assign) NSBundle                *resourceBundle;
@property(nonatomic,assign) JSBHandler              bridgeHandler;
@property(nonatomic,assign) long                    uniqueId;
@property(nonatomic,assign) NSUInteger              numberOfUrlRequests;

@property(nonatomic,retain) NSMutableArray          *startupMessageQueue;
@property(nonatomic,retain) NSMutableDictionary     *responseCallbacks;
@property(nonatomic,retain) NSMutableDictionary     *messageHandlers;
@property(nonatomic,retain) NSMutableDictionary     *nativeModules;
@end

@implementation JSBridge

@synthesize jsWebView;
@synthesize jsWebViewDelegate;
@synthesize resourceBundle;
@synthesize bridgeHandler;
@synthesize uniqueId;
@synthesize numberOfUrlRequests;

@synthesize startupMessageQueue;
@synthesize responseCallbacks;
@synthesize messageHandlers;

#pragma mark - Alloc-Dealloc

-(NSMutableDictionary *)nativeModules {
    if (!_nativeModules) {
        _nativeModules = [[NSMutableDictionary alloc] init];
    }
    return _nativeModules;
}

-(void)initialize {
    jsWebView.delegate  = nil;
    jsWebViewDelegate   = nil;
    resourceBundle      = nil;
    bridgeHandler       = nil;
    RELEASE_MEM(jsWebView);
    
    RELEASE_MEM(startupMessageQueue);
    RELEASE_MEM(responseCallbacks);
    RELEASE_MEM(messageHandlers);
    RELEASE_MEM(self.nativeModules);
}

-(void)dealloc {
    [self initialize];
#if __has_feature(objc_arc)
#else
    [super dealloc];
#endif
}

#pragma mark - PRIVATE APIs

-(void)dispatchMessage:(NSDictionary *)message {
    NSString *messageJSON = [JSBridge serializeMessage:message];
    JSBLog(@"JSB Action: SEND: %@",messageJSON);

    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    
    NSString* javascriptCommand = [NSString stringWithFormat:@"%@.%@('%@');",JS_BRIDGE,JS_BRIDGE_SEND_NATIVE_QUEUE,messageJSON];
    if ([[NSThread currentThread] isMainThread]) {
        [jsWebView stringByEvaluatingJavaScriptFromString:javascriptCommand];
    } else {
        __strong UIWebView* strongWebView = jsWebView;
        dispatch_sync(dispatch_get_main_queue(), ^{
            [strongWebView stringByEvaluatingJavaScriptFromString:javascriptCommand];
        });
    }
}

-(void)queueMessage:(NSDictionary *)message {
    if (startupMessageQueue) {
        [startupMessageQueue addObject:message];
    } else {
        [self dispatchMessage:message];
    }
}

-(void)flushMessageQueue {
    NSString *messageQueueString = [jsWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@.%@();",JS_BRIDGE,JS_BRIDGE_GET_JS_QUEUE]];
    
    id messages = [JSBridge deserializeMessageJSON:messageQueueString];
    if(![messages isKindOfClass:[NSArray class]]) {
        JSBLog(@"JSBridge: WARNING: Invalid %@ received: %@", [messages class], messages);
        return;
    }
    
    for (NSDictionary *message in messages) {
        if (![message isKindOfClass:[NSDictionary  class]]) {
            JSBLog(@"JSBridge: WARNING: Invalid %@ received: %@", [message class], message);
            continue;
        }
        JSBLog(@"JSB Action: RCVD: %@",message);
        
        NSString* responseId = message[@"responseId"];
        if (responseId) {
            JSBResponseCallback responseCallback = responseCallbacks[responseId];
            responseCallback(message[@"responseData"]);
            [responseCallbacks removeObjectForKey:responseId];
        } else {
            JSBResponseCallback responseCallback = NULL;
            NSString* callbackId = message[@"callbackId"];
            if (callbackId) {
                responseCallback = ^(id responseData) {
                    if (responseData == nil) {
                        responseData = [NSNull null];
                    }
                    
                    NSDictionary *msg = @{ @"responseId":callbackId, @"responseData":responseData };
                    [self queueMessage:msg];
                };
            } else {
                responseCallback = ^(id ignoreResponseData) {
                    // Do nothing
                };
            }
            
            JSBHandler handler = bridgeHandler;
            if(message[@"eventName"]) {
                handler = messageHandlers[message[@"eventName"]];
            }
            if(handler) {
                handler(message[@"data"], responseCallback);
            } else {
                JSBLog(@"JSBridge: EXCEPTION: No handler for message from JS: %@",message);
            }
        }
    }
}

-(void)processJSAPIRequest:(UIWebView *)webView param:(NSString *)param {
    
    NSArray  *components= [[param substringFromIndex:1] componentsSeparatedByString:@"&"];
    NSString *obj		= (NSString*)[components objectAtIndex:0];
    NSString *method	= [(NSString*)[components objectAtIndex:1]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *configStr	= [(NSString*)[components objectAtIndex:2]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    __unsafe_unretained NSDictionary *config = [NSJSONSerialization JSONObjectWithData:[configStr dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSObject* jsModule	= [self.nativeModules objectForKey:obj];
    
    // execute the interfacing method
    SEL selector = NSSelectorFromString(method);
    NSMethodSignature* sig = [[jsModule class] instanceMethodSignatureForSelector:selector];
    NSInvocation* invoker = [NSInvocation invocationWithMethodSignature:sig];
    invoker.selector = selector;
    invoker.target = jsModule;
    if(config) [invoker setArgument:&config atIndex:2];
    [invoker invoke];
    
    //return the value by using javascript
    if([sig methodReturnLength] > 0) {
        NSString *retValue;
        [invoker getReturnValue:&retValue];
        if(retValue) {
            retValue = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) retValue, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8));
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JSBridge.nativeReturnValue = \"%@;\"", retValue]];
        } else {
            [webView stringByEvaluatingJavaScriptFromString:@"JSBridge.nativeReturnValue=null;"];
        }
    } else {
        [webView stringByEvaluatingJavaScriptFromString:@"JSBridge.nativeReturnValue=null;"];
    }
    config = nil;
    invoker = nil;
}

#pragma mark - WebView Delegates

-(void)webViewDidStartLoad:(UIWebView *)webView {
    if(webView != jsWebView) return;
    numberOfUrlRequests++;
    
    __strong NSObject<UIWebViewDelegate>* strongDelegate = jsWebViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [strongDelegate webViewDidStartLoad:webView];
    }
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if(webView != jsWebView) return;
    numberOfUrlRequests--;
    
    __strong NSObject<UIWebViewDelegate>* strongDelegate = jsWebViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [strongDelegate webView:webView didFailLoadWithError:error];
    }
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    if(webView != jsWebView) return;
    numberOfUrlRequests--;
    
    if(numberOfUrlRequests == 0) {
        if(![[webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"typeof %@ == 'object'",JS_BRIDGE]] isEqualToString:@"true"]) {
            NSBundle *bundle = resourceBundle ? resourceBundle : [NSBundle mainBundle];
            NSString *filePath = [bundle pathForResource:JS_BRIDGE_FILE_NAME ofType:@"js"];
            NSString *js = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
            [webView stringByEvaluatingJavaScriptFromString:js];
        }
    }
    
    if (startupMessageQueue) {
        for (id queuedMessage in startupMessageQueue) {
            [self dispatchMessage:queuedMessage];
        }
        startupMessageQueue = nil;
    }
    
    __strong NSObject<UIWebViewDelegate>* strongDelegate = jsWebViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [strongDelegate webViewDidFinishLoad:webView];
    }
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if(webView != jsWebView) return YES;
    
    NSURL *url = [request URL];
    if ([[url scheme] isEqualToString:JSBRIDGE_URL_SCHEME]) {
        if ([[url host] isEqualToString:JSBRIDGE_URL_MESSAGE]) {
            NSString *param = [url relativePath];
            if([param isEqualToString:JSBRIDGE_URL_REL_PATH]) {
                [self flushMessageQueue];
            } else {
                [self processJSAPIRequest:webView param:param];
            }
        } else {
            JSBLog(@"JSBridge: WARNING: Received unknown command %@",url);
        }
        return NO;
    } else {
        __strong NSObject<UIWebViewDelegate>* strongDelegate = jsWebViewDelegate;
        if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
            return [strongDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
        }
    }
    return YES;
}

#pragma mark - PRIVATE STATIC APIs

+(NSString *)serializeMessage:(id)message {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:message options:0 error:nil] encoding:NSUTF8StringEncoding];
}

+(NSArray*)deserializeMessageJSON:(NSString *)messageJSON {
    return [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

#pragma mark - PUBLIC APIs

-(id)initWithWebView:(UIWebView*)webView webViewDelegate:(NSObject<UIWebViewDelegate>*)webViewDelegate bundle:(NSBundle*)bundle handler:(JSBHandler)handler {
    self = [super init];
    if(self) {
        [self initialize];
        
        jsWebView           = webView;
        jsWebView.delegate  = self;
        jsWebViewDelegate   = webViewDelegate;
        resourceBundle      = bundle;
        bridgeHandler       = handler;
        
        uniqueId            = 0;
        numberOfUrlRequests = 0;
        
        messageHandlers     = [NSMutableDictionary dictionary];
        startupMessageQueue = [NSMutableArray array];
        responseCallbacks   = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void)send:(NSString *)eventName data:(id)data responseCallback:(JSBResponseCallback)responseCallback {
    
    NSMutableDictionary* message = [NSMutableDictionary dictionary];
    
    if(data) message[@"data"] = data;
    if(eventName) message[@"eventName"] = eventName;
    
    if (responseCallback) {
        NSString* callbackId = [NSString stringWithFormat:@"objc_cb_%ld", ++uniqueId];
        responseCallbacks[callbackId] = [responseCallback copy];
        message[@"callbackId"] = callbackId;
    }
    
    [self queueMessage:message];

}

-(void)registerEvent:(NSString *)eventName handler:(JSBHandler)handler {
    messageHandlers[eventName] = [handler copy];
}
-(void)deRegisterEvent:(NSString *)eventName handler:(JSBHandler)handler {
    [messageHandlers removeObjectForKey:eventName];
}

-(void)registerJavaScriptAPI:(NSObject *)instance {
    [self.nativeModules setValue:instance forKey:NSStringFromClass([instance class])];
}

@end
