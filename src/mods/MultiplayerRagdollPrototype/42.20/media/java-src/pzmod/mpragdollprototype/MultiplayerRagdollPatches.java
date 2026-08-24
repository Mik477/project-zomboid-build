package pzmod.mpragdollprototype;

import me.zed_0xff.zombie_buddy.Patch;

public final class MultiplayerRagdollPatches {
    private MultiplayerRagdollPatches() {}

    @Patch(className = "zombie.characters.IsoGameCharacter", methodName = "hitConsequences")
    public static final class HitConsequences {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Object target,
                @Patch.Argument(0) Object weapon,
                @Patch.Argument(1) Object wielder,
                @Patch.Argument(2) boolean ignoreDamage,
                @Patch.Argument(3) float damage,
                @Patch.Argument(4) boolean remote) {
            PrototypeRuntime.enterHitConsequences(
                    target,
                    weapon,
                    wielder,
                    ignoreDamage,
                    damage,
                    remote);
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object target,
                @Patch.Thrown Throwable thrown) {
            PrototypeRuntime.exitHitConsequences(target, thrown);
        }
    }

    @Patch(className = "zombie.characters.IsoGameCharacter", methodName = "applyDamage")
    public static final class ApplyDamage {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Object target,
                @Patch.Argument(0) float damage) {
            PrototypeRuntime.beforeApplyDamage(target, damage);
        }
    }

    @Patch(className = "zombie.characters.IsoZombie", methodName = "update")
    public static final class ZombieUpdate {
        @Patch.OnExit
        public static void exit(@Patch.This Object zombie) {
            PrototypeRuntime.sampleZombieMovement(zombie);
        }
    }

    @Patch(className = "zombie.ai.states.ZombieFallDownState", methodName = "execute")
    public static final class ZombieFallDownExecute {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) Object character) {
            return PrototypeRuntime.shouldDeferFallDownExecution(character);
        }
    }

    @Patch(className = "zombie.characters.NetworkCharacterAI", methodName = "isDeadBodyTimeout")
    public static final class NetworkCharacterDeadBodyTimeout {
        @Patch.OnExit
        public static void exit(
                @Patch.This Object networkCharacterAI,
                @Patch.Return(readOnly = false) boolean result) {
            if (result && PrototypeRuntime.shouldDeferDeadBodyTimeout(networkCharacterAI)) {
                result = false;
            }
        }
    }

    @Patch(className = "zombie.core.physics.RagdollController", methodName = "simulateHitReaction")
    public static final class RagdollHitReaction {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.This Object ragdollController) {
            return PrototypeRuntime.replaceHitReaction(ragdollController);
        }
    }

    @Patch(
            className = "zombie.core.physics.RagdollController",
            methodName = "uploadAnimationBonePreviousTransformsToRagdoll")
    public static final class RagdollInitialVelocities {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.This Object ragdollController) {
            return PrototypeRuntime.shouldSuppressInitialVelocities(ragdollController);
        }
    }

    @Patch(className = "zombie.core.physics.RagdollController", methodName = "addToWorld")
    public static final class RagdollAddToWorld {
        @Patch.OnEnter
        public static void enter(@Patch.This Object ragdollController) {
            PrototypeRuntime.beforeAddRagdollToWorld(ragdollController);
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object ragdollController,
                @Patch.Thrown Throwable thrown) {
            PrototypeRuntime.afterAddRagdollToWorld(ragdollController, thrown);
        }
    }

    @Patch(className = "zombie.core.physics.RagdollController", methodName = "update")
    public static final class RagdollUpdate {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Object ragdollController,
                @Patch.Argument(0) float deltaT) {
            PrototypeRuntime.prepareRagdollFrame(ragdollController, deltaT);
        }

        @Patch.OnExit
        public static void exit(@Patch.This Object ragdollController) {
            PrototypeRuntime.finishRagdollFrame(ragdollController);
        }
    }

    @Patch(className = "zombie.core.physics.RagdollController", methodName = "simulateRagdoll")
    public static final class RagdollSimulation {
        @Patch.OnExit
        public static void exit(
                @Patch.This Object ragdollController,
                @Patch.Argument(5) float[] rigidBodyBuffer) {
            PrototypeRuntime.captureRagdollFrame(ragdollController, rigidBodyBuffer);
        }
    }

    @Patch(className = "zombie.core.physics.RagdollController", methodName = "postUpdate")
    public static final class RagdollPostUpdate {
        @Patch.OnExit
        public static void exit(
                @Patch.This Object ragdollController,
                @Patch.Argument(0) float deltaT) {
            PrototypeRuntime.updateRagdollController(ragdollController, deltaT);
        }
    }

    @Patch(className = "zombie.network.packets.character.DeadCharacterPacket", methodName = "processClient")
    public static final class DeadCharacterProcessClient {
        @Patch.OnEnter
        public static void enter(@Patch.This Object packet) {
            PrototypeRuntime.enterDeathPacket(packet);
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(@Patch.This Object packet) {
            PrototypeRuntime.exitDeathPacket(packet);
        }
    }

    @Patch(className = "zombie.characters.IsoGameCharacter", methodName = "canRagdoll")
    public static final class CanRagdoll {
        @Patch.OnExit
        public static void exit(
                @Patch.This Object character,
                @Patch.Return(readOnly = false) boolean result) {
            if (!result) {
                result = PrototypeRuntime.canRagdoll(character);
            }
        }
    }

    @Patch(className = "zombie.characters.IsoGameCharacter", methodName = "canUseCurrentPoseForCorpse")
    public static final class CanUseCurrentPoseForCorpse {
        @Patch.OnExit
        public static void exit(
                @Patch.This Object character,
                @Patch.Return(readOnly = false) boolean result) {
            if (!result) {
                result = PrototypeRuntime.canCaptureCorpsePose(character);
            }
        }
    }
}
