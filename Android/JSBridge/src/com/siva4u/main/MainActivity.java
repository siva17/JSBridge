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
		jsBridge.loadHTML("https://acceptance.dot.state.wi.us/regRenewal/");		
    }    
}
