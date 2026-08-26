package pzmod.tests;

import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.ReentrantLock;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.expose.LuaJavaClassExposer;
import se.krka.kahlua.integration.expose.LuaJavaInvoker;
import se.krka.kahlua.integration.expose.MethodArguments;
import se.krka.kahlua.integration.expose.ReturnValues;
import se.krka.kahlua.integration.expose.caller.MethodCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.Coroutine;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.LuaCallFrame;

public final class KahluaObjectPoolRaceHarness {
    private static final int THREADS = 24;
    private static final int ITERATIONS = 100_000;
    private static final ReentrantLock POOL_LOCK = new ReentrantLock();
    private static final CyclicBarrier INVOKER_BARRIER = new CyclicBarrier(2);
    private static final AtomicInteger INVOKER_ORDER = new AtomicInteger();

    private KahluaObjectPoolRaceHarness() {}

    public static void main(String[] args) throws Exception {
        boolean guarded = args.length == 1 && "guarded".equals(args[0]);
        boolean patched = args.length == 1 && "patched".equals(args[0]);
        boolean recovery = args.length == 1 && "recovery".equals(args[0]);
        boolean inFlightRecovery = args.length == 1 && "inflight-recovery".equals(args[0]);
        if (recovery || inFlightRecovery) {
            int failures = exerciseInvokerRecovery(inFlightRecovery);
            System.out.printf("mode=%s invokerFailures=%d%n", args[0], failures);
            if (failures != 0) System.exit(1);
            return;
        }
        int returnValueFailures = exerciseReturnValues(guarded, patched);
        int methodArgumentFailures = exerciseMethodArguments(guarded, patched);
        int failures = returnValueFailures + methodArgumentFailures;

        System.out.printf(
                "mode=%s returnValuesFailures=%d methodArgumentsFailures=%d totalFailures=%d%n",
                guarded ? "guarded" : patched ? "patched" : "unguarded",
                returnValueFailures,
                methodArgumentFailures,
                failures);
        if (((guarded || patched) && failures != 0) || (!guarded && !patched && failures == 0)) {
            System.exit(1);
        }
    }

    public static void invokedNoOp() throws Exception {
        int order = INVOKER_ORDER.incrementAndGet();
        INVOKER_BARRIER.await();
        if ((order & 1) == 0) Thread.sleep(50L);
    }

    public static void invokedImmediate() {}

    @SuppressWarnings("unchecked")
    private static int exerciseInvokerRecovery(boolean inFlightRecovery) throws Exception {
        Field poolsField = MethodArguments.class.getDeclaredField("Pools");
        poolsField.setAccessible(true);
        ArrayList<MethodArguments> methodPool = ((ArrayList<MethodArguments>[]) poolsField.get(null))[0];
        MethodArguments duplicate = new MethodArguments(0);
        synchronized (methodPool) {
            methodPool.clear();
            if (!inFlightRecovery) {
                methodPool.add(duplicate);
                methodPool.add(duplicate);
            }
        }

        Field returnPoolField = ReturnValues.class.getDeclaredField("Pool");
        returnPoolField.setAccessible(true);
        ArrayList<ReturnValues> returnPool = (ArrayList<ReturnValues>) returnPoolField.get(null);
        Constructor<ReturnValues> constructor = ReturnValues.class.getDeclaredConstructor(
                KahluaConverterManager.class,
                LuaCallFrame.class);
        constructor.setAccessible(true);
        synchronized (returnPool) {
            returnPool.clear();
            for (int index = 0; index < THREADS; index++) {
                returnPool.add(constructor.newInstance(null, null));
            }
        }

        if (inFlightRecovery) {
            ReturnValues activationProbe = ReturnValues.get(null, null);
            ReturnValues.put(activationProbe);
        }

        J2SEPlatform platform = J2SEPlatform.getInstance();
        KahluaTable environment = platform.newTable();
        KahluaConverterManager manager = new KahluaConverterManager();
        LuaJavaClassExposer exposer = new LuaJavaClassExposer(manager, platform, environment);
        Method method = KahluaObjectPoolRaceHarness.class.getMethod(
                inFlightRecovery ? "invokedImmediate" : "invokedNoOp");
        LuaJavaInvoker invoker = new LuaJavaInvoker(
                exposer,
                manager,
                KahluaObjectPoolRaceHarness.class,
                "invokedNoOp",
                new MethodCaller(method, null, false));

        if (inFlightRecovery) {
            AtomicInteger failures = new AtomicInteger();
            MethodArguments.put(duplicate);
            LuaCallFrame frame = new LuaCallFrame(new Coroutine(platform, environment));
            MethodArguments arguments = invoker.prepareCall(frame, 0);
            MethodArguments.put(duplicate);
            try {
                int result = invoker.call(arguments);
                ReturnValues.put(arguments.getReturnValues());
                MethodArguments.put(arguments);
                if (result != 0) failures.incrementAndGet();
            } catch (Throwable failure) {
                failures.incrementAndGet();
            }
            return failures.get();
        }

        int recoveryThreads = 2;
        CountDownLatch ready = new CountDownLatch(recoveryThreads);
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch finished = new CountDownLatch(recoveryThreads);
        AtomicInteger failures = new AtomicInteger();
        Map<MethodArguments, Boolean> active = Collections.synchronizedMap(new IdentityHashMap<>());
        for (int threadIndex = 0; threadIndex < recoveryThreads; threadIndex++) {
            Thread worker = new Thread(() -> {
                ready.countDown();
                try {
                    start.await();
                    LuaCallFrame frame = new LuaCallFrame(new Coroutine(platform, environment));
                    MethodArguments arguments = invoker.prepareCall(frame, 0);
                    if (active.put(arguments, Boolean.TRUE) != null) failures.incrementAndGet();
                    int result = invoker.call(arguments);
                    ReturnValues.put(arguments.getReturnValues());
                    MethodArguments.put(arguments);
                    if (result != 0) failures.incrementAndGet();
                } catch (Throwable failure) {
                    failures.incrementAndGet();
                } finally {
                    finished.countDown();
                }
            }, "kahlua-invoker-recovery-" + threadIndex);
            worker.start();
        }
        ready.await();
        start.countDown();
        finished.await();
        return failures.get();
    }

