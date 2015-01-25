package com.siva4u.main;

import org.json.JSONObject;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;

import com.siva4u.jsbridge.R;
import com.siva4u.jsbridge.JSBridge;
import com.siva4u.jsbridge.JSBridgeCallback;
import com.siva4u.jsbridge.JSBridgeHandler;

public class MainActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        final WebView webview = (WebView) findViewById(R.id.JSBridgeWebView);
        final JSBridge jsBridge = new JSBridge(getApplicationContext(), webview);
        jsBridge.init(this, new JSBridgeHandler() {
			@Override
			public void hanlder(JSONObject data, JSBridgeCallback responseCallback) {
				JSBridge.Log("MainActivity","JSBridgeHandler",data+" with CB:"+responseCallback);
				JSBridge.callEventCallback(responseCallback, JSBridge.putKeyValue(null, "initData","Response for message from Native for UN-SUPPORTED API"));
			}
		});

		jsBridge.send(null,JSBridge.putKeyValue(null, "thoseData", "A string sent from Native before Webview has loaded."), new JSBridgeCallback(){
			@Override
			public void callBack(JSONObject data) {
				JSBridge.Log("MainActivity", "CallbackSendMessage", data.toString());
			}
		});
				
		jsBridge.send("testJavascriptHandler",JSBridge.putKeyValue(null, "foo", "Before Ready"),null);
		
		jsBridge.loadHTML("file:///android_asset/index.html");
		
		jsBridge.send(null, JSBridge.putKeyValue(null, "thisData", "A string sent from ObjC after Webview has loaded."), null);
    }    
}
