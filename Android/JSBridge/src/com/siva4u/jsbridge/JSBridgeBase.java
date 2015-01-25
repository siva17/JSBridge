package com.siva4u.jsbridge;

import android.content.Context;
import android.webkit.WebView;

public class JSBridgeBase {
    protected Context webViewContext;
    protected WebView webView;
    public JSBridgeBase(Context c, WebView view) {
        webViewContext = c;
        webView = view;
    }
}
