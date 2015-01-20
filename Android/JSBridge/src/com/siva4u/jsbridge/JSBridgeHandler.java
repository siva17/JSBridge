package com.siva4u.jsbridge;

import org.json.JSONObject;

public interface JSBridgeHandler {
    public void hanlder(JSONObject data, JSBridgeCallback responseCallback);
}
