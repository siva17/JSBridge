//
//  JSBIncludes.h
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

#import <Foundation/Foundation.h>
#import <UIKit/UIWebView.h>

#ifndef JSBridge_JSBIncludes_h
#define JSBridge_JSBIncludes_h

#if __has_feature(objc_arc)
#define RELEASE_MEM(ptr) ptr = nil;
#else
#define RELEASE_MEM(ptr) if(ptr) [ptr release]; ptr = nil;
#endif

//!!! WARNING - Should be in SYNC with Native Code defines - Begin
#define JSBRIDGE_URL_SCHEME         @"jsbridgeurlscheme"
#define JSBRIDGE_URL_MESSAGE        @"__JSB_URL_MESSAGE__"
#define JSBRIDGE_URL_PARAM          @"__JSB_PARAM_NONE__"
//!!! WARNING - Should be in SYNC with Native Code defines - End
#define JSBRIDGE_URL_REL_PATH       [NSString stringWithFormat:@"/%@",JSBRIDGE_URL_PARAM]

#define JS_BRIDGE_FILE_NAME         @"JSBridge"
#define JS_BRIDGE                   @"JSBridge"
#define JS_BRIDGE_GET_JS_QUEUE      @"_fetchJSQueue"
#define JS_BRIDGE_SEND_NATIVE_QUEUE @"_handleMessageFromNative"

#define JSB_LOG_ENABLE              1
#define JSB_LOG_SIMPLE				1

#ifdef JSB_LOG_ENABLE
#if(JSB_LOG_SIMPLE == 1)
#define JSBLog(s, ...) NSLog(@"JSBridge: %@\n", [NSString stringWithFormat:(s), ## __VA_ARGS__]);
#else
#define JSBLog(s, ...) NSLog(@"\t<%p %@:(%d)>\t%@\n", self, [[NSString stringWithUTF8String:__FUNCTION__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ## __VA_ARGS__]);
#endif
#else
#define JSBLog(s, ...)
#endif

typedef void (^JSBResponseCallback)(id responseData);
typedef void (^JSBHandler)(id data, JSBResponseCallback responseCallback);

#endif
