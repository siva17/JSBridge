package com.siva4u.example;

import org.json.JSONObject;

import android.content.Context;
import android.webkit.WebView;
import android.widget.Toast;

import com.siva4u.jsbridge.JSBridge;
import com.siva4u.jsbridge.JSBridgeBase;
import com.siva4u.jsbridge.JSBridgeCallback;

public class Test extends JSBridgeBase {

	public Test(Context c, WebView view) {
		super(c, view);
	}

	public void JSBAPI_APIOne() {
		JSBridge.Log("Test","APIOne","START");
        Toast.makeText(webViewContext, "Hello....", Toast.LENGTH_SHORT).show();
	}
	
    public void JSBAPI_APITwo(JSONObject jsonObject) {
    	JSBridge.Log("Test","APITwo","START: "+jsonObject);
        Toast.makeText(webViewContext, jsonObject.toString(), Toast.LENGTH_SHORT).show();
    }
    
    public void JSBAPI_APIThree(JSONObject jsonObject) {
    	JSBridge.Log("Test","APIThree","START: "+jsonObject);
        Toast.makeText(webViewContext, jsonObject.toString(), Toast.LENGTH_SHORT).show();
    }
    
    public JSONObject JSBAPI_APIFour(JSONObject jsonObject) {
    	JSBridge.Log("Test","APIFour","START: "+jsonObject);
        Toast.makeText(webViewContext, jsonObject.toString(), Toast.LENGTH_SHORT).show();
        return JSBridge.putKeyValue(null, "returnData", "Returned Data from API Four...");
    }
    
    public JSONObject JSBAPI_APIFive(JSONObject jsonObject) {
    	JSBridge.Log("Test","APIFive","START: "+jsonObject);
        Toast.makeText(webViewContext, jsonObject.toString(), Toast.LENGTH_SHORT).show();
        return JSBridge.putKeyValue(null, "returnData", "Returned Data from API Five: "+jsonObject.toString());
    }

    public JSONObject JSBAPI_APISix(JSONObject jsonObject) {
    	JSBridge.Log("Test","APISix","START: "+jsonObject);
		Toast.makeText(webViewContext, jsonObject.toString(), Toast.LENGTH_SHORT).show();
		JSONObject retObj = JSBridge.putKeyValue(null, "returnData", "Returned Data from API Six: ");
		JSBridge.callAPICallback(webView,jsonObject,retObj);
        return retObj;
    }

    public JSONObject JSBAPI_APISeven(JSONObject jsonObject) {
    	JSBridge.Log("Test","APISeven","START: "+jsonObject);
		Toast.makeText(webViewContext, jsonObject.toString(), Toast.LENGTH_SHORT).show();
		JSONObject retObj = JSBridge.putKeyValue(null, "returnData", "Returned Data from API Seven: "+jsonObject.toString());
		JSBridge.callAPICallback(webView,jsonObject,retObj);
        return retObj;
    }
    
    public void JSBEvent_testNativeEvent(JSONObject jsonObject, JSBridgeCallback responseCallback) {
    	JSBridge.Log("Test","testNativeEvent","START: "+jsonObject);
    	JSBridge.Log("Test","testNativeEvent","responseCallback: "+responseCallback);
    	JSBridge.callEventCallback(responseCallback, JSBridge.putKeyValue(null, "eventData", "Response is sent from Test.testNativeEvent"));
    }
}
