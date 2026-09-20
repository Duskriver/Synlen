package sk.fourq.otaupdate;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.core.content.FileProvider;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okio.BufferedSink;
import okio.Okio;
import org.jetbrains.annotations.NotNull;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * OtaUpdatePlugin
 */
public class OtaUpdatePlugin implements
        FlutterPlugin,
        ActivityAware,
        EventChannel.StreamHandler,
        MethodCallHandler,
        PluginRegistry.RequestPermissionsResultListener {

    //CONSTANTS
    private static final String ARG_URL = "url";
    private static final String ARG_USE_PACKAGE_INSTALLER = "usePackageInstaller";
    private static final String ARG_HEADERS = "headers";
    private static final String ARG_FILENAME = "filename";
    private static final String ARG_CHECKSUM = "checksum";
    private static final String ARG_ANDROID_PROVIDER_AUTHORITY = "androidProviderAuthority";
    public static final String TAG = "FLUTTER OTA";
    private static final String DEFAULT_APK_NAME = "ota_update.apk";
    private static final String STREAM_CHANNEL = "sk.fourq.ota_update/stream";
    private static final String METHOD_CHANNEL = "sk.fourq.ota_update/method";

    // THIS IS TEMPORARY ACCESSOR, THAT IS CLEARED WHEN PLUGIN IS DETACHED FROM ENGINE
    private static OtaUpdatePlugin instance;
    private Long contentLength;

    public static OtaUpdatePlugin getInstance() {
        return instance;
    }

    //BASIC PLUGIN STATE
    private Context context;
    private Activity activity;
    private EventChannel.EventSink progressSink;
    private Handler handler;
    private String androidProviderAuthority;
    private BinaryMessenger messanger;
    private OkHttpClient client;
    private InstallSessionCallback installSessionCallback;

    //DOWNLOAD SPECIFIC PLUGIN STATE. PLUGIN SUPPORT ONLY ONE DOWNLOAD AT A TIME
    // 所有权只在主线程移交；工作线程只读取本任务的取消标记和参数。
    private DownloadOperation activeDownload;

    private static final class DownloadOperation {
        final Call call;
        final String checksum;
        final List<Result> cancellations = new ArrayList<>();
        volatile boolean canceled;
        boolean installationStarted;

        DownloadOperation(Call call, String checksum) {
            this.call = call;
            this.checksum = checksum;
        }
    }
    private String downloadUrl;
    private JSONObject headers;
    private String filename;
    private String checksum;
    private boolean usePackageInstaller = false;

    //FLUTTER EMBEDDING V2 - PLUGIN BINDING
    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        Log.d(TAG, "onAttachedToEngine");
        initialize(binding.getApplicationContext(), binding.getBinaryMessenger());
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        Log.d(TAG, "onDetachedFromEngine");
        cancelActiveDownload();
        closeSink();
        context = null;
        messanger = null;
        OtaUpdatePlugin.instance = null;
    }

    //FLUTTER EMBEDDING V2 - ACTIVITY BINDING. PLUGIN USES ACTIVITY FOR PERMISSION REQUESTS
    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity");
        activityPluginBinding.addRequestPermissionsResultListener(this);
        activity = activityPluginBinding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges");
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges");
    }

    @Override
    public void onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity");
    }

    //METHOD LISTENER
    @Override
    public void onMethodCall(MethodCall call, Result result) {
        Log.d(TAG, "onMethodCall " + call.method);
        if (call.method.equals("getAbi")) {
            result.success(Build.SUPPORTED_ABIS[0]);
        } else if (call.method.equals("cancel")) {
            final DownloadOperation operation = activeDownload;
            if (operation == null || operation.installationStarted) {
                // 已交给系统的安装界面不能撤回；其终态继续通过事件流传递。
                result.success(null);
            } else {
                operation.cancellations.add(result);
                cancelActiveDownload();
            }
        } else {
            result.notImplemented();
        }
    }

    //STREAM LISTENER
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        if (activeDownload != null) {
            // 拒绝新监听不能关闭仍在写盘或校验的旧任务。
            events.error("" + OtaStatus.ALREADY_RUNNING_ERROR.ordinal(), "Another update is still running", null);
            events.endOfStream();
            return;
        }
        Log.d(TAG, "STREAM OPENED");
        progressSink = events;
        //READ ARGUMENTS FROM CALL
        Map<String, String> argumentsMap;
        try {
            argumentsMap = parseArgumentsMap(arguments);
        } catch (RuntimeException ex) {
            reportStatus(true, OtaStatus.INTERNAL_ERROR, "Invalid arguments passed to onListen()", ex, null);
            return;
        }
        downloadUrl = argumentsMap.get(ARG_URL);
        String rawUsePackageInstaller = argumentsMap.get(ARG_USE_PACKAGE_INSTALLER);
        if (rawUsePackageInstaller != null) {
            usePackageInstaller = rawUsePackageInstaller.equals("true");
        }
        try {
            String headersJson = argumentsMap.get(ARG_HEADERS);
            if (headersJson != null && !headersJson.isEmpty()) {
                headers = new JSONObject(headersJson);
            }
        } catch (JSONException e) {
            Log.e(TAG, "ERROR: " + e.getMessage(), e);
        }
        if (argumentsMap.containsKey(ARG_FILENAME) && argumentsMap.get(ARG_FILENAME) != null) {
            filename = argumentsMap.get(ARG_FILENAME);
        } else {
            filename = DEFAULT_APK_NAME;
        }
        if (argumentsMap.containsKey(ARG_CHECKSUM) && argumentsMap.get(ARG_CHECKSUM) != null) {
            checksum = argumentsMap.get(ARG_CHECKSUM);
        }
        // user-provided provider authority
        String authority = argumentsMap.get(ARG_ANDROID_PROVIDER_AUTHORITY);
        androidProviderAuthority = Objects.requireNonNullElseGet(authority, () -> context.getPackageName() + "." + "ota_update_provider");
        executeDownload();
    }

    @SuppressWarnings("unchecked")
    private Map<String, String> parseArgumentsMap(Object arguments) {
        if (arguments instanceof Map) {
            return ((Map<String, String>) arguments);
        }
        throw new IllegalArgumentException();
    }

    @Override
    public void onCancel(Object o) {
        Log.d(TAG, "STREAM CLOSED");
        cancelActiveDownload();
        closeSink();
    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] strings, int[] grantResults) {
        Log.d(TAG, "REQUEST PERMISSIONS RESULT RECEIVED");
        if (requestCode == 0 && grantResults.length > 0) {
            for (int grantResult : grantResults) {
                if (grantResult != PackageManager.PERMISSION_GRANTED) {
                    reportStatus(true, OtaStatus.PERMISSION_NOT_GRANTED_ERROR, "Permission not granted", null, null);
                    return false;
                }
            }
            executeDownload();
            return true;
        } else {
            reportStatus(true, OtaStatus.PERMISSION_NOT_GRANTED_ERROR, "Permission not granted", null, null);
            return false;
        }
    }

    /**
     * Execute download and start installation. This method is called either from onListen method
     * or from onRequestPermissionsResult if user had to grant permissions.
     */
    private void executeDownload() {
        DownloadOperation operation = null;
        try {
            if (activeDownload != null) return;
            final File file = new File(context.getFilesDir(), "ota_update/" + filename);
            if (file.exists() && !file.delete()) {
                throw new IOException("Unable to remove previous APK");
            }
            final File parent = file.getParentFile();
            if (parent != null && !parent.exists() && !parent.mkdirs()) {
                throw new IOException("Unable to create APK directory");
            }
            final Request.Builder request = new Request.Builder().url(downloadUrl);
            if (headers != null) {
                Iterator<String> keys = headers.keys();
                while (keys.hasNext()) {
                    String key = keys.next();
                    request.addHeader(key, headers.getString(key));
                }
            }
            operation = new DownloadOperation(client.newCall(request.build()), checksum);
            activeDownload = operation;
            final DownloadOperation owner = operation;
            owner.call.enqueue(new Callback() {
                @Override public void onFailure(@NotNull Call call, @NotNull IOException error) {
                    finishDownload(owner, file, OtaStatus.DOWNLOAD_ERROR, error.getMessage(), error);
                }

                @Override public void onResponse(@NotNull Call call, @NotNull Response response) {
                    OtaStatus failure = null;
                    String message = null;
                    Exception error = null;
                    // 响应体和输出文件先关闭，终态及取消确认才允许对外发布。
                    try (Response bodyOwner = response) {
                        if (!response.isSuccessful()) {
                            throw new IOException("HTTP status " + response.code());
                        }
                        if (response.body() == null) throw new IOException("Missing response body");
                        try (ProgressResponseBody body = new ProgressResponseBody(response.body(),
                                (read, total, done) -> reportDownloadProgress(owner, read, total, done));
                             BufferedSink output = Okio.buffer(Okio.sink(file))) {
                            output.writeAll(body.source());
                        }
                        if (!owner.canceled && owner.checksum != null) {
                            try {
                                if (!validateChecksum(owner.checksum, file)) {
                                    failure = OtaStatus.CHECKSUM_ERROR;
                                    message = "Checksum verification failed";
                                }
                            } catch (RuntimeException exception) {
                                failure = OtaStatus.CHECKSUM_ERROR;
                                message = exception.getMessage();
                                error = exception;
                            }
                        }
                    } catch (IOException | RuntimeException exception) {
                        failure = OtaStatus.DOWNLOAD_ERROR;
                        message = exception.getMessage();
                        error = exception;
                    }
                    finishDownload(owner, file, failure, message, error);
                }
            });
        } catch (Exception error) {
            if (operation != null) {
                finishDownload(operation, null, OtaStatus.INTERNAL_ERROR, error.getMessage(), error);
            } else {
                reportStatus(true, OtaStatus.INTERNAL_ERROR, error.getMessage(), error, null);
            }
        }
    }

    private void cancelActiveDownload() {
        final DownloadOperation operation = activeDownload;
        if (operation == null || operation.installationStarted) return;
        operation.canceled = true;
        operation.call.cancel();
    }

    private void finishDownload(DownloadOperation operation, File file,
                                OtaStatus failure, String message, Exception error) {
        handler.post(() -> {
            // 工作结束前保留所有权；重复或迟到回调不能释放另一任务或关闭它的流。
            if (activeDownload != operation || operation.installationStarted) return;
            if (operation.canceled) {
                reportStatus(true, OtaStatus.CANCELED, "Download canceled", null, null);
            } else if (failure != null) {
                reportStatus(true, failure, message, error, null);
            } else {
                // 与取消在同一主线程决胜：安装尚未启动时，取消总能阻止交接。
                operation.installationStarted = true;
                try {
                    executeInstallation(Uri.fromFile(file), file);
                } catch (RuntimeException exception) {
                    reportStatus(true, OtaStatus.INSTALLATION_ERROR, exception.getMessage(), exception, null);
                }
            }
            if (operation.canceled || failure != null) {
                if (activeDownload == operation) activeDownload = null;
            }
            for (Result result : operation.cancellations) result.success(null);
            operation.cancellations.clear();
        });
    }

    private void reportDownloadProgress(DownloadOperation operation, long read, long total, boolean done) {
        if (done || total < 1) return;
        handler.post(() -> {
            if (activeDownload != operation || operation.canceled || operation.installationStarted) return;
            contentLength = total;
            reportStatus(false, OtaStatus.DOWNLOADING, "", null, "" + ((read * 100) / total));
        });
    }

    /**
     * Check if app has INSTALL_PACKAGES permission (system app privilege)
     */
    private boolean hasInstallPackagesPermission() {
        try {
            boolean hasInstallPackages = context.checkCallingOrSelfPermission("android.permission.INSTALL_PACKAGES")
                    == PackageManager.PERMISSION_GRANTED;
            Log.d(TAG, "INSTALL_PACKAGES permission: " + hasInstallPackages);
            return hasInstallPackages;
        } catch (Exception e) {
            Log.w(TAG, "Error checking INSTALL_PACKAGES permission", e);
            return false;
        }
    }

    boolean validateChecksum(String expected, File file) {
        return Sha256ChecksumValidator.validateChecksum(expected, file);
    }

    /**
     * Execute installation
     * <p>
     * If app has INSTALL_PACKAGES permission, use package installer (will be silent if possible)
     * For android API level >= 24 use package installer (will be silent if possible)
     * For android API level < 24 start intent ACTION_VIEW (open file, android should prompt for installation)
     *
     * @param fileUri        Uri for file path
     * @param downloadedFile Downloaded file
     */
    void executeInstallation(Uri fileUri, File downloadedFile) {
        // Try silent installation for system apps first
        if (hasInstallPackagesPermission()) {
            Log.d(TAG, "App has INSTALL_PACKAGES, using package installer");
            installUsingPackageInstaller(downloadedFile);
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            if (usePackageInstaller) {
                installUsingPackageInstaller(downloadedFile);
            } else {
                installUsingActionInstallPackage(downloadedFile);
            }
        } else {
            installUsingVndPackageArchive(fileUri);
        }
    }

    /**
     * Perform installation using PackageInstaller (for system apps)
     */
    private void installUsingPackageInstaller(File downloadedFile) {
        try {
            Log.d(TAG, "Using PackageInstaller installation method");
            // NOTIFY DART PART OF THE PLUGIN, THAT INSTALLATION STARTED
            reportStatus(false, OtaStatus.INSTALLING, "Installation started", null, null);
            PackageInstaller packageInstaller = context.getPackageManager().getPackageInstaller();
            // Configure session parameters.
            // MODE_FULL_INSTALL means we’re doing a full APK installation (not a staged/delta update).
            PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(
                    PackageInstaller.SessionParams.MODE_FULL_INSTALL
            );
            // Create a new installation session and get its unique ID
            // Open the session so we can write the APK bytes into it
            int sessionId = packageInstaller.createSession(params);
            packageInstaller.registerSessionCallback(installSessionCallback);
            PackageInstaller.Session session = packageInstaller.openSession(sessionId);
            long totalWritten = 0;
            try (OutputStream out = session.openWrite("package", 0, -1);
                 InputStream in = new FileInputStream(downloadedFile)
            ) {
                // Buffer for copying data from the APK file into the session
                byte[] buffer = new byte[65536];
                int c;
                while ((c = in.read(buffer)) != -1) {
                    out.write(buffer, 0, c);
                    totalWritten += c;
                    if (contentLength != null) {
                        session.setStagingProgress(totalWritten / ((float) contentLength));
                    }
                }
                session.fsync(out);
            }

            // Create intent for the installation result
            Intent intent = new Intent(context, InstallResultReceiver.class);
            intent.setAction(context.getPackageName() + "." + InstallResultReceiver.ACTION_INSTALL_COMPLETE);
            // Wrap the result Intent in a PendingIntent, which gives us an IntentSender for commit().
            // On Android 12 (S) and above, PendingIntent must be declared mutable/immutable explicitly.
            PendingIntent pendingIntent = PendingIntent.getBroadcast(
                    context,
                    sessionId,
                    intent,
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                            ? PendingIntent.FLAG_MUTABLE
                            : PendingIntent.FLAG_UPDATE_CURRENT);

            // Commit the session. This hands control over to the system to actually perform the install.
            // The provided IntentSender will be invoked with the result of the installation.
            session.commit(pendingIntent.getIntentSender());
            session.close();
            Log.d(TAG, "Installation session committed");
        } catch (Exception e) {
            Log.e(TAG, "PackageInstaller installation method failed", e);
            reportStatus(true, OtaStatus.INSTALLATION_ERROR, "Installation failed: " + e.getMessage(), e, null);
        }
    }

    @SuppressWarnings("deprecation")
    private void installUsingActionInstallPackage(File downloadedFile) {
        Intent intent;
        Uri apkUri = FileProvider.getUriForFile(context, androidProviderAuthority, downloadedFile);
        intent = new Intent(Intent.ACTION_INSTALL_PACKAGE);
        intent.setData(apkUri);
        intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
        reportStatus(true, OtaStatus.INSTALLING, "Installation started", null, null);
    }

    @SuppressWarnings("deprecation")
    private void installUsingVndPackageArchive(Uri fileUri) {
        Intent intent;
        intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(fileUri, "application/vnd.android.package-archive");
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
        reportStatus(true, OtaStatus.INSTALLING, "Installation started", null, null);
    }


    /**
     * Report error to the dart code
     *
     * @param closeSink Indicates whether to close the progress sink after reporting status
     * @param otaStatus Status to report
     * @param s         Error message to report
     * @param e         Exception to report
     */
    private void reportStatus(final boolean closeSink, final OtaStatus otaStatus, final String s, final Exception e, Object arg) {
        if (Looper.getMainLooper().isCurrentThread()) {
            if (otaStatus.isError()) {
                Log.e(TAG, "ERROR: " + s, e);
            }
            if (progressSink != null) {
                if (otaStatus.isError()) {
                    progressSink.error("" + otaStatus.ordinal(), s, null);
                } else {
                    List<String> responseArgs = new ArrayList<>(2);
                    responseArgs.add("" + otaStatus.ordinal());
                    if (arg != null) {
                        responseArgs.add(arg.toString());
                    } else {
                        responseArgs.add("");
                    }
                    progressSink.success(responseArgs);
                }
                if (closeSink) closeSink();
            }
            if (closeSink) activeDownload = null;
        } else {
            //REPORT ERROR ON UI THREAD
            handler.post(new Runnable() {
                @Override
                public void run() {
                    reportStatus(closeSink, otaStatus, s, e, null);
                }
            });
        }
    }

    /**
     * Initialization. Shared for embedding v1 and v2
     *
     * @param context   ApplicationContext
     * @param messanger BinaryMessanger for communication with dart
     */
    private void initialize(Context context, BinaryMessenger messanger) {
        this.context = context;
        OtaUpdatePlugin.instance = this;
        handler = new Handler(context.getMainLooper());
        installSessionCallback = new InstallSessionCallback();
        final EventChannel progressChannel = new EventChannel(messanger, STREAM_CHANNEL);
        progressChannel.setStreamHandler(this);

        final MethodChannel methodChannel = new MethodChannel(messanger, METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);

        client = new OkHttpClient();
    }

    public void onInstallSuccess(String message) {
        reportStatus(true, OtaStatus.INSTALLATION_DONE, message, null, null);
    }

    public void onInstallFailure(String message) {
        reportStatus(true, OtaStatus.INSTALLATION_ERROR, message, null, null);
    }

    public void onInstallProgress(float progress) {
        reportStatus(false, OtaStatus.INSTALLING, "", null, (int) Math.floor(progress * 100));
    }

    private void closeSink() {
        if (progressSink != null) {
            progressSink.endOfStream();
        }
        progressSink = null;
        contentLength = null;
        try {
            if (context != null && installSessionCallback != null) {
                context.getPackageManager().getPackageInstaller().unregisterSessionCallback(installSessionCallback);
            }
        } catch (RuntimeException e) {
            Log.e(TAG, "Error unregistering session callback", e);
        }
    }

    /**
     * All statuses reported by the plugin
     */
    private enum OtaStatus {
        DOWNLOADING(false),
        INSTALLING(false),
        INSTALLATION_DONE(false),
        INSTALLATION_ERROR(true),
        ALREADY_RUNNING_ERROR(true),
        PERMISSION_NOT_GRANTED_ERROR(true),
        INTERNAL_ERROR(true),
        DOWNLOAD_ERROR(true),
        CHECKSUM_ERROR(true),
        CANCELED(true);

        /**
         * Indicates whether status represents an error
         */
        private final boolean error;

        /**
         * Constructor
         *
         * @param error Indicates whether status represents an error
         */
        OtaStatus(boolean error) {
            this.error = error;
        }

        /**
         * @return true if status represents an error, false otherwise
         */
        public boolean isError() {
            return error;
        }
    }
}
