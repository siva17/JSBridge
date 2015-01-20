package com.siva4u.jsbridge;

import android.graphics.Bitmap;
import android.webkit.WebView;

public interface JSBridgeInteface {
    public void onPageStarted (WebView view, String url, Bitmap favicon);
    public void onPageFinished(WebView view, String url);
    public boolean shouldOverrideUrlLoading(WebView view, String url);
}
