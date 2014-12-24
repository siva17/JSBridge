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
  var JSBRIDGE_URL_PARAM   = '__JSB_PARAM_NONE__';
  //!!! WARNING - Should be in SYNC with Native Code defines - End
  
  var isIOSDevice          =  /iP(hone|od|ad)/g.test(navigator.userAgent);
  var isAndroidDevice      =  /Android/g.test(navigator.userAgent);
  var sendMessageQueue     = [];
  var receiveMessageQueue  = [];
  var messageHandlers      = {};
  var responseCallbacks    = {};
  var uniqueId             = 1;
  var messagingIframe;
  
  // PRIVATE METHODS
  function logException(e,m) {
  if (typeof console != 'undefined') {
  console.error("JSBridge: EXCEPTION: ",e," : ",m);
  }
  }
  
  function callNativeAPI(obj,functionName,config,responseCallback) {
  var argStr = "";
  if(config) {
  if(responseCallback) {
  var cbID = "cbID" + (+new Date);
  responseCallbacks[cbID] = responseCallback;
  config["callbackID"] = cbID;
  }
  argStr += encodeURIComponent(JSON.stringify(config));
  }
  
  // Should not called triggerNativeCall as iFrame needs to be deleted in order to get the retvalue.
  var iframe = document.createElement("IFRAME");
  iframe.setAttribute("src", JSBRIDGE_URL_SCHEME + '://' + JSBRIDGE_URL_MESSAGE + '/' + obj + "&" + encodeURIComponent(functionName) + "&" + encodeURIComponent(argStr));
  document.documentElement.appendChild(iframe);
  iframe.parentNode.removeChild(iframe);
  iframe = null;
  
  var ret = JSBridge.nativeReturnValue;
  JSBridge.nativeReturnValue = undefined;
  if(ret) return decodeURIComponent(ret);
  };
  
  function triggerNativeCall(param) {
  if(isIOSDevice) {
  messagingIframe.src = JSBRIDGE_URL_SCHEME + '://' + JSBRIDGE_URL_MESSAGE + '/'+ ((param)?(param):(JSBRIDGE_URL_PARAM));
  } else if(isAndroidDevice) {
  try {
  var api = eval("Android.NativeAPI");
  if(api) api(_fetchJSQueue());
  } catch(e) {}
  } else {
  try {
  var api = eval("WebApp.NativeAPI");
  if(api) api(_fetchJSQueue());
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
             handler(message.data, responseCallback);
             } catch(e) {
             logException(e,"dispatchMessageFromNative");
             }
             }
             });
  }
  
  // PUBLIC METHODS
  function init(bridgeHandler) {
  if(JSBridge.bridgeHandler){logException(e,"init");}
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
  var api = eval(name);
  if(api) {
  if(isAndroidDevice) {
  if(responseCallback) {
  var cbID = 'cbID' + (+new Date);
  responseCallbacks[cbID] = responseCallback;
  data.callbackID = cbID;
  }
  try{
  data = JSON.stringify(data);
  }catch(e){}
  }
  return api(data,responseCallback);
  } else {
  logException("Unsupported API:",name);
  }
  } catch(e) {
  logException(e,"Invalid API:"+name);
  }
  }
  
  function _fetchJSQueue() {
  try {
  var messageQueueString = JSON.stringify(sendMessageQueue);
  sendMessageQueue = [];
  return messageQueueString;
  } catch(e) {
  logException(e,"_fetchJSQueue");
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
  
  function _registerObjCJSModule(obj,methods) {
  w[obj] = {};
  var jsObj = w[obj];
  
  for(var i=0, l=methods.length; i<l; i++) {
  (function (){
   var method = methods[i];
   var jsMethod = method.replace(new RegExp(":", "g"), "");
   jsObj[jsMethod] = function() {
   return callNativeAPI(obj,method,arguments[0],arguments[1]);
   };
   })();
  }
  };
  
  
  w.JSBridge = {
		init    : init,
  callAPI : callAPI,
		send    : send,
  
		registerEvent   : registerEvent,
  deRegisterEvent : deRegisterEvent,
  
		_fetchJSQueue           : _fetchJSQueue,
		_handleMessageFromNative: _handleMessageFromNative,
  
  _invokeJSCallback       : _invokeJSCallback,
  _registerObjCJSModule   : _registerObjCJSModule
  }
  
  messagingIframe = doc.createElement('iframe');
  messagingIframe.style.display = 'none';
  messagingIframe.src = JSBRIDGE_URL_SCHEME + '://' + JSBRIDGE_URL_MESSAGE + '/' + JSBRIDGE_URL_PARAM;
  doc.documentElement.appendChild(messagingIframe);
  
  var readyEvent = doc.createEvent('Events');
  readyEvent.initEvent('JSBridgeReady');
  readyEvent.bridge = JSBridge;
  doc.dispatchEvent(readyEvent);
  
  })(window,document);