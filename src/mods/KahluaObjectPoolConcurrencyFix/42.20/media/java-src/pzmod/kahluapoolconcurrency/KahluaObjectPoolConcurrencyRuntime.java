package pzmod.kahluapoolconcurrency;

import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.locks.ReentrantLock;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.expose.MethodArguments;
import se.krka.kahlua.integration.expose.ReturnValues;
import se.krka.kahlua.vm.LuaCallFrame;

public final class KahluaObjectPoolConcurrencyRuntime {
    private static final int ARGUMENT_POOL_COUNT = 30;
    private static final ReentrantLock POOL_LOCK = new ReentrantLock();
    private static final AtomicBoolean REPORTED = new AtomicBoolean();
    private static final ArrayList<ReturnValues> RETURN_VALUES_POOL = new ArrayList<>();
    private static final WeakHashMap<ReturnValues, Boolean> ACTIVE_RETURN_VALUES = new WeakHashMap<>();
    private static final ArrayList<MethodArguments>[] METHOD_ARGUMENT_POOLS = createMethodArgumentPools();
    private static final WeakHashMap<MethodArguments, Boolean> ACTIVE_METHOD_ARGUMENTS = new WeakHashMap<>();
    private static Constructor<ReturnValues> returnValuesConstructor;
    private static Field returnValuesManagerField;
    private static Field returnValuesCallFrameField;
    private static Field returnValuesArgsField;
    private static Field methodArgumentsFailureField;
    private static Field methodArgumentsValidField;
    private static boolean initialized;

    private KahluaObjectPoolConcurrencyRuntime() {}

    public static ReturnValues acquireReturnValues(
            KahluaConverterManager converterManager,
            LuaCallFrame callFrame) {
        POOL_LOCK.lock();
        try {
            ensureInitialized();
            ReturnValues value = RETURN_VALUES_POOL.isEmpty()
                    ? returnValuesConstructor.newInstance(converterManager, callFrame)
                    : RETURN_VALUES_POOL.remove(RETURN_VALUES_POOL.size() - 1);
            returnValuesManagerField.set(value, converterManager);
            returnValuesCallFrameField.set(value, callFrame);
            returnValuesArgsField.setInt(value, 0);
            ACTIVE_RETURN_VALUES.put(value, Boolean.TRUE);
            return value;
        } catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("Unable to acquire isolated Kahlua return values", failure);
        } finally {
            POOL_LOCK.unlock();
        }
    }

    public static void releaseReturnValues(ReturnValues value) {
        POOL_LOCK.lock();
        try {
            ensureInitialized();
            if (value == null || ACTIVE_RETURN_VALUES.remove(value) == null) return;
            returnValuesManagerField.set(value, null);
            returnValuesCallFrameField.set(value, null);
            returnValuesArgsField.setInt(value, 0);
            RETURN_VALUES_POOL.add(value);
        } catch (IllegalAccessException failure) {
            throw new IllegalStateException("Unable to release isolated Kahlua return values", failure);
        } finally {
            POOL_LOCK.unlock();
        }
    }

    public static MethodArguments acquireMethodArguments(int argumentCount) {
        POOL_LOCK.lock();
        try {
            ensureInitialized();
            ArrayList<MethodArguments> pool = METHOD_ARGUMENT_POOLS[argumentCount];
            MethodArguments value = pool.isEmpty()
                    ? new MethodArguments(argumentCount)
                    : pool.remove(pool.size() - 1);
            ACTIVE_METHOD_ARGUMENTS.put(value, Boolean.TRUE);
            return value;
        } finally {
            POOL_LOCK.unlock();
        }
    }

    public static void releaseMethodArguments(MethodArguments value) {
        POOL_LOCK.lock();
        try {
            ensureInitialized();
            if (value == null || ACTIVE_METHOD_ARGUMENTS.remove(value) == null) return;
            value.setSelf(null);
            value.setReturnValues(null);
            Arrays.fill(value.getParams(), null);
            methodArgumentsFailureField.set(value, null);
            methodArgumentsValidField.setBoolean(value, true);
            METHOD_ARGUMENT_POOLS[value.getParams().length].add(value);
        } catch (IllegalAccessException failure) {
            throw new IllegalStateException("Unable to release isolated Kahlua method arguments", failure);
        } finally {
            POOL_LOCK.unlock();
        }
    }

    private static void ensureInitialized() {
        if (initialized) return;
        try {
            returnValuesConstructor = ReturnValues.class.getDeclaredConstructor(
                    KahluaConverterManager.class,
                    LuaCallFrame.class);
            returnValuesConstructor.setAccessible(true);
            returnValuesManagerField = accessibleField(ReturnValues.class, "manager");
            returnValuesCallFrameField = accessibleField(ReturnValues.class, "callFrame");
            returnValuesArgsField = accessibleField(ReturnValues.class, "args");
            methodArgumentsFailureField = accessibleField(MethodArguments.class, "failure");
            methodArgumentsValidField = accessibleField(MethodArguments.class, "valid");
            initialized = true;
            if (REPORTED.compareAndSet(false, true)) {
                System.out.println("[KahluaObjectPoolConcurrencyFix] Isolated object pools active; legacy pool returns quarantined.");
            }
        } catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("Unable to initialize isolated Kahlua object pools", failure);
        }
    }

    private static Field accessibleField(Class<?> type, String name) throws NoSuchFieldException {
        Field field = type.getDeclaredField(name);
        field.setAccessible(true);
        return field;
    }

    @SuppressWarnings("unchecked")
    private static ArrayList<MethodArguments>[] createMethodArgumentPools() {
        ArrayList<MethodArguments>[] pools = (ArrayList<MethodArguments>[]) new ArrayList<?>[ARGUMENT_POOL_COUNT];
        for (int index = 0; index < pools.length; index++) pools[index] = new ArrayList<>();
        return pools;
    }
}
