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
    NSString *messageJSON = [JSBridge stringifyJSON:message];
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

-(NSObject *)getNativeModuleFromName:(NSString *)name webView:(UIWebView *)webView {
    NSObject *nativeModule	= [nativeModules objectForKey:name];
    if(nativeModule == nil) {
        Class objClass = NSClassFromString(name);
        if(objClass) {
            @try {
                nativeModule = [[objClass alloc] initWithJSBridge:self webView:webView];
                [nativeModules setObject:nativeModule forKey:name];
                }
            @catch (NSException *exception) {
                JSBLog(@"getNativeModuleFromName: EXCEPTION: %@",name);
                nativeModule = nil;
            }
            @finally {
            }
        } else {
            JSBLog(@"Unsupported Module: %@",name);
        }
    }
    return nativeModule;
}

-(void)handleReturnValue:(NSInvocation *)invoker sig:(NSMethodSignature *)sig webView:(UIWebView *)webView apiName:(NSString *)apiName status:(BOOL)status {
    NSString *retValue = nil;
    if((invoker != nil) && (sig != nil)) {
        if([sig methodReturnLength] > 0) {
            [invoker getReturnValue:&retValue];
            if(retValue) {
                JSBLog(@"handleReturnValue:%@",retValue);
                retValue = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) retValue, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8));
            }
        }
    }
    
    NSString *dataStr = @"";
    if(status == false) retValue = [NSString stringWithFormat:@"UN-SUPPORTED API: %@",apiName];
    if(retValue) dataStr = [NSString stringWithFormat:@",'data':'%@'",retValue];
    [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JSBridge.nativeReturnValue = \"{'status':'%@'%@}\"",((status)?(@"true"):(@"false")),dataStr]];
    
    RELEASE_MEM(retValue);
}

