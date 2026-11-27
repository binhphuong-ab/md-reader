package com.binhphuongab.mdreader;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.graphics.Insets;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

/**
 * MD Reader for Android: one full-screen WebView running the same viewer as the Mac app
 * (assets/web/viewer.html). Files arrive through "Open with", "Share", or the in-page Open
 * button ("Recent Files" picker if installed, else the system picker); the last picked file
 * reopens on the next launch.
 */
public class MainActivity extends Activity {
    private static final int PICK_FILE = 1;
    private static final String VIEWER = "file:///android_asset/web/viewer.html";
    private static final String WELCOME =
            "# MD Reader\n\n**Pull down** at the top of the page to show the buttons, then tap the "
            + "folder to choose a Markdown file. Or open a `.md` file from your file manager and pick "
            + "**MD Reader**.\n\nSupports $\\LaTeX$ math, Mermaid diagrams, tables, task lists and "
            + "footnotes.\n";

    private WebView web;
    private boolean pageReady;
    private Uri docUri;
    private String docText;
    private int topInsetPx;
    private SharedPreferences prefs;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        prefs = getSharedPreferences("mdreader", MODE_PRIVATE);
        getExternalFilesDir(null);   // create Android/data/<pkg>/files owned by the app (adb push target)

        web = new WebView(this);
        web.setBackgroundColor(0xFF15171C);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);   // the pull-to-reveal buttons are the feedback
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setAllowFileAccess(true);
        s.setBuiltInZoomControls(true);        // pinch to zoom
        s.setDisplayZoomControls(false);
        web.addJavascriptInterface(new Bridge(), "MDRAndroid");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (u.toString().startsWith("file:///android_asset/")) return false;
                openExternal(u.toString());
                return true;
            }
        });

        // Android 15+ draws apps edge to edge: keep the text clear of the status bar.
        web.setOnApplyWindowInsetsListener((v, insets) -> {
            Insets bars = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
            topInsetPx = bars.top;
            v.setPadding(bars.left, 0, bars.right, 0);
            pushInsets();
            return insets;
        });
        setContentView(web);
        if (Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) c.setSystemBarsAppearance(0,
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                            | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS);
        }

        web.loadUrl(VIEWER);
        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (docUri != null && pageReady) load(docUri, true);   // pick up edits made elsewhere
    }

    private void handleIntent(Intent intent) {
        String action = intent == null ? null : intent.getAction();
        if (Intent.ACTION_VIEW.equals(action) && intent.getData() != null) {
            load(intent.getData(), false);
        } else if (Intent.ACTION_SEND.equals(action)) {
            Uri stream = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            String text = intent.getStringExtra(Intent.EXTRA_TEXT);
            if (stream != null) load(stream, false);
            else if (text != null) { docUri = null; docText = text; render(false); }
        } else if (docUri == null && docText == null) {
            String last = prefs.getString("lastUri", null);
            if (last != null) load(Uri.parse(last), false);
        }
    }

    private void load(Uri uri, boolean keepScroll) {
        new Thread(() -> {
            String text;
            try (InputStream in = getContentResolver().openInputStream(uri)) {
                if (in == null) throw new IllegalStateException("cannot open");
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buf = new byte[64 * 1024];
                for (int n; (n = in.read(buf)) > 0; ) out.write(buf, 0, n);
                text = new String(out.toByteArray(), StandardCharsets.UTF_8);
            } catch (Exception e) {
                runOnUiThread(() -> {
                    if (uri.toString().equals(prefs.getString("lastUri", null))) {
                        prefs.edit().remove("lastUri").apply();   // stale: file moved or permission gone
                    } else {
                        Toast.makeText(this, "Could not open file", Toast.LENGTH_SHORT).show();
                    }
                });
                return;
            }
            final String loaded = text;
            runOnUiThread(() -> {
                boolean sameDoc = uri.equals(docUri);
                if (sameDoc && keepScroll && loaded.equals(docText)) return;   // unchanged
                docUri = uri;
                docText = loaded;
                setTitle(displayName(uri));
                render(sameDoc && keepScroll);
            });
        }).start();
    }

    private String displayName(Uri uri) {
        try (Cursor c = getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (c != null && c.moveToFirst()) return c.getString(0);
        } catch (Exception ignored) { }
        String last = uri.getLastPathSegment();
        return last != null ? last : "Markdown";
    }

    private void render(boolean keepScroll) {
        if (!pageReady) return;
        String text = docText != null ? docText : WELCOME;
        web.evaluateJavascript("MDR.render(" + JSONObject.quote(text) + ", '', " + keepScroll + ")", null);
    }

    private void pushInsets() {
        if (!pageReady) return;
        float density = getResources().getDisplayMetrics().density;
        web.evaluateJavascript("MDR.setTopInset(" + Math.round(topInsetPx / density) + ")", null);
    }

    private void openExternal(String href) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(href)));
        } catch (Exception e) {
            Toast.makeText(this, "No app can open this link", Toast.LENGTH_SHORT).show();
        }
    }

    private void pickFile() {
        // Prefer our own "Recent Files" picker (newest-first, .md preselected); the system picker
        // is only the fallback when that app isn't installed. ACTION_OPEN_DOCUMENT always lands in
        // the system picker, so the direct route has to be an explicit GET_CONTENT.
        Intent recent = new Intent(Intent.ACTION_GET_CONTENT)
                .setPackage("com.binhphuongab.recentfiles")
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("text/markdown");
        try {
            startActivityForResult(recent, PICK_FILE);
            return;
        } catch (android.content.ActivityNotFoundException ignored) { }
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("*/*");
        startActivityForResult(i, PICK_FILE);
    }

    @Override
    protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request != PICK_FILE || result != RESULT_OK || data == null || data.getData() == null) return;
        Uri uri = data.getData();
        try {
            getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            prefs.edit().putString("lastUri", uri.toString()).apply();
        } catch (SecurityException ignored) { }
        load(uri, false);
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        // Let the page close the zoomed diagram or the outline drawer first.
        web.evaluateJavascript("MDR.back()", r -> { if (!"true".equals(r)) finish(); });
    }

    /** window.MDRAndroid in the page; viewer.js posts the same messages it sends on macOS. */
    private class Bridge {
        @JavascriptInterface
        public void post(String json) {
            runOnUiThread(() -> {
                try {
                    JSONObject m = new JSONObject(json);
                    switch (m.optString("type")) {
                        case "ready":
                            pageReady = true;
                            pushInsets();
                            render(false);
                            break;
                        case "open":
                            openExternal(m.optString("href"));
                            break;
                        case "pick":
                            pickFile();
                            break;
                        case "haptic":
                            web.performHapticFeedback(Build.VERSION.SDK_INT >= 30
                                    ? HapticFeedbackConstants.CONFIRM : HapticFeedbackConstants.VIRTUAL_KEY);
                            break;
                        case "copy":
                            ClipboardManager cm = getSystemService(ClipboardManager.class);
                            cm.setPrimaryClip(ClipData.newPlainText("code", m.optString("text")));
                            break;
                    }
                } catch (Exception ignored) { }
            });
        }
    }
}
