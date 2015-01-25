package com.siva4u.jsbridge;

import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Bitmap;
import android.os.Build;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.webkit.WebViewClient;

@SuppressLint({ "NewApi", "SetJavaScriptEnabled", "JavascriptInterface", "SdCardPath" })
public class JSBridge {

    public static final String JS_BRIDGE_FILE_NAME			= "JSBridge.js";
    public static final String JS_BRIDGE					= "JSBridge";
    public static final String JS_BRIDGE_SEND_NATIVE_QUEUE	= "_handleMessageFromNative";
    public static final String JS_API_BASE_PACKAGE			= "com.siva4u.example.";
    public static final String JS_API_PREFIX_FOR_API		= "JSBAPI_";
    public static final String JS_API_PREFIX_FOR_EVENT		= "JSBEvent_";

    private Context				context					= null;
    private WebView				webView					= null;
    private JSBridgeInteface    jsWebViewInterface		= null;
    private JSBridgeHandler		jsBridgeHandler			= null;
    private int					uniqueId				= 0;
    private JSONArray			startupMessageQueue		= new JSONArray();
    private JSONObject			responseCallbacks		= new JSONObject();
    private JSONObject			jsEventNativeHandlers	= new JSONObject();
    private JSONObject			nativeModules			= new JSONObject();

    public static void Log(String className, String methodName, String str) {
        System.out.println("JSBridge:["+className+"."+methodName+"]: "+str);
    }

    public static String getString(JSONObject obj, String forKey) {
        try {
        	if(obj != null) {
	            if(forKey != null) return obj.get(forKey).toString();
	            else return obj.toString();
        	}
        } catch (JSONException e) {}
        return null;
    }
    public static String getString(JSONObject obj) {
        return getString(obj, null);
    }
    
    public static JSONObject putKeyValue(JSONObject obj, String key, String value) {
    	if((key != null) && (value != null)) {
    		try {
    			if(obj == null) obj = new JSONObject();
				obj.put(key, value);
			} catch (JSONException e) {}
    	}
    	return obj;
    }
    public static JSONObject putKeyValue(JSONObject obj, String key, Object value) {
    	if((key != null) && (value != null)) {
    		try {
    			if(obj == null) obj = new JSONObject();
				obj.put(key, value);
			} catch (JSONException e) {}
    	}
    	return obj;
    }
    public static JSONObject putKeyValue(JSONObject obj, String key, JSONObject value) {
    	if((key != null) && (value != null)) {
    		try {
    			if(obj == null) obj = new JSONObject();
				obj.put(key, value);
			} catch (JSONException e) {}
    	}
    	return obj;
    }
    public static JSONObject getJSONObject(String str) {
        try {
        	if(str != null) return new JSONObject(str);
        } catch (JSONException e) {}
        return null;
    }
    public static JSONObject getJSONObjectForKey(JSONObject obj, String key) {
    	try {
    		if((obj != null) && (key != null)) return obj.getJSONObject(key);
        } catch (JSONException e) {}
    	return null;
    }
    public static Object getObjectFromJSONObject(JSONObject obj, String key) {
    	if((obj == null) || (key == null)) return null;
    	try {
    		return obj.get(key);
        } catch (JSONException e) {}
    	return null;
    }
    public static JSONObject updateJsonObject(JSONObject obj, String key, String value) {
        try {
            if((obj != null) && (key != null) && (value != null)) return obj.put(key,value);
        } catch (JSONException e) {}
        return obj;
    }
    public static JSONObject updateJsonObject(JSONObject obj, String key, JSONObject value) {
        try {
            if((obj != null) && (key != null) && (value != null)) return obj.put(key,value);
        } catch (JSONException e) {}
        return obj;
    }
    public static JSONObject updateJsonObject(JSONObject obj, String key, Object value) {
        try {
            if((obj != null) && (key != null) && (value != null)) return obj.put(key,value);
        } catch (JSONException e) {}
        return obj;
    }

    public static void callEventCallback(JSBridgeCallback responseCallback, String dataStr) {
    	if(responseCallback != null) {
    		responseCallback.callBack(getReturnObject(null, "true", dataStr));
    	}
    }
    public static void callEventCallback(JSBridgeCallback responseCallback, JSONObject dataJson) {
    	if(responseCallback != null) {
    		responseCallback.callBack(getReturnObject(null,"true", dataJson));
    	}
    }
    
    public static JSONObject callAPICallback(final WebView wv, JSONObject inJsonObj, JSONObject outJsonObj) {
    	return callAPICallback(wv, inJsonObj, outJsonObj, "true");
    }
    public static JSONObject callAPICallback(final WebView wv, JSONObject inJsonObj, String outJsonStr) {
    	return callAPICallback(wv, inJsonObj, outJsonStr, "true");
    }    

