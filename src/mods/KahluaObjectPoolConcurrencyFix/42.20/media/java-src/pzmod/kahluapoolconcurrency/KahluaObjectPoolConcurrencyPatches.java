package pzmod.kahluapoolconcurrency;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.expose.MethodArguments;
import se.krka.kahlua.integration.expose.ReturnValues;
import se.krka.kahlua.vm.LuaCallFrame;

public final class KahluaObjectPoolConcurrencyPatches {
    private KahluaObjectPoolConcurrencyPatches() {}

    @Patch(
            className = "se.krka.kahlua.integration.expose.ReturnValues",
            methodName = "get",
            strictMatch = true)
    public static final class ReturnValuesGet {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(
                @Patch.Argument(0) KahluaConverterManager converterManager,
                @Patch.Argument(1) LuaCallFrame callFrame) {
            return true;
        }

        @Patch.OnExit
        public static void exit(
                @Patch.Argument(0) KahluaConverterManager converterManager,
                @Patch.Argument(1) LuaCallFrame callFrame,
                @Patch.Return(readOnly = false) ReturnValues returnValues) {
            returnValues = KahluaObjectPoolConcurrencyRuntime.acquireReturnValues(converterManager, callFrame);
        }
    }

    @Patch(
            className = "se.krka.kahlua.integration.expose.ReturnValues",
            methodName = "put",
            strictMatch = true)
    public static final class ReturnValuesPut {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) ReturnValues returnValues) {
            KahluaObjectPoolConcurrencyRuntime.releaseReturnValues(returnValues);
            return true;
        }
    }

    @Patch(
            className = "se.krka.kahlua.integration.expose.MethodArguments",
            methodName = "get",
            strictMatch = true)
    public static final class MethodArgumentsGet {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) int argumentCount) {
            return true;
        }

        @Patch.OnExit
        public static void exit(
                @Patch.Argument(0) int argumentCount,
                @Patch.Return(readOnly = false) MethodArguments methodArguments) {
            methodArguments = KahluaObjectPoolConcurrencyRuntime.acquireMethodArguments(argumentCount);
        }
    }

    @Patch(
            className = "se.krka.kahlua.integration.expose.MethodArguments",
            methodName = "put",
            strictMatch = true)
    public static final class MethodArgumentsPut {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) MethodArguments methodArguments) {
            KahluaObjectPoolConcurrencyRuntime.releaseMethodArguments(methodArguments);
            return true;
        }
    }
}
