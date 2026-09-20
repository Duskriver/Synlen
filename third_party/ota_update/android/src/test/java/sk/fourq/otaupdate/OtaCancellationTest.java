package sk.fourq.otaupdate;

import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Protocol;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;
import okio.Timeout;
import okio.Buffer;
import okio.BufferedSource;
import okio.ForwardingSource;
import okio.Okio;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.LooperMode;
import org.robolectric.util.ReflectionHelpers;

import static org.junit.Assert.*;

/** 手动推进真实下载回调和主线程队列，固定取消与校验、安装交接的顺序。 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
@LooperMode(LooperMode.Mode.PAUSED)
public class OtaCancellationTest {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final List<FakeCall> calls = new ArrayList<>();
    private TestPlugin plugin;

    @Before public void setUp() {
        plugin = new TestPlugin();
        ReflectionHelpers.setField(plugin, "context", RuntimeEnvironment.getApplication());
        ReflectionHelpers.setField(plugin, "handler", new Handler(Looper.getMainLooper()));
        ReflectionHelpers.setField(plugin, "client", new OkHttpClient() {
            @Override public Call newCall(Request request) {
                FakeCall call = new FakeCall(request);
                calls.add(call);
                return call;
            }
        });
    }

    @After public void tearDown() throws Exception {
        plugin.checksumRelease.countDown();
        worker.shutdown();
        assertTrue(worker.awaitTermination(5, TimeUnit.SECONDS));
        idle();
    }

    private Sink start() {
        Map<String, String> args = new HashMap<>();
        args.put("url", "https://example.com/update.apk");
        args.put("filename", "synlen-update.apk");
        args.put("checksum", "ab".repeat(32));
        args.put("usePackageInstaller", "false");
        Sink sink = new Sink();
        plugin.onListen(args, sink);
        return sink;
    }

    private Result cancel() {
        Result result = new Result();
        plugin.onMethodCall(new MethodCall("cancel", null), result);
        return result;
    }

    private Future<?> respond(FakeCall call, int status) {
        return respond(call, status, ResponseBody.create("APK fixture", MediaType.get("application/octet-stream")));
    }

    private Future<?> respond(FakeCall call, int status, ResponseBody body) {
        return worker.submit(() -> {
            Response response = new Response.Builder().request(call.request)
                .protocol(Protocol.HTTP_1_1).code(status).message("fixture")
                .body(body)
                .build();
            call.callback.onResponse(call, response);
            return null;
        });
    }

    private void idle() { Shadows.shadowOf(Looper.getMainLooper()).idle(); }

    @Test public void cancellationWaitsForChecksumAndBlocksRetry() throws Exception {
        plugin.blockChecksum = true;
        Sink first = start();
        Future<?> callback = respond(calls.get(0), 200);
        assertTrue(plugin.checksumEntered.await(5, TimeUnit.SECONDS));
        Result canceled = cancel();
        try {
            assertEquals("校验未结束时不能确认取消", 0, canceled.completions);
            Sink rejected = start();
            assertEquals("旧任务未释放时不能创建新网络请求", 1, calls.size());
            assertEquals(List.of("4"), rejected.errors);
        } finally {
            plugin.checksumRelease.countDown();
        }
        callback.get(5, TimeUnit.SECONDS);
        idle();
        assertEquals(1, canceled.completions);
        assertEquals(List.of("9"), first.errors);
        assertEquals(0, plugin.installations);
    }

    @Test public void cancellationBeforeQueuedInstallationSuppressesInstaller() throws Exception {
        Sink sink = start();
        respond(calls.get(0), 200).get(5, TimeUnit.SECONDS);
        Result canceled = cancel();
        idle();
        assertEquals("已排队但未交给系统的安装仍须取消", 0, plugin.installations);
        assertEquals(List.of("9"), sink.errors);
        assertEquals(1, canceled.completions);
    }

    @Test public void lateFailureCannotCloseRetryOrClearItsCall() throws Exception {
        start();
        FakeCall old = calls.get(0);
        Result canceled = cancel();
        old.callback.onFailure(old, new IOException("canceled"));
        idle();
        assertEquals(1, canceled.completions);
        Sink retry = start();
        FakeCall current = calls.get(1);
        old.callback.onFailure(old, new IOException("late callback"));
        idle();
        assertTrue("迟到回调不能终结重试流", retry.errors.isEmpty());
        assertEquals(0, retry.closed);
        Result retryCancel = cancel();
        assertTrue("取消必须仍指向重试请求", current.canceled);
        current.callback.onFailure(current, new IOException("canceled"));
        idle();
        assertEquals(1, retryCancel.completions);
    }

    @Test public void failedHttpResponseNeverReachesInstaller() throws Exception {
        Sink sink = start();
        respond(calls.get(0), 404).get(5, TimeUnit.SECONDS);
        idle();
        assertEquals(List.of("7"), sink.errors);
        assertEquals(0, plugin.installations);
        assertEquals(1, sink.closed);
    }

    @Test public void repeatedCancellationWaitsForBodyCloseAndDropsQueuedProgress() throws Exception {
        Sink sink = start();
        BlockingBody body = new BlockingBody();
        Future<?> callback = respond(calls.get(0), 200, body);
        assertTrue(body.entered.await(5, TimeUnit.SECONDS));
        Result first = cancel();
        Result second = cancel();
        try {
            assertEquals(0, first.completions);
            assertEquals(0, second.completions);
            assertFalse(body.closed);
        } finally {
            body.release.countDown();
        }
        callback.get(5, TimeUnit.SECONDS);
        idle();
        assertTrue(body.closed);
        assertEquals(1, first.completions);
        assertEquals(1, second.completions);
        assertEquals(0, plugin.installations);
        assertTrue("取消期间排队的进度不得覆盖终态", sink.values.isEmpty());
        assertEquals(List.of("9"), sink.errors);
    }

    @Test public void streamDetachmentCancelsWorkBeforeNewListen() throws Exception {
        start();
        FakeCall old = calls.get(0);
        plugin.onCancel(null);
        assertTrue(old.canceled);
        Sink rejected = start();
        assertEquals(List.of("4"), rejected.errors);
        old.callback.onFailure(old, new IOException("canceled"));
        idle();
        start();
        assertEquals(2, calls.size());
        respond(calls.get(1), 200).get(5, TimeUnit.SECONDS);
        idle();
        assertEquals(1, plugin.installations);
    }

    @Test public void checksumFailureClosesStreamAndAllowsRetry() throws Exception {
        plugin.validChecksum = false;
        Sink first = start();
        respond(calls.get(0), 200).get(5, TimeUnit.SECONDS);
        idle();
        assertEquals(List.of("8"), first.errors);
        assertEquals(0, plugin.installations);
        plugin.validChecksum = true;
        Sink retry = start();
        respond(calls.get(1), 200).get(5, TimeUnit.SECONDS);
        idle();
        assertEquals(1, plugin.installations);
        assertEquals(1, retry.closed);
        assertTrue(retry.errors.isEmpty());
        assertEquals(1, cancel().completions);
    }

    private static class TestPlugin extends OtaUpdatePlugin {
        boolean blockChecksum;
        boolean validChecksum = true;
        int installations;
        final CountDownLatch checksumEntered = new CountDownLatch(1);
        final CountDownLatch checksumRelease = new CountDownLatch(1);
        @Override boolean validateChecksum(String expected, File file) {
            checksumEntered.countDown();
            if (blockChecksum) {
                try {
                    if (!checksumRelease.await(5, TimeUnit.SECONDS)) throw new AssertionError("校验等待超时");
                } catch (InterruptedException e) { throw new AssertionError(e); }
            }
            return validChecksum;
        }
        @Override void executeInstallation(Uri uri, File file) {
            installations++;
            onInstallSuccess("installed");
        }
    }

    private static class Sink implements EventChannel.EventSink {
        final List<String> errors = new ArrayList<>();
        final List<Object> values = new ArrayList<>();
        int closed;
        @Override public void success(Object value) { values.add(value); }
        @Override public void error(String code, String message, Object details) { errors.add(code); }
        @Override public void endOfStream() { closed++; }
    }

    private static class BlockingBody extends ResponseBody {
        final CountDownLatch entered = new CountDownLatch(1);
        final CountDownLatch release = new CountDownLatch(1);
        volatile boolean closed;
        final BufferedSource source = Okio.buffer(new ForwardingSource(new Buffer().writeUtf8("APK fixture")) {
            @Override public long read(Buffer sink, long count) throws IOException {
                entered.countDown();
                try {
                    if (!release.await(5, TimeUnit.SECONDS)) throw new AssertionError("响应体等待超时");
                } catch (InterruptedException e) { throw new AssertionError(e); }
                return super.read(sink, count);
            }
            @Override public void close() throws IOException {
                closed = true;
                super.close();
            }
        });
        @Override public MediaType contentType() { return MediaType.get("application/octet-stream"); }
        @Override public long contentLength() { return 11; }
        @Override public BufferedSource source() { return source; }
    }

    private static class Result implements MethodChannel.Result {
        int completions;
        @Override public void success(Object value) { completions++; }
        @Override public void error(String code, String message, Object details) { fail(message); }
        @Override public void notImplemented() { fail("未实现取消"); }
    }

    private static class FakeCall implements Call {
        final Request request;
        Callback callback;
        boolean canceled;
        FakeCall(Request request) { this.request = request; }
        @Override public Request request() { return request; }
        @Override public Response execute() { throw new UnsupportedOperationException(); }
        @Override public void enqueue(Callback callback) { this.callback = callback; }
        @Override public void cancel() { canceled = true; }
        @Override public boolean isExecuted() { return callback != null; }
        @Override public boolean isCanceled() { return canceled; }
        @Override public Timeout timeout() { return Timeout.NONE; }
        @Override public Call clone() { return new FakeCall(request); }
    }
}