    @SuppressWarnings("unchecked")
    private static int exerciseReturnValues(boolean guarded, boolean patched) throws Exception {
        Field poolField = ReturnValues.class.getDeclaredField("Pool");
        poolField.setAccessible(true);
        ArrayList<ReturnValues> pool = (ArrayList<ReturnValues>) poolField.get(null);
        Constructor<ReturnValues> constructor = ReturnValues.class.getDeclaredConstructor(
                se.krka.kahlua.converter.KahluaConverterManager.class,
                se.krka.kahlua.vm.LuaCallFrame.class);
        constructor.setAccessible(true);
        synchronized (pool) {
            pool.clear();
            for (int index = 0; index < 128; index++) {
                pool.add(constructor.newInstance(null, null));
            }
        }

        Checkin<ReturnValues> checkin = patched ? ReturnValues::put : pool::add;
        return runWorkers(guarded, () -> ReturnValues.get(null, null), checkin);
    }

    @SuppressWarnings("unchecked")
    private static int exerciseMethodArguments(boolean guarded, boolean patched) throws Exception {
        Field poolsField = MethodArguments.class.getDeclaredField("Pools");
        poolsField.setAccessible(true);
        ArrayList<MethodArguments>[] pools = (ArrayList<MethodArguments>[]) poolsField.get(null);
        ArrayList<MethodArguments> pool = pools[0];
        synchronized (pool) {
            pool.clear();
            for (int index = 0; index < 128; index++) {
                pool.add(new MethodArguments(0));
            }
        }

        Checkin<MethodArguments> checkin = patched ? MethodArguments::put : pool::add;
        return runWorkers(guarded, () -> MethodArguments.get(0), checkin);
    }

    private static <T> int runWorkers(boolean guarded, Checkout<T> checkout, Checkin<T> checkin)
            throws InterruptedException {
        CountDownLatch ready = new CountDownLatch(THREADS);
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch finished = new CountDownLatch(THREADS);
        AtomicInteger failures = new AtomicInteger();
        Map<T, Boolean> active = Collections.synchronizedMap(new IdentityHashMap<>());

        for (int threadIndex = 0; threadIndex < THREADS; threadIndex++) {
            Thread worker = new Thread(() -> {
                ready.countDown();
                try {
                    start.await();
                    for (int iteration = 0; iteration < ITERATIONS; iteration++) {
                        T value = null;
                        try {
                            if (guarded) POOL_LOCK.lock();
                            try {
                                value = checkout.get();
                            } finally {
                                if (guarded) POOL_LOCK.unlock();
                            }
                            if (value == null || active.put(value, Boolean.TRUE) != null) {
                                failures.incrementAndGet();
                            }
                            Thread.yield();
                        } catch (Throwable failure) {
                            failures.incrementAndGet();
                        } finally {
                            if (value != null) {
                                active.remove(value);
                                if (guarded) POOL_LOCK.lock();
                                try {
                                    checkin.accept(value);
                                } catch (Throwable failure) {
                                    failures.incrementAndGet();
                                } finally {
                                    if (guarded) POOL_LOCK.unlock();
                                }
                            }
                        }
                    }
                } catch (InterruptedException failure) {
                    Thread.currentThread().interrupt();
                    failures.incrementAndGet();
                } finally {
                    finished.countDown();
                }
            }, "kahlua-pool-race-" + threadIndex);
            worker.start();
        }

        ready.await();
        start.countDown();
        finished.await();
        return failures.get();
    }

    @FunctionalInterface
    private interface Checkout<T> {
        T get();
    }

    @FunctionalInterface
    private interface Checkin<T> {
        void accept(T value);
    }
}
