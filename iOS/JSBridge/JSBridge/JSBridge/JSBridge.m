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
#import "JSBridgeBase.h"

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
@synthesize nativeModules;

#pragma mark - Alloc-Dealloc

-(void)initialize {
    jsWebViewDelegate   = nil;
    resourceBundle      = nil;
    bridgeHandler       = nil;
    uniqueId            = 0;
    numberOfUrlRequests = 0;
    
    if(jsWebView) jsWebView.delegate = nil;
    RELEASE_MEM(jsWebView);
    RELEASE_MEM(startupMessageQueue);
    RELEASE_MEM(responseCallbacks);
    RELEASE_MEM(messageHandlers);
    RELEASE_MEM(nativeModules);
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
    JSBLog(@"dispatchMessage: SEND: %@",messageJSON);

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

-(NSObject *)getNativeModuleFromName:(NSString *)name {
    NSObject *nativeModule	= [nativeModules objectForKey:name];
    if(nativeModule == nil) {
        Class objClass = NSClassFromString(name);
        if(objClass) {
            @try {
                nativeModule = [(JSBridgeBase *)[objClass alloc] initWithBridge:self webView:jsWebView];
                [nativeModules setObject:nativeModule forKey:name];
                }
            @catch (NSException *exception) {
                JSBLog(@"getNativeModuleFromName: EXCEPTION: %@",name);
                nativeModule = nil;
            }
            @finally {
            }
        } else {
            JSBLog(@"getNativeModuleFromName: Unsupported Module: %@",name);
        }
    }
    return nativeModule;
}

-(void)processEventHandler:(NSDictionary *)message responseCallback:(JSBResponseCallback)responseCallback {
    NSString *eventName = message[@"eventName"];
    if(eventName) {
        JSBHandler handler = messageHandlers[eventName];
        if(!handler) {
            @try {
                // eventName is not registered and so create an instance of the API
                NSArray *api        = [eventName componentsSeparatedByString:@"."];
                NSObject *jsModule  = [self getNativeModuleFromName:(NSString*)[api objectAtIndex:0]];
                if(jsModule) {
                    
                    SEL selector            = NSSelectorFromString([NSString stringWithFormat:@"JSBEvent_%@:responseCallback:",(NSString*)[api objectAtIndex:1]]);
                    NSMethodSignature *sig  = [[jsModule class] instanceMethodSignatureForSelector:selector];
                    if(sig) {
                        NSInvocation *invoker   = [NSInvocation invocationWithMethodSignature:sig];
                        invoker.selector        = selector;
                        invoker.target          = jsModule;
                        [self registerEvent:eventName handler:^(id data, JSBResponseCallback responseCallback) {
                            NSDictionary *configData = message[@"data"];
                            if(configData) [invoker setArgument:&configData atIndex:2];
                            if(responseCallback) [invoker setArgument:&responseCallback atIndex:3];
                            [invoker invoke];
                        }];
                        
                        handler = messageHandlers[eventName];
                    } else {
                        JSBLog(@"processEventHandler: EXCEPTION: Unsupported Event: %@",eventName);
                    }
                } else {
                    JSBLog(@"processEventHandler: EXCEPTION: No Plugin: %@",eventName);
                }
            }
            @catch (NSException *exception) {
                JSBLog(@"processEventHandler: EXCEPTION: %@",eventName);
                handler = nil;
            }
            @finally {
            }
        }
        if(handler) {
            handler(message[@"data"], responseCallback);
        }
    } else {
        if(bridgeHandler) {
            bridgeHandler(message[@"data"], responseCallback);
        } else {
            JSBLog(@"processEventHandler: EXCEPTION: No handler for message from JS: %@",message);
        }
    }
}

-(void)flushMessageQueue {
    NSString *messageQueueString = [jsWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@.%@();",JS_BRIDGE,JS_BRIDGE_GET_JS_QUEUE]];
    
    id messages = [JSBridge deserializeMessageJSON:messageQueueString];
    if(![messages isKindOfClass:[NSArray class]]) {
        JSBLog(@"flushMessageQueue: WARNING: Invalid %@ received: %@", [messages class], messages);
        return;
    }
    
    for (NSDictionary *message in messages) {
        if (![message isKindOfClass:[NSDictionary  class]]) {
            JSBLog(@"flushMessageQueue: WARNING: Invalid %@ received: %@", [message class], message);
            continue;
        }
        JSBLog(@"flushMessageQueue: RCVD: %@",message);

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
            
            if(message[@"eventName"]) {
                [self processEventHandler:message responseCallback:responseCallback];
            } else {
                if(bridgeHandler) {
                    bridgeHandler(message[@"data"], responseCallback);
                } else {
                    JSBLog(@"flushMessageQueue: EXCEPTION: No handler for message from JS: %@",message);
                }
            }
        }
    }
}

-(void)processJSAPIRequest:(UIWebView *)webView param:(NSString *)param {
    
    JSBLog(@"processJSAPIRequest: RCVD: %@",param);
    
    NSArray *components = [[param substringFromIndex:1] componentsSeparatedByString:@"&"];
    
    @try {
        // execute the interfacing method
        NSArray  *api           = [(NSString*)[components objectAtIndex:0] componentsSeparatedByString:@"."];
        NSObject *jsModule      = [self getNativeModuleFromName:(NSString*)[api objectAtIndex:0]];
        
        SEL selector            = NSSelectorFromString([NSString stringWithFormat:@"JSBAPI_%@",(NSString*)[api objectAtIndex:1]]);
        NSMethodSignature *sig  = [[jsModule class] instanceMethodSignatureForSelector:selector];
        NSInvocation *invoker   = [NSInvocation invocationWithMethodSignature:sig];
        invoker.selector        = selector;
        invoker.target          = jsModule;
        NSString *configStr     = [(NSString*)[components objectAtIndex:1]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        __unsafe_unretained NSDictionary *configData = [NSJSONSerialization JSONObjectWithData:[configStr dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        if(configData) [invoker setArgument:&configData atIndex:2];
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
        configData = nil;
        invoker = nil;
    }
    @catch (NSException *exception) {
        JSBLog(@"processJSAPIRequest: EXCEPTION: %@",[components objectAtIndex:0]);
    }
    @finally {
    }
}

#pragma mark - WebView Delegates

-(void)webViewDidStartLoad:(UIWebView *)webView {
    if(webView != jsWebView) return;
    numberOfUrlRequests++;

    [jsWebView stringByEvaluatingJavaScriptFromString:@"window.isHybridMode = true"];

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
            JSBLog(@"shouldStartLoadWithRequest: WARNING: Received unknown command %@",url);
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
        messageHandlers     = [NSMutableDictionary dictionary];
        startupMessageQueue = [NSMutableArray array];
        responseCallbacks   = [NSMutableDictionary dictionary];
        nativeModules       = [NSMutableDictionary dictionary];
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

@end
