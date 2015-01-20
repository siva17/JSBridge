//
//  JSBridge.js
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

;(function(w,doc) {
    if(w.JSBridge)return;

// PRIVATE VARIABLES
    //!!! WARNING - Should be in SYNC with Native Code defines - Begin
    var JSBRIDGE_URL_SCHEME  = 'jsbridgeurlscheme';
    var JSBRIDGE_URL_MESSAGE = '__JSB_URL_MESSAGE__';
    var JSBRIDGE_URL_EVENT   = '__JSB_URL_EVENT__';
    var JSBRIDGE_URL_API     = '__JSB_URL_API__';
  
    //!!! WARNING - Should be in SYNC with Native Code defines - End
  
    var ua                  = navigator.userAgent;
    var isIOSDevice         = /iP(hone|od|ad)/g.test(ua);
    var isAndroidDevice     = /Android/g.test(ua);
    var sendMessageQueue    = [];
    var receiveMessageQueue = [];
    var messageHandlers     = {};
    var responseCallbacks   = {};
    var apiData             = null;
    var uniqueId            = 1;
    var messagingIframe;

// PRIVATE METHODS

    function JSBridgeLog() {
        if (typeof console != 'undefined') {
            console.log("JSBridge:JS: LOG: ",arguments);
        }
    }
    function JSBridgeLogException(e,m) {
        if (typeof console != 'undefined') {
            console.error("JSBridge:JS: EXCEPTION: ",arguments);
        }
    }

    function getIFrameSrc(param) {
        return JSBRIDGE_URL_SCHEME + '://' + JSBRIDGE_URL_MESSAGE + '/'+ param;
    }

    function callObjCAPI(name,data) {
        // Should not called triggerNativeCall as iFrame needs to be deleted in order to get the retvalue.
        var iframe = document.createElement("IFRAME");
        apiData = {api:name};
        if(data) apiData["data"] = data;
        iframe.setAttribute("src", getIFrameSrc(JSBRIDGE_URL_API));
        document.documentElement.appendChild(iframe);
        iframe.parentNode.removeChild(iframe);
        iframe = null;

        var ret = JSBridge.nativeReturnValue;
        JSBridge.nativeReturnValue = undefined;
        if(ret) return decodeURIComponent(ret);
    };

    function triggerNativeCall() {
        if(isIOSDevice) {
            messagingIframe.src = getIFrameSrc(JSBRIDGE_URL_EVENT);
        } else {
            var apiName = ((isAndroidDevice)?("AndroidAPI.ProcessJSEventQueue"):("WebAppAPI.ProcessJSEventQueue"));
            try {
                var api = eval(apiName);
                if(api) api(_fetchJSEventQueue());
            } catch(e) {}
        }
    }

    function doSend(message, responseCallback) {
        if (responseCallback) {
            var callbackId = 'cb_' + (uniqueId++) + '_' + new Date().getTime();
            responseCallbacks[callbackId] = responseCallback;
            message['callbackId'] = callbackId;
        }
        sendMessageQueue.push(message);
        triggerNativeCall();
    }

    function dispatchMessageFromNative(messageJSON) {
        setTimeout(function _timeoutDispatchMessageFromObjC() {
            var message = JSON.parse(messageJSON);
            var messageHandler;
            var responseCallback;

            if (message.responseId) {
                responseCallback = responseCallbacks[message.responseId];
                if(!responseCallback){return;}
                responseCallback(message.responseData);
                delete responseCallbacks[message.responseId];
            } else {
                if (message.callbackId) {
                    var callbackResponseId = message.callbackId;
                    responseCallback = function(responseData) {
                        doSend({responseId:callbackResponseId, responseData:responseData});
                    }
                }
                
                try {
                    var handler = ((message.eventName)?(messageHandlers[message.eventName]):(JSBridge.bridgeHandler));
                    if(handler) {
                    	handler(message.data, responseCallback);
                    }
                } catch(e) {
                    JSBridgeLogException(e,"dispatchMessageFromNative");
                }
            }
        });
    }

// PUBLIC METHODS
    function init(bridgeHandler) {
        if(JSBridge.bridgeHandler){JSBridgeLogException(e,"init");}
        JSBridge.bridgeHandler  = bridgeHandler;
        var receivedMessages    = receiveMessageQueue;
        receiveMessageQueue     = null;
        for(var i=0; i<receivedMessages.length; i++) {
            dispatchMessageFromNative(receivedMessages[i]);
        }
    }

    function send(eventName, data, responseCallback) {
        var dataToSend = {};
        if(eventName) dataToSend["eventName"] = eventName;
        if(data) dataToSend["data"] = data;
        doSend(dataToSend, responseCallback);
    }

    function registerEvent(eventName, handler) {
        messageHandlers[eventName] = handler;
    }

    function deRegisterEvent(eventName, handler) {
        if(messageHandlers[eventName]) {
            delete messageHandlers[eventName];
        }
    }

    function callAPI(name, data, responseCallback) {
        try {
            if(data) {
                if(responseCallback) {
                    var cbID = "cbID" + (+new Date);
                    responseCallbacks[cbID] = responseCallback;
                    data["callbackID"] = cbID;
                }
                try{data = JSON.stringify(data);}catch(e){}
            }

            if(isIOSDevice) {
                if(data) name += ":";
                return callObjCAPI(name,data);
            } else {
                var api = eval((isAndroidDevice)?("AndroidAPI.ProcessJSAPIRequest"):("WebAppAPI.ProcessJSAPIRequest"));
                if(api) {
                	if(data) return api(name,data);
                	return api(name,null);
                } else {
	                JSBridgeLogException("Unsupported API:",name);
                }
			}
        } catch(e) {
            JSBridgeLogException(e,"Invalid API:"+name);
        }
    }
  
    function _fetchJSEventQueue() {
        try {
            var messageQueueString = JSON.stringify(sendMessageQueue);
            sendMessageQueue = [];
            return messageQueueString;
        } catch(e) {
            JSBridgeLogException(e,"_fetchJSEventQueue");
        }
        return [];
    }

    function _handleMessageFromNative(messageJSON) {
        if(receiveMessageQueue) {
            receiveMessageQueue.push(messageJSON);
        } else {
            dispatchMessageFromNative(messageJSON);
        }
    }

    function _getAPIData() { return JSON.stringify(apiData); }
  
    function _invokeJSCallback(cbID,removeAfterExecute,config) {
        if(cbID) {
            var cb = responseCallbacks[cbID];
            if(cb) {
                if(removeAfterExecute) delete(responseCallbacks[cbID]);
                var data = config;
                if(isAndroidDevice) {
                    try {data = JSON.parse(config);}catch(e){}
                }
                if(data.callbackID) delete(data.callbackID);
                cb.call(null, data);
            }
        }
    };

	w.JSBridge = {
		init    : init,
		send    : send,
        callAPI : callAPI,
  
		registerEvent   : registerEvent,
        deRegisterEvent : deRegisterEvent,
  
		_fetchJSEventQueue      : _fetchJSEventQueue,
		_handleMessageFromNative: _handleMessageFromNative,
        _getAPIData             : _getAPIData,
        _invokeJSCallback       : _invokeJSCallback,
    }

    messagingIframe = doc.createElement('iframe');
    messagingIframe.style.display = 'none';
    triggerNativeCall();
    doc.documentElement.appendChild(messagingIframe);

    var readyEvent = doc.createEvent('Events');
    readyEvent.initEvent('JSBridgeReady');
    readyEvent.bridge = JSBridge;
    doc.dispatchEvent(readyEvent);

})(window,document);