    private final String getAssetFileContents(String fileName) {
        String contents = "";
        try {
            InputStream stream = context.getAssets().open(fileName);
            byte[] buffer = new byte[stream.available()];
            stream.read(buffer);
            stream.close();
            contents = new String(buffer);
        } catch (IOException e) {}
        return contents;
    }
    private static JSONObject getReturnObject(String apiName, String status, JSONObject inJsonObj) {
    	JSONObject outJsonObj = new JSONObject();
    	putKeyValue(outJsonObj, "status", status);
    	if(apiName != null) putKeyValue(outJsonObj, "apiName", apiName);
    	if(inJsonObj != null) putKeyValue(outJsonObj, "data", inJsonObj);
    	return outJsonObj;
    }
    private static JSONObject getReturnObject(String apiName, String status, String inStr) {
    	JSONObject outJsonObj = new JSONObject();
    	putKeyValue(outJsonObj, "status", status);
    	if(apiName != null) putKeyValue(outJsonObj, "apiName", apiName);
    	if(inStr != null) putKeyValue(outJsonObj, "data", inStr);
    	return outJsonObj;
    }    
    private static void callEventCallback(JSBridgeCallback responseCallback, String dataStr, String supportStatus) {
    	if(responseCallback != null) {
    		responseCallback.callBack(getReturnObject(null,supportStatus, dataStr));
    	}
    }
    private static JSONObject callAPICallback(final WebView wv, JSONObject inJsonObj, String outJsonObj, String supportStatus) {
    	return callAPICallbackComplete(wv, inJsonObj, JSBridge.getReturnObject(null,supportStatus, outJsonObj));
    }
    private static JSONObject callAPICallback(final WebView wv, JSONObject inJsonObj, JSONObject outJsonObj, String supportStatus) {
    	return callAPICallbackComplete(wv, inJsonObj, JSBridge.getReturnObject(null,supportStatus, outJsonObj));
    }  
    private static JSONObject callAPICallbackComplete(final WebView wv, JSONObject inJsonObj, final JSONObject outJsonObj) {
        final String callbackID = JSBridge.getString(inJsonObj, "callbackID");
        if(callbackID != null) {
            String str = JSBridge.getString(inJsonObj, "removeAfterExecute");
            if(str == null) str = "true";
            final String removeAfterExecute = str;
            wv.post(new Runnable() {
                @Override
                public void run() {
                	wv.loadUrl("javascript: JSBridge._invokeJSCallback('"+callbackID+"',"+removeAfterExecute+",'"+outJsonObj.toString()+"');");
                }
            });
        }
        return outJsonObj;
    }
    private JSBridgeHandler getMessageHandler(String eventName) {    
	    if(eventName != null) {
	    	try {
		        return (JSBridgeHandler) jsEventNativeHandlers.get(eventName);
	        } catch (JSONException e) {}
	    }
	    return null;
    }
    private class JSBridgeWebViewClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            if(jsWebViewInterface != null) {
                jsWebViewInterface.shouldOverrideUrlLoading(view, url);
            }
            return false;
        }
        @Override
        public void onPageStarted (WebView view, String url, Bitmap favicon) {
            if(jsWebViewInterface != null) {
                jsWebViewInterface.onPageStarted(view, url, favicon);
            }
        }
        @Override
        public void onPageFinished(WebView view, String url) {
            if(startupMessageQueue != null) {
                int queueCount = startupMessageQueue.length();
                if(queueCount > 0) {
                    for (int i = 0; i < queueCount; i++) {
                        try {
                            dispatchMessage(startupMessageQueue.getString(i));
                        } catch (JSONException e) {}
                    }
                }
                startupMessageQueue = null;
            }
            if(jsWebViewInterface != null) {
                jsWebViewInterface.onPageFinished(view,url);
            }
        }
    }

    private class AndroidAPI extends JSBridgeBase {
        public AndroidAPI(Context c, WebView view) {
            super(c, view);
        }

        private JSBridgeBase getInstance(String name) {
    		String className = name.split("\\.")[0];        		    		
    		JSBridgeBase classIntance = (JSBridgeBase) getObjectFromJSONObject(nativeModules,className);    		
    		if(classIntance == null) {
    			try {
					Class<?> apiClass = Class.forName(JS_API_BASE_PACKAGE+className);
					if(apiClass != null) {
						Constructor<?> cons = apiClass.getConstructor(Context.class, WebView.class);
						if(cons != null) {
							try {
								Object instance = cons.newInstance(new Object[] { webViewContext,webView });
								if(instance != null) {
									classIntance = (JSBridgeBase) instance;
									nativeModules.put(className, classIntance);
								}
							} catch (InstantiationException e) {
							} catch (IllegalAccessException e) {
							} catch (IllegalArgumentException e) {
							} catch (InvocationTargetException e) {
							} catch (JSONException e) {}
						}
					}
				} catch (NoSuchMethodException e) {
				} catch (ClassNotFoundException e) {}
    		}
        	return classIntance;
        }
        
        private Method getMethod(JSBridgeBase classIntance, String type, String name, JSONObject data) {
			Method thisMethod = null;
    		try {
				String methodName = type + name.split("\\.")[1];
				if(type == JS_API_PREFIX_FOR_EVENT) {
					thisMethod = classIntance.getClass().getMethod(methodName, JSONObject.class, JSBridgeCallback.class);
				} else if(type == JS_API_PREFIX_FOR_API) {
    				if(data != null) {
    					thisMethod = classIntance.getClass().getMethod(methodName, JSONObject.class);
    				} else {
    					thisMethod = classIntance.getClass().getMethod(methodName);
    				}
				}
			} catch (NoSuchMethodException e) {}
    		return thisMethod;
        }
        
        private JSONObject invokeMethod(String type, String name, JSONObject data, JSBridgeCallback responseCallback) {
    		JSBridge.Log("JSBridge","invokeMethod", "API:"+name+", data: "+data+" and responseCallback:"+responseCallback);
    		if(name == null) return null;
    		    		
    		JSBridgeBase classIntance = getInstance(name);
    		if(classIntance != null) {
				Method thisMethod = getMethod(classIntance, type, name, data);
				if(thisMethod != null) {
					try {
						JSONObject retVal = new JSONObject();
						if(type == JS_API_PREFIX_FOR_EVENT) {
							putKeyValue(retVal, "1", thisMethod.invoke(classIntance,data,responseCallback));
						} else if(type == JS_API_PREFIX_FOR_API) {
    						if(data != null) {
    							putKeyValue(retVal, "1", thisMethod.invoke(classIntance,data));
    						} else {
    							putKeyValue(retVal, "1", thisMethod.invoke(classIntance));
    						}
						}
						putKeyValue(retVal, "0","TRUE"); 
						return retVal;
					} catch (IllegalAccessException e) {
					} catch (IllegalArgumentException e) {
					} catch (InvocationTargetException e) {}
				}
    		}
    		
    		return null;
        }
        
        private void invokeJSEventHandler(JSONObject message, final JSBridgeCallback responseCallback) {
        	String eventName = getString(message,"eventName");
        	JSONObject data	 = getJSONObjectForKey(message,"data");
        	Log("invokeJSEventHandler:eventName:"+eventName+" -> "+message+" -> "+data);
        	        	
        	if(eventName != null) {
            	JSBridgeHandler handler = null;
        		handler = getMessageHandler(eventName);
        		if(handler != null) {
        			handler.hanlder(data,responseCallback);
        		} else {        			
        			JSONObject retVal = invokeMethod(JS_API_PREFIX_FOR_EVENT, eventName, data, responseCallback);
        			if(retVal == null) {
        				callEventCallback(responseCallback,"UN-SUPPORTED EVENT: "+eventName,"false");
        			}
                }            
        	} else {
                if(jsBridgeHandler != null) {
                    jsBridgeHandler.hanlder(data,responseCallback);
                }
        	}
        }
        
        @JavascriptInterface
        public String ProcessJSAPIRequest(String name, String data) {
        	JSONObject inJsonObj = getJSONObject(data);
        	try {
	        	JSONObject retVal = invokeMethod(JS_API_PREFIX_FOR_API,name,inJsonObj,null);
	        	if(retVal != null) {
	        		JSONObject dataObj = getJSONObjectForKey(retVal, "1");
	            	String dataStr = null;
	            	if(dataObj == null) dataStr = getString(retVal, "1");
	            	
	            	JSONObject retObj;
	            	if(dataObj != null) {
	            		retObj = getReturnObject(name,"true", dataObj);	
	            	} else {
	            		retObj = getReturnObject(name,"true", dataStr);	
	            	}
	        		return ((retObj != null)?(retObj.toString()):(null));
	        	}
            } catch (Exception e) {}
       		return callAPICallback(webView, inJsonObj, "UN-SUPPORTED API: "+name, "false").toString();
        }
        
        @JavascriptInterface
        public void ProcessJSEventQueue(String msgQueue) {
            try {
                JSONArray messages = new JSONArray(msgQueue);
                if(messages != null) {
                    int msgCount = messages.length();
                    if(msgCount > 0) {
                        for (int i = 0; i < msgCount; i++) {
                            JSONObject message = messages.getJSONObject(i);
                            if(message != null) {
                                JSBridgeCallback responseCallback = null;
                                String responseId = getString(message,"responseId");
                                if(responseId != null) {
                                    responseCallback = (JSBridgeCallback) responseCallbacks.get(responseId);
                                    if(responseCallback != null) {
                                        try {
                                            String data = getString(message,"responseData");
                                            responseCallback.callBack(((data != null)?(getJSONObject(data)):(null)));
                                            responseCallbacks.remove(responseId);
                                        } catch(Exception e) {}
                                    }
                                } else {
                                	
                                    final String callbackId = getString(message,"callbackId");
                                    class responseCallBackImpl implements JSBridgeCallback {
                                        @Override
                                        public void callBack(JSONObject data) {
                                            if(callbackId != null) {
                                                JSONObject msg = new JSONObject();
                                                updateJsonObject(msg, "responseId", callbackId);
                                                updateJsonObject(msg, "responseData", data);
                                                queueMessage(msg);
                                            }
                                        }
                                    }

                                    invokeJSEventHandler(message,new responseCallBackImpl());
                                }
                            }
                        }
                    }
                }
            } catch (JSONException e) {}
        }
        @JavascriptInterface
        public void Log(String str) {
            JSBridge.Log("JSBridge","Android.Log",str);
        }
    }

    private void dispatchMessage(final String jsonStr) {
        webView.post(new Runnable() {
            @Override
            public void run() {
                webView.loadUrl("javascript: "+JS_BRIDGE+"."+JS_BRIDGE_SEND_NATIVE_QUEUE+"('"+jsonStr+"');");
            }
        });
    }

    private void queueMessage(JSONObject jsonObj) {
        if(startupMessageQueue != null) {
            startupMessageQueue.put(jsonObj);
        } else {
            dispatchMessage(getString(jsonObj));
        }
    }

    public JSBridge(Context context, WebView webview) {
        this.context = context;
        this.webView = webview;
    }

    @SuppressWarnings("deprecation")
	public void init(Object jsWebViewInterface, Object jsHandler) {
        if(JSBridgeInteface.class.isInstance(jsWebViewInterface)) {
            this.jsWebViewInterface = (JSBridgeInteface)jsWebViewInterface;
        }
        if(JSBridgeHandler.class.isInstance(jsHandler)) {
            this.jsBridgeHandler = (JSBridgeHandler)jsHandler;
        }
        CookieManager.getInstance().setAcceptCookie(true);
        if(webView != null) {
            webView.getSettings().setJavaScriptEnabled(true);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                WebView.setWebContentsDebuggingEnabled(true);
            }
            
            webView.getSettings().setDomStorageEnabled(true);
            webView.getSettings().setDatabaseEnabled(true);
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
               webView.getSettings().setDatabasePath("/data/data/" + webView.getContext().getPackageName() + "/databases/");
            }
            
            registerJavaScriptAPI(new AndroidAPI(context, webView));
            webView.setWebViewClient(new JSBridgeWebViewClient());
            webView.loadUrl("javascript: "+getAssetFileContents(JS_BRIDGE_FILE_NAME));
        }
    }

    public void registerJavaScriptAPI(JSBridgeBase instance) {
        if(webView != null) {
            webView.addJavascriptInterface(instance, instance.getClass().getSimpleName());
        }
    }

    public void loadHTML(String url) {
        if(webView != null) webView.loadUrl(url);
    }

    public void send(String eventName, JSONObject data, JSBridgeCallback responseCallback) {
        JSONObject message = new JSONObject();
        updateJsonObject(message,"status","true");
        updateJsonObject(message,"data",data);
        updateJsonObject(message,"eventName",eventName);
        if(responseCallback != null) {
            String callbackId = "android_cb_"+(++uniqueId);
            updateJsonObject(responseCallbacks,callbackId,responseCallback);
            updateJsonObject(message,"callbackId",callbackId);
        }
        queueMessage(message);
    }

    public void registerEvent(String eventName, JSBridgeHandler hanlder) {
        try {
            jsEventNativeHandlers.put(eventName, hanlder);
        } catch (JSONException e) {}
    }

    public void deRegisterEvent(String eventName, JSBridgeHandler hanlder) {
        jsEventNativeHandlers.remove(eventName);
    }
}
