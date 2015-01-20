package com.siva4u.jsbridge;

import android.content.Context;
import android.webkit.WebView;

public class JSBridgeAPIBase {

    protected Context webViewContext;
    protected WebView webView;
    
    public JSBridgeAPIBase(Context c, WebView view) {
        webViewContext = c;
        webView = view;
    }
}