-(void)processEventHandler:(UIWebView *)webView message:(NSDictionary *)message responseCallback:(JSBResponseCallback)responseCallback {
    NSString *eventName = message[@"eventName"];
    if(eventName) {
        JSBHandler handler = messageHandlers[eventName];
        if(!handler) {
            @try {
                // eventName is not registered and so create an instance of the API
                NSArray *api        = [eventName componentsSeparatedByString:@"."];
                NSObject *jsModule  = [self getNativeModuleFromName:(NSString*)[api objectAtIndex:0] webView:webView];
                if(jsModule) {
                    SEL selector                = NSSelectorFromString([NSString stringWithFormat:@"JSBEvent_%@:responseCallback:",(NSString*)[api objectAtIndex:1]]);
                    NSMethodSignature *sig      = [[jsModule class] instanceMethodSignatureForSelector:selector];
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
        if(handler == nil) {
            handler = ^(id data, JSBResponseCallback responseCallback) {
                if(responseCallback) {
                    responseCallback(@{@"status":@false,@"data":[NSString stringWithFormat:@"UN-SUPPORTED EVENT: %@",eventName]});
                }
            };
        }
        handler(message[@"data"], responseCallback);
    } else {
        if(bridgeHandler) {
            bridgeHandler(message[@"data"], responseCallback);
        } else {
            JSBLog(@"EXCEPTION: No handler for message from JS: %@",message);
        }
    }
}

-(void)processJSEventQueue:(UIWebView *)webView {
    NSString *messageQueueString = [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@.%@();",JS_BRIDGE,JS_BRIDGE_GET_JS_EVENT_QUEUE]];
    
    id messages = [JSBridge parseJSONArray:messageQueueString];
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
            
            [self processEventHandler:webView message:message responseCallback:responseCallback];
        }
    }
}

-(void)processJSAPIRequest:(UIWebView *)webView {
    
    NSDictionary *cData = [JSBridge parseJSON:[webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@.%@();",JS_BRIDGE,JS_BRIDGE_GET_API_DATA]]];
    NSString *apiName   = [cData objectForKey:@"api"];
    @try {
        // execute the interfacing method
        NSArray  *api       = [apiName componentsSeparatedByString:@"."];
        NSObject *jsModule  = [self getNativeModuleFromName:(NSString*)[api objectAtIndex:0] webView:webView];
        if(jsModule) {
            SEL selector            = NSSelectorFromString([NSString stringWithFormat:@"JSBAPI_%@",(NSString*)[api objectAtIndex:1]]);
            NSMethodSignature *sig  = [[jsModule class] instanceMethodSignatureForSelector:selector];
            NSInvocation *invoker   = [NSInvocation invocationWithMethodSignature:sig];
            invoker.selector        = selector;
            invoker.target          = jsModule;
            
            NSString *apiDataStr    = [cData objectForKey:@"data"];
            JSBLog(@"JSB API: RCVD: %@(%@)",api,apiDataStr);
            if(apiDataStr) {
                NSDictionary *apiData = [JSBridge parseJSON:apiDataStr];
                [invoker setArgument:&apiData atIndex:2];
            }
            [invoker invoke];
            
            [self handleReturnValue:invoker sig:sig webView:webView apiName:apiName status:true];
            RELEASE_MEM(invoker);
        } else {
            [self handleReturnValue:nil sig:nil webView:webView apiName:apiName status:false];
        }
    }
    @catch (NSException *exception) {
        JSBLog(@"processJSAPIRequest: EXCEPTION: %@",exception);
        [self handleReturnValue:nil sig:nil webView:webView apiName:apiName status:false];
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

    JSBLog(@"Received: %@",request);

    if(webView != jsWebView) return YES;
    
    NSURL *url = [request URL];
    if ([[url scheme] isEqualToString:JSBRIDGE_URL_SCHEME]) {
        if ([[url host] isEqualToString:JSBRIDGE_URL_MESSAGE]) {
            NSString *relativePath = [url relativePath];
            if([relativePath isEqualToString:JSBRIDGE_URL_EVENT_REL_PATH]) {
                [self processJSEventQueue:webView];
            } else if([relativePath isEqualToString:JSBRIDGE_URL_API_REL_PATH]) {
                [self processJSAPIRequest:webView];
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

+(NSArray*)parseJSONArray:(NSString *)messageJSON {
    return [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

+(NSDictionary *)getReturnObjectWithStatus:(BOOL)status apiName:(NSString *)apiName data:(id)data {
    NSMutableDictionary *retValue = [[NSMutableDictionary alloc] initWithObjectsAndKeys:((status)?(@"true"):(@"false")),@"status",nil];
    if(apiName) [retValue setObject:apiName forKey:@"apiName"];
    if(data) [retValue setObject:data forKey:@"data"];
    return retValue;
}
+(NSDictionary *)getReturnObjectWithStatus:(BOOL)status data:(id)data {
    return [JSBridge getReturnObjectWithStatus:status apiName:nil data:data];
}

+(void)callCallbackWithStatus:(UIWebView *)wv inJSON:(NSDictionary *)inJSON outJSON:(id)outJSON status:(BOOL)status {
    if(inJSON) {
        NSString *callbackID = [inJSON objectForKey:@"callbackID"];
        if(callbackID) {
            
            NSString *removeAfterExecute = [inJSON objectForKey:@"removeAfterExecute"];
            if(!removeAfterExecute) removeAfterExecute = @"true";
            
            NSDictionary *retObj     = [JSBridge getReturnObjectWithStatus:status data:outJSON];
            NSString *retVal         = [JSBridge stringifyJSON:retObj];
            NSString *jsAPIToExecute = [NSString stringWithFormat:@"JSBridge._invokeJSCallback(\"%@\", %@, %@);",callbackID,removeAfterExecute,retVal];
            [wv stringByEvaluatingJavaScriptFromString:jsAPIToExecute];
        }
    }
}

+(void)callEventCallback:(JSBResponseCallback)responseCallback data:(NSDictionary *)data status:(BOOL)status {
    if(responseCallback != nil) {
        responseCallback([JSBridge getReturnObjectWithStatus:status data:data]);
    }
}

#pragma mark - PUBLIC STATIC APIs

+(NSString *)stringifyJSON:(id)message {
    if([NSJSONSerialization isValidJSONObject:message]) {
        return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:message options:0 error:nil] encoding:NSUTF8StringEncoding];
    }
    return @"";
}

+(NSDictionary*)parseJSON:(NSString *)messageJSON {
    return [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

+(NSString *)getString:(NSString *)str {
    return ((str)?(str):(@""));
}

+(NSDictionary *)putKeyValue:(NSMutableDictionary *)src key:(NSString *)key value:(id)value {
    if(src == nil) src = [[NSMutableDictionary alloc]init];
    if((key != nil) && (value != nil)) [src setObject:value forKey:key];
    return src;
}

+(NSDictionary *)getReturnObject:(id)data {
    return [JSBridge getReturnObjectWithStatus:true data:data];
}

+(void)callCallbackForWebView:(UIWebView *)wv inJSON:(NSDictionary *)inJSON outJSON:(id)outJSON {
    [JSBridge callCallbackWithStatus:wv inJSON:inJSON outJSON:outJSON status:true];
}

+(void)callEventCallback:(JSBResponseCallback)responseCallback data:(id)data {
    [JSBridge callEventCallback:responseCallback data:data status:true];
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
    
    message[@"status"] = @"true";
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
