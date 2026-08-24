package pzmod.mpragdollprototype;

public final class RigidBodyTelemetry {
    public static final int BODY_COUNT = 11;
    public static final int BODY_STRIDE = 7;
    public static final int BUFFER_LENGTH = BODY_COUNT * BODY_STRIDE;
    public static final int JOINT_COUNT = 10;
    public static final int CAPTURE_INVALID_LENGTH = 0;
    public static final int CAPTURE_DEFERRED_FIRST_FRAME = 1;
    public static final int CAPTURE_INVALID_VALUES = 2;
    public static final int CAPTURE_BASELINE = 3;
    public static final int CAPTURE_UPDATED = 4;

    private static final String[] BODY_NAMES = {
        "pelvis", "spine", "head", "leftUpperLeg", "leftLowerLeg",
        "rightUpperLeg", "rightLowerLeg", "leftUpperArm", "leftLowerArm",
        "rightUpperArm", "rightLowerArm"
    };
    private static final float[] DEFAULT_BODY_MASSES = {
        0.1481f, 0.3111f, 0.0823f, 0.11125f, 0.0643f, 0.11125f,
        0.0643f, 0.03075f, 0.02295f, 0.03075f, 0.02295f
    };
    private static final int[] JOINT_PARENTS = {0, 1, 0, 3, 0, 5, 1, 7, 1, 9};
    private static final int[] JOINT_CHILDREN = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    private static final String[] JOINT_NAMES = {
        "pelvisSpine", "spineHead", "leftHip", "leftKnee", "rightHip",
        "rightKnee", "leftShoulder", "leftElbow", "rightShoulder", "rightElbow"
    };
    private static final int[] SNAPSHOT_FRAMES = {
        1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256
    };
    private static final int[] ARM_BODY_PARTS = {7, 8, 9, 10};
    private static final int[] ARM_JOINTS = {6, 7, 8, 9};
    private static final int[] CORE_BODY_PARTS = {0, 1, 2, 3, 4, 5, 6};
    private static final int[] CORE_JOINTS = {0, 1, 2, 3, 4, 5};

    private final float movementDirectionX;
    private final float movementDirectionZ;
    private final float[] bodyMasses;
    private final float totalMass;
    private final float torsoMass;
    private float[] latest = new float[BUFFER_LENGTH];
    private float[] previous = new float[BUFFER_LENGTH];
    private float[] scratch = new float[BUFFER_LENGTH];
    private final float[] baseline = new float[BUFFER_LENGTH];
    private final float[] linearVelocity = new float[BODY_COUNT * 3];
    private final float[] angularVelocity = new float[BODY_COUNT * 3];
    private final float[] relativeLinearSpeed = new float[BODY_COUNT];
    private final float[] relativeAngularSpeed = new float[BODY_COUNT];
    private final float[] maxLinearSpeed = new float[BODY_COUNT];
    private final float[] maxAngularSpeed = new float[BODY_COUNT];
    private final float[] maxRelativeLinearSpeed = new float[BODY_COUNT];
    private final float[] maxRelativeAngularSpeed = new float[BODY_COUNT];
    private final int[] maxRelativeLinearSpeedFrame = new int[BODY_COUNT];
    private final int[] maxRelativeAngularSpeedFrame = new int[BODY_COUNT];
    private final float[] maxRelativeLinearSpeedSeconds = new float[BODY_COUNT];
    private final float[] maxRelativeAngularSpeedSeconds = new float[BODY_COUNT];
    private final float[] maxAirborneRelativeLinearSpeed = new float[BODY_COUNT];
    private final float[] maxAirborneRelativeAngularSpeed = new float[BODY_COUNT];
    private final float[] maxOnFloorRelativeLinearSpeed = new float[BODY_COUNT];
    private final float[] maxOnFloorRelativeAngularSpeed = new float[BODY_COUNT];
    private final float[] bodyPathLength = new float[BODY_COUNT];
    private final float[] maxOpeningDisplacement = new float[BODY_COUNT];
    private final float[] baselineJointDistance = new float[JOINT_COUNT];
    private final float[] currentJointDistance = new float[JOINT_COUNT];
    private final float[] currentJointDistanceDelta = new float[JOINT_COUNT];
    private final float[] currentJointAngularDeviation = new float[JOINT_COUNT];
    private final float[] maxJointStretch = new float[JOINT_COUNT];
    private final float[] maxJointCompression = new float[JOINT_COUNT];
    private final float[] maxJointAngularDeviation = new float[JOINT_COUNT];
    private final int[] maxJointAngularDeviationFrame = new int[JOINT_COUNT];
    private final float[] maxJointAngularDeviationSeconds = new float[JOINT_COUNT];
    private final float[] baselineJointRotation = new float[JOINT_COUNT * 4];
    private final float[] work = new float[4];

    private boolean baselineCaptured;
    private int callbackCount;
    private int validFrameCount;
    private int deferredFirstFrameCount;
    private int invalidFrameCount;
    private long lastCaptureNanos;
    private float currentDeltaSeconds;
    private float currentWallDeltaSeconds;
    private float elapsedSeconds;
    private float baselineComX;
    private float baselineComY;
    private float baselineComZ;
    private float currentComX;
    private float currentComY;
    private float currentComZ;
    private float currentComVelocityX;
    private float currentComVelocityY;
    private float currentComVelocityZ;
    private float currentForwardVelocity;
    private float currentLateralVelocity;
    private float currentVelocityCoherenceRms;
    private float currentMaxBodyRelativeSpeed;
    private float comPathLength;
    private float maxComSpeed;
    private float maxForwardVelocity;
    private float maxBackwardVelocity;
    private float maxLateralVelocity;
    private float maxUpwardVelocity;
    private float maxDownwardVelocity;
    private float maxVelocityCoherenceRms;
    private float maxBodyRelativeSpeed;
    private int firstSleepingFrame = -1;
    private int firstOnFloorFrame = -1;
    private int firstNotUprightFrame = -1;
    private float firstSleepingSeconds = Float.NaN;
    private float firstOnFloorSeconds = Float.NaN;
    private float firstNotUprightSeconds = Float.NaN;
    private boolean latestSleeping;
    private boolean latestOnFloor;
    private boolean latestUpright = true;
    private boolean latestOnBack;

    public RigidBodyTelemetry(float movementDirectionX, float movementDirectionZ) {
        this(movementDirectionX, movementDirectionZ, DEFAULT_BODY_MASSES);
    }

    public RigidBodyTelemetry(
            float movementDirectionX,
            float movementDirectionZ,
            float[] bodyMasses) {
        if (bodyMasses == null || bodyMasses.length != BODY_COUNT) {
            throw new IllegalArgumentException("bodyMasses must contain " + BODY_COUNT + " values");
        }
        this.bodyMasses = bodyMasses.clone();
        for (float mass : this.bodyMasses) {
            if (!isFinite(mass) || !(mass > 0.0f)) {
                throw new IllegalArgumentException("bodyMasses must be finite and positive");
            }
        }
        this.totalMass = sum(this.bodyMasses, 0, BODY_COUNT);
        this.torsoMass = sum(this.bodyMasses, 0, 3);
        float directionLength = length(movementDirectionX, movementDirectionZ);
        if (directionLength > 0.0001f) {
            this.movementDirectionX = movementDirectionX / directionLength;
            this.movementDirectionZ = movementDirectionZ / directionLength;
        } else {
            this.movementDirectionX = 0.0f;
            this.movementDirectionZ = 0.0f;
        }
    }

    public int capture(float[] source, float simulationDeltaSeconds, long captureNanos,
            boolean controllerFirstFrame) {
        callbackCount++;
        if (source == null || source.length < BUFFER_LENGTH) {
            invalidFrameCount++;
            return CAPTURE_INVALID_LENGTH;
        }
        System.arraycopy(source, 0, scratch, 0, BUFFER_LENGTH);
        if (controllerFirstFrame) {
            deferredFirstFrameCount++;
            return CAPTURE_DEFERRED_FIRST_FRAME;
        }
        if (!hasValidValues(scratch)) {
            invalidFrameCount++;
            return CAPTURE_INVALID_VALUES;
        }

        currentWallDeltaSeconds = lastCaptureNanos > 0L && captureNanos > lastCaptureNanos
                ? (captureNanos - lastCaptureNanos) / 1_000_000_000.0f
                : Float.NaN;
        lastCaptureNanos = captureNanos;
        currentDeltaSeconds = sanitizeDeltaSeconds(simulationDeltaSeconds, currentWallDeltaSeconds);
        rotateBuffers();
        if (!baselineCaptured) {
            captureBaseline();
            return CAPTURE_BASELINE;
        }

        validFrameCount++;
        elapsedSeconds += currentDeltaSeconds;
        updateBodyMetrics();
        updateCenterOfMassMetrics();
        updateJointMetrics();
        return CAPTURE_UPDATED;
    }

    public boolean hasBaseline() { return baselineCaptured; }
    public int getCallbackCount() { return callbackCount; }
    public int getValidFrameCount() { return validFrameCount; }
    public int getDeferredFirstFrameCount() { return deferredFirstFrameCount; }
    public int getInvalidFrameCount() { return invalidFrameCount; }
    public float getComDisplacementX() { return baselineCaptured ? currentComX - baselineComX : Float.NaN; }
    public float getComDisplacementY() { return baselineCaptured ? currentComY - baselineComY : Float.NaN; }
    public float getComDisplacementZ() { return baselineCaptured ? currentComZ - baselineComZ : Float.NaN; }
    public float getElapsedSeconds() { return elapsedSeconds; }
    public float getCurrentForwardDisplacement() {
        if (!baselineCaptured) return Float.NaN;
        return (currentComX - baselineComX) * movementDirectionX
                + (currentComZ - baselineComZ) * movementDirectionZ;
    }
    public float getCurrentForwardVelocity() { return currentForwardVelocity; }
    public float getCurrentVelocityCoherenceRms() { return currentVelocityCoherenceRms; }
    public float getMaxOpeningDisplacement(int bodyPart) { return maxOpeningDisplacement[bodyPart]; }
    public float getMaxRelativeAngularSpeed(int bodyPart) { return maxRelativeAngularSpeed[bodyPart]; }
    public float getMaxJointStretch(int joint) { return maxJointStretch[joint]; }
    public float getMaxJointAngularDeviation(int joint) { return maxJointAngularDeviation[joint]; }

    public float getParentVelocityCorrection(int bodyPart, float[] output) {
        if (output == null || output.length < 3 || validFrameCount <= 0
                || bodyPart < 0 || bodyPart >= BODY_COUNT) {
            return Float.NaN;
        }
        int parentBody = parentBodyPart(bodyPart);
        if (parentBody < 0) {
            return Float.NaN;
        }
        int parentOffset = parentBody * 3;
        int bodyOffset = bodyPart * 3;
        output[0] = linearVelocity[parentOffset] - linearVelocity[bodyOffset];
        output[1] = linearVelocity[parentOffset + 1] - linearVelocity[bodyOffset + 1];
        output[2] = linearVelocity[parentOffset + 2] - linearVelocity[bodyOffset + 2];
        return length(output[0], output[1], output[2]);
    }

    public static String bodyName(int bodyPart) {
        return bodyPart >= 0 && bodyPart < BODY_NAMES.length ? BODY_NAMES[bodyPart] : "unknown";
    }

    public void observeState(boolean sleeping, boolean onFloor, boolean upright, boolean onBack) {
        latestSleeping = sleeping;
        latestOnFloor = onFloor;
        latestUpright = upright;
        latestOnBack = onBack;
        if (validFrameCount <= 0) return;
        if (sleeping && firstSleepingFrame < 0) {
            firstSleepingFrame = validFrameCount;
            firstSleepingSeconds = elapsedSeconds;
        }
        if (onFloor && firstOnFloorFrame < 0) {
            firstOnFloorFrame = validFrameCount;
            firstOnFloorSeconds = elapsedSeconds;
        }
        if (!upright && firstNotUprightFrame < 0) {
            firstNotUprightFrame = validFrameCount;
            firstNotUprightSeconds = elapsedSeconds;
        }
    }

    public static boolean shouldLogSnapshot(int validFrame) {
        for (int snapshotFrame : SNAPSHOT_FRAMES) {
            if (snapshotFrame == validFrame) return true;
        }
        return false;
    }

    public String frameDetails() {
        StringBuilder builder = new StringBuilder(2600);
        builder.append("frame=").append(validFrameCount)
                .append(" callbacks=").append(callbackCount)
                .append(" simDt=").append(currentDeltaSeconds)
                .append(" wallDt=").append(currentWallDeltaSeconds)
                .append(" elapsed=").append(elapsedSeconds)
                .append(" comDelta=");
        appendVector(builder, getComDisplacementX(), getComDisplacementY(), getComDisplacementZ());
        builder.append(" comVelocity=");
        appendVector(builder, currentComVelocityX, currentComVelocityY, currentComVelocityZ);
        builder.append(" forwardVelocity=").append(currentForwardVelocity)
                .append(" lateralVelocity=").append(currentLateralVelocity)
                .append(" verticalVelocity=").append(currentComVelocityY)
                .append(" coherenceRms=").append(currentVelocityCoherenceRms)
                .append(" maxBodyRelativeSpeed=").append(currentMaxBodyRelativeSpeed)
                .append(" sleeping=").append(latestSleeping)
                .append(" onFloor=").append(latestOnFloor)
                .append(" upright=").append(latestUpright)
                .append(" onBack=").append(latestOnBack)
                .append(" bodies=");
        appendBodyFrame(builder);
        return builder.toString();
    }

    public String jointFrameDetails() {
        StringBuilder builder = new StringBuilder(1100);
        builder.append("frame=").append(validFrameCount).append(" joints=");
        for (int joint = 0; joint < JOINT_COUNT; joint++) {
            if (joint > 0) builder.append(';');
            builder.append(JOINT_NAMES[joint]).append("{distance=")
                    .append(currentJointDistance[joint])
                    .append(",delta=").append(currentJointDistanceDelta[joint])
                    .append(",angleDelta=").append(currentJointAngularDeviation[joint])
                    .append('}');
        }
        return builder.toString();
    }

    public String summaryDetails(String reason) {
        StringBuilder builder = new StringBuilder(760);
        builder.append("reason=").append(reason)
                .append(" callbacks=").append(callbackCount)
                .append(" validFrames=").append(validFrameCount)
                .append(" deferredFirstFrames=").append(deferredFirstFrameCount)
                .append(" invalidFrames=").append(invalidFrameCount)
                .append(" elapsed=").append(elapsedSeconds)
                .append(" totalMass=").append(totalMass)
                .append(" comDelta=");
        appendVector(builder, getComDisplacementX(), getComDisplacementY(), getComDisplacementZ());
        builder.append(" comPath=").append(comPathLength)
                .append(" maxComSpeed=").append(maxComSpeed)
                .append(" maxForward=").append(maxForwardVelocity)
                .append(" maxBackward=").append(maxBackwardVelocity)
                .append(" maxLateral=").append(maxLateralVelocity)
                .append(" maxUpward=").append(maxUpwardVelocity)
                .append(" maxDownward=").append(maxDownwardVelocity)
                .append(" maxCoherenceRms=").append(maxVelocityCoherenceRms)
                .append(" maxBodyRelativeSpeed=").append(maxBodyRelativeSpeed)
                .append(" firstNotUprightFrame=").append(firstNotUprightFrame)
                .append(" firstNotUprightSeconds=").append(firstNotUprightSeconds)
                .append(" firstOnFloorFrame=").append(firstOnFloorFrame)
                .append(" firstOnFloorSeconds=").append(firstOnFloorSeconds)
                .append(" firstSleepingFrame=").append(firstSleepingFrame)
                .append(" firstSleepingSeconds=").append(firstSleepingSeconds)
                .append(" finalSleeping=").append(latestSleeping)
                .append(" finalOnFloor=").append(latestOnFloor)
                .append(" finalUpright=").append(latestUpright)
                .append(" finalOnBack=").append(latestOnBack);
        return builder.toString();
    }

    public String armFrameDetails() {
        StringBuilder builder = new StringBuilder(900);
        builder.append("frame=").append(validFrameCount)
                .append(" elapsed=").append(elapsedSeconds)
                .append(" phase=").append(latestOnFloor ? "on-floor" : "airborne")
                .append(" arms=");
        for (int index = 0; index < ARM_BODY_PARTS.length; index++) {
            int bodyPart = ARM_BODY_PARTS[index];
            if (index > 0) builder.append(';');
            builder.append(BODY_NAMES[bodyPart]).append("{mass=")
                    .append(bodyMasses[bodyPart])
                    .append(",relativeLinear=").append(relativeLinearSpeed[bodyPart])
                    .append(",relativeAngular=").append(relativeAngularSpeed[bodyPart])
                    .append(",opening=").append(openingDisplacement(bodyPart))
                    .append(",maxRelativeLinear=").append(maxRelativeLinearSpeed[bodyPart])
                    .append('@').append(maxRelativeLinearSpeedFrame[bodyPart])
                    .append(",maxRelativeAngular=").append(maxRelativeAngularSpeed[bodyPart])
                    .append('@').append(maxRelativeAngularSpeedFrame[bodyPart])
                    .append('}');
        }
        builder.append(" armJoints=");
        for (int index = 0; index < ARM_JOINTS.length; index++) {
            int joint = ARM_JOINTS[index];
            if (index > 0) builder.append(';');
            builder.append(JOINT_NAMES[joint]).append("{distanceDelta=")
                    .append(currentJointDistanceDelta[joint])
                    .append(",angleDelta=").append(currentJointAngularDeviation[joint])
                    .append('}');
        }
        return builder.toString();
    }

    public String coreFrameDetails() {
        StringBuilder builder = new StringBuilder(1200);
        builder.append("frame=").append(validFrameCount)
                .append(" elapsed=").append(elapsedSeconds)
                .append(" phase=").append(latestOnFloor ? "on-floor" : "airborne")
                .append(" core=");
        for (int index = 0; index < CORE_BODY_PARTS.length; index++) {
            int bodyPart = CORE_BODY_PARTS[index];
            int velocityOffset = bodyPart * 3;
            if (index > 0) builder.append(';');
            builder.append(BODY_NAMES[bodyPart]).append("{linear=")
                    .append(length(
                            linearVelocity[velocityOffset],
                            linearVelocity[velocityOffset + 1],
                            linearVelocity[velocityOffset + 2]))
                    .append(",angular=").append(length(
                            angularVelocity[velocityOffset],
                            angularVelocity[velocityOffset + 1],
                            angularVelocity[velocityOffset + 2]))
                    .append(",relativeLinear=").append(relativeLinearSpeed[bodyPart])
                    .append(",relativeAngular=").append(relativeAngularSpeed[bodyPart])
                    .append(",opening=").append(openingDisplacement(bodyPart))
                    .append('}');
        }
        builder.append(" coreJoints=");
        for (int index = 0; index < CORE_JOINTS.length; index++) {
            int joint = CORE_JOINTS[index];
            if (index > 0) builder.append(';');
            builder.append(JOINT_NAMES[joint]).append("{distanceDelta=")
                    .append(currentJointDistanceDelta[joint])
                    .append(",angleDelta=").append(currentJointAngularDeviation[joint])
                    .append('}');
        }
        return builder.toString();
    }

    public String bodySummaryDetails() {
        StringBuilder builder = new StringBuilder(2500);
        builder.append("bodies=");
        for (int bodyPart = 0; bodyPart < BODY_COUNT; bodyPart++) {
            if (bodyPart > 0) builder.append(';');
            builder.append(BODY_NAMES[bodyPart]).append("{mass=")
                    .append(bodyMasses[bodyPart])
                    .append(",path=").append(bodyPathLength[bodyPart])
                    .append(",maxLinear=").append(maxLinearSpeed[bodyPart])
                    .append(",maxAngular=").append(maxAngularSpeed[bodyPart])
                    .append(",maxRelativeLinear=").append(maxRelativeLinearSpeed[bodyPart])
                    .append('@').append(maxRelativeLinearSpeedFrame[bodyPart])
                    .append('/').append(maxRelativeLinearSpeedSeconds[bodyPart])
                    .append(",maxRelativeAngular=").append(maxRelativeAngularSpeed[bodyPart])
                    .append('@').append(maxRelativeAngularSpeedFrame[bodyPart])
                    .append('/').append(maxRelativeAngularSpeedSeconds[bodyPart])
                    .append(",airRelativeLinear=").append(maxAirborneRelativeLinearSpeed[bodyPart])
                    .append(",airRelativeAngular=").append(maxAirborneRelativeAngularSpeed[bodyPart])
                    .append(",floorRelativeLinear=").append(maxOnFloorRelativeLinearSpeed[bodyPart])
                    .append(",floorRelativeAngular=").append(maxOnFloorRelativeAngularSpeed[bodyPart])
                    .append(",maxOpening=").append(maxOpeningDisplacement[bodyPart])
                    .append('}');
        }
        return builder.toString();
    }

    public String armSummaryDetails() {
        StringBuilder builder = new StringBuilder(1600);
        builder.append("arms=");
        for (int index = 0; index < ARM_BODY_PARTS.length; index++) {
            int bodyPart = ARM_BODY_PARTS[index];
            if (index > 0) builder.append(';');
            builder.append(BODY_NAMES[bodyPart]).append("{mass=")
                    .append(bodyMasses[bodyPart])
                    .append(",maxRelativeLinear=").append(maxRelativeLinearSpeed[bodyPart])
                    .append('@').append(maxRelativeLinearSpeedFrame[bodyPart])
                    .append('/').append(maxRelativeLinearSpeedSeconds[bodyPart])
                    .append(",maxRelativeAngular=").append(maxRelativeAngularSpeed[bodyPart])
                    .append('@').append(maxRelativeAngularSpeedFrame[bodyPart])
                    .append('/').append(maxRelativeAngularSpeedSeconds[bodyPart])
                    .append(",airLinear=").append(maxAirborneRelativeLinearSpeed[bodyPart])
                    .append(",airAngular=").append(maxAirborneRelativeAngularSpeed[bodyPart])
                    .append(",floorLinear=").append(maxOnFloorRelativeLinearSpeed[bodyPart])
                    .append(",floorAngular=").append(maxOnFloorRelativeAngularSpeed[bodyPart])
                    .append('}');
        }
        builder.append(" joints=");
        for (int index = 0; index < ARM_JOINTS.length; index++) {
            int joint = ARM_JOINTS[index];
            if (index > 0) builder.append(';');
            builder.append(JOINT_NAMES[joint]).append("{maxAngle=")
                    .append(maxJointAngularDeviation[joint])
                    .append('@').append(maxJointAngularDeviationFrame[joint])
                    .append('/').append(maxJointAngularDeviationSeconds[joint])
                    .append(",maxStretch=").append(maxJointStretch[joint])
                    .append(",maxCompression=").append(maxJointCompression[joint])
                    .append('}');
        }
        return builder.toString();
    }

    public String jointSummaryDetails() {
        StringBuilder builder = new StringBuilder(1500);
        builder.append("joints=");
        for (int joint = 0; joint < JOINT_COUNT; joint++) {
            if (joint > 0) builder.append(';');
            builder.append(JOINT_NAMES[joint]).append("{baseline=")
                    .append(baselineJointDistance[joint])
                    .append(",maxStretch=").append(maxJointStretch[joint])
                    .append(",maxCompression=").append(maxJointCompression[joint])
                    .append(",maxAngleDelta=").append(maxJointAngularDeviation[joint])
                    .append('@').append(maxJointAngularDeviationFrame[joint])
                    .append('/').append(maxJointAngularDeviationSeconds[joint])
                    .append('}');
        }
        return builder.toString();
    }

    private void rotateBuffers() {
        float[] oldPrevious = previous;
        previous = latest;
        latest = scratch;
        scratch = oldPrevious;
    }

    private void captureBaseline() {
        baselineCaptured = true;
        validFrameCount = 1;
        System.arraycopy(latest, 0, previous, 0, BUFFER_LENGTH);
        System.arraycopy(latest, 0, baseline, 0, BUFFER_LENGTH);
        calculateCenterOfMass(latest, work);
        baselineComX = work[0];
        baselineComY = work[1];
        baselineComZ = work[2];
        currentComX = baselineComX;
        currentComY = baselineComY;
        currentComZ = baselineComZ;
        for (int joint = 0; joint < JOINT_COUNT; joint++) {
            int parent = JOINT_PARENTS[joint];
            int child = JOINT_CHILDREN[joint];
            float distance = bodyDistance(latest, parent, child);
            baselineJointDistance[joint] = distance;
            currentJointDistance[joint] = distance;
            relativeQuaternion(latest, parent, child, work);
            System.arraycopy(work, 0, baselineJointRotation, joint * 4, 4);
        }
    }

    private void updateBodyMetrics() {
        float torsoVelocityX = 0.0f;
        float torsoVelocityY = 0.0f;
        float torsoVelocityZ = 0.0f;
        for (int bodyPart = 0; bodyPart < BODY_COUNT; bodyPart++) {
            int bodyOffset = bodyPart * BODY_STRIDE;
            int velocityOffset = bodyPart * 3;
            float velocityX = (latest[bodyOffset] - previous[bodyOffset]) / currentDeltaSeconds;
            float velocityY = (latest[bodyOffset + 1] - previous[bodyOffset + 1]) / currentDeltaSeconds;
            float velocityZ = (latest[bodyOffset + 2] - previous[bodyOffset + 2]) / currentDeltaSeconds;
            linearVelocity[velocityOffset] = velocityX;
            linearVelocity[velocityOffset + 1] = velocityY;
            linearVelocity[velocityOffset + 2] = velocityZ;
            angularVelocity(latest, previous, bodyPart, currentDeltaSeconds, angularVelocity, velocityOffset);
            bodyPathLength[bodyPart] += bodyDistance(latest, previous, bodyPart);
            maxLinearSpeed[bodyPart] = Math.max(maxLinearSpeed[bodyPart], length(velocityX, velocityY, velocityZ));
            maxAngularSpeed[bodyPart] = Math.max(maxAngularSpeed[bodyPart], length(
                    angularVelocity[velocityOffset], angularVelocity[velocityOffset + 1],
                    angularVelocity[velocityOffset + 2]));
            maxOpeningDisplacement[bodyPart] = Math.max(
                    maxOpeningDisplacement[bodyPart], openingDisplacement(bodyPart));
            if (bodyPart < 3) {
                float torsoWeight = bodyMasses[bodyPart] / torsoMass;
                torsoVelocityX += velocityX * torsoWeight;
                torsoVelocityY += velocityY * torsoWeight;
                torsoVelocityZ += velocityZ * torsoWeight;
            }
        }

        int spineVelocityOffset = 3;
        currentMaxBodyRelativeSpeed = 0.0f;
        for (int bodyPart = 0; bodyPart < BODY_COUNT; bodyPart++) {
            int velocityOffset = bodyPart * 3;
            float bodyRelativeLinearSpeed = length(
                    linearVelocity[velocityOffset] - torsoVelocityX,
                    linearVelocity[velocityOffset + 1] - torsoVelocityY,
                    linearVelocity[velocityOffset + 2] - torsoVelocityZ);
            float bodyRelativeAngularSpeed = length(
                    angularVelocity[velocityOffset] - angularVelocity[spineVelocityOffset],
                    angularVelocity[velocityOffset + 1] - angularVelocity[spineVelocityOffset + 1],
                    angularVelocity[velocityOffset + 2] - angularVelocity[spineVelocityOffset + 2]);
            relativeLinearSpeed[bodyPart] = bodyRelativeLinearSpeed;
            relativeAngularSpeed[bodyPart] = bodyRelativeAngularSpeed;
            if (bodyRelativeLinearSpeed > maxRelativeLinearSpeed[bodyPart]) {
                maxRelativeLinearSpeed[bodyPart] = bodyRelativeLinearSpeed;
                maxRelativeLinearSpeedFrame[bodyPart] = validFrameCount;
                maxRelativeLinearSpeedSeconds[bodyPart] = elapsedSeconds;
            }
            if (bodyRelativeAngularSpeed > maxRelativeAngularSpeed[bodyPart]) {
                maxRelativeAngularSpeed[bodyPart] = bodyRelativeAngularSpeed;
                maxRelativeAngularSpeedFrame[bodyPart] = validFrameCount;
                maxRelativeAngularSpeedSeconds[bodyPart] = elapsedSeconds;
            }
            if (latestOnFloor) {
                maxOnFloorRelativeLinearSpeed[bodyPart] = Math.max(
                        maxOnFloorRelativeLinearSpeed[bodyPart], bodyRelativeLinearSpeed);
                maxOnFloorRelativeAngularSpeed[bodyPart] = Math.max(
                        maxOnFloorRelativeAngularSpeed[bodyPart], bodyRelativeAngularSpeed);
            } else {
                maxAirborneRelativeLinearSpeed[bodyPart] = Math.max(
                        maxAirborneRelativeLinearSpeed[bodyPart], bodyRelativeLinearSpeed);
                maxAirborneRelativeAngularSpeed[bodyPart] = Math.max(
                        maxAirborneRelativeAngularSpeed[bodyPart], bodyRelativeAngularSpeed);
            }
            currentMaxBodyRelativeSpeed = Math.max(currentMaxBodyRelativeSpeed, bodyRelativeLinearSpeed);
        }
        maxBodyRelativeSpeed = Math.max(maxBodyRelativeSpeed, currentMaxBodyRelativeSpeed);
    }

    private void updateCenterOfMassMetrics() {
        float previousComX = currentComX;
        float previousComY = currentComY;
        float previousComZ = currentComZ;
        calculateCenterOfMass(latest, work);
        currentComX = work[0];
        currentComY = work[1];
        currentComZ = work[2];
        float comStepX = currentComX - previousComX;
        float comStepY = currentComY - previousComY;
        float comStepZ = currentComZ - previousComZ;
        comPathLength += length(comStepX, comStepY, comStepZ);
        currentComVelocityX = comStepX / currentDeltaSeconds;
        currentComVelocityY = comStepY / currentDeltaSeconds;
        currentComVelocityZ = comStepZ / currentDeltaSeconds;
        maxComSpeed = Math.max(maxComSpeed,
                length(currentComVelocityX, currentComVelocityY, currentComVelocityZ));
        currentForwardVelocity = currentComVelocityX * movementDirectionX
                + currentComVelocityZ * movementDirectionZ;
        currentLateralVelocity = currentComVelocityX * -movementDirectionZ
                + currentComVelocityZ * movementDirectionX;
        maxForwardVelocity = Math.max(maxForwardVelocity, currentForwardVelocity);
        maxBackwardVelocity = Math.max(maxBackwardVelocity, -currentForwardVelocity);
        maxLateralVelocity = Math.max(maxLateralVelocity, Math.abs(currentLateralVelocity));
        maxUpwardVelocity = Math.max(maxUpwardVelocity, currentComVelocityY);
        maxDownwardVelocity = Math.max(maxDownwardVelocity, -currentComVelocityY);

        float weightedSquaredDifference = 0.0f;
        for (int bodyPart = 0; bodyPart < BODY_COUNT; bodyPart++) {
            int velocityOffset = bodyPart * 3;
            float differenceX = linearVelocity[velocityOffset] - currentComVelocityX;
            float differenceY = linearVelocity[velocityOffset + 1] - currentComVelocityY;
            float differenceZ = linearVelocity[velocityOffset + 2] - currentComVelocityZ;
            weightedSquaredDifference += bodyMasses[bodyPart]
                    * (differenceX * differenceX + differenceY * differenceY + differenceZ * differenceZ);
        }
        currentVelocityCoherenceRms = (float) Math.sqrt(weightedSquaredDifference / totalMass);
        maxVelocityCoherenceRms = Math.max(maxVelocityCoherenceRms, currentVelocityCoherenceRms);
    }

    private void updateJointMetrics() {
        for (int joint = 0; joint < JOINT_COUNT; joint++) {
            int parent = JOINT_PARENTS[joint];
            int child = JOINT_CHILDREN[joint];
            float distance = bodyDistance(latest, parent, child);
            float distanceDelta = distance - baselineJointDistance[joint];
            currentJointDistance[joint] = distance;
            currentJointDistanceDelta[joint] = distanceDelta;
            maxJointStretch[joint] = Math.max(maxJointStretch[joint], distanceDelta);
            maxJointCompression[joint] = Math.max(maxJointCompression[joint], -distanceDelta);
            relativeQuaternion(latest, parent, child, work);
            int baselineOffset = joint * 4;
            float angularDeviation = quaternionAngleDifference(
                    work[0], work[1], work[2], work[3],
                    baselineJointRotation[baselineOffset], baselineJointRotation[baselineOffset + 1],
                    baselineJointRotation[baselineOffset + 2], baselineJointRotation[baselineOffset + 3]);
            currentJointAngularDeviation[joint] = angularDeviation;
            if (angularDeviation > maxJointAngularDeviation[joint]) {
                maxJointAngularDeviation[joint] = angularDeviation;
                maxJointAngularDeviationFrame[joint] = validFrameCount;
                maxJointAngularDeviationSeconds[joint] = elapsedSeconds;
            }
        }
    }

    private void appendBodyFrame(StringBuilder builder) {
        for (int bodyPart = 0; bodyPart < BODY_COUNT; bodyPart++) {
            if (bodyPart > 0) builder.append(';');
            int bodyOffset = bodyPart * BODY_STRIDE;
            int velocityOffset = bodyPart * 3;
            builder.append(BODY_NAMES[bodyPart]).append("{p=");
            appendVector(builder, latest[bodyOffset] - latest[0],
                    latest[bodyOffset + 1] - latest[1], latest[bodyOffset + 2] - latest[2]);
            builder.append(",q=");
            appendQuaternion(builder, latest[bodyOffset + 3], latest[bodyOffset + 4],
                    latest[bodyOffset + 5], latest[bodyOffset + 6]);
            builder.append(",linear=");
            appendVector(builder, linearVelocity[velocityOffset], linearVelocity[velocityOffset + 1],
                    linearVelocity[velocityOffset + 2]);
            builder.append(",angular=");
            appendVector(builder, angularVelocity[velocityOffset], angularVelocity[velocityOffset + 1],
                    angularVelocity[velocityOffset + 2]);
            builder.append(",relativeLinear=").append(relativeLinearSpeed[bodyPart])
                    .append(",relativeAngular=").append(relativeAngularSpeed[bodyPart])
                    .append(",opening=").append(openingDisplacement(bodyPart)).append('}');
        }
    }

    private float openingDisplacement(int bodyPart) {
        int bodyOffset = bodyPart * BODY_STRIDE;
        return length(
                (latest[bodyOffset] - latest[0]) - (baseline[bodyOffset] - baseline[0]),
                (latest[bodyOffset + 1] - latest[1]) - (baseline[bodyOffset + 1] - baseline[1]),
                (latest[bodyOffset + 2] - latest[2]) - (baseline[bodyOffset + 2] - baseline[2]));
    }

    private static boolean hasValidValues(float[] values) {
        for (int bodyPart = 0; bodyPart < BODY_COUNT; bodyPart++) {
            int bodyOffset = bodyPart * BODY_STRIDE;
            for (int component = 0; component < BODY_STRIDE; component++) {
                if (!isFinite(values[bodyOffset + component])) return false;
            }
            float quaternionNormSquared = values[bodyOffset + 3] * values[bodyOffset + 3]
                    + values[bodyOffset + 4] * values[bodyOffset + 4]
                    + values[bodyOffset + 5] * values[bodyOffset + 5]
                    + values[bodyOffset + 6] * values[bodyOffset + 6];
            if (quaternionNormSquared < 0.1f || quaternionNormSquared > 4.0f) return false;
        }
        return true;
    }

    private static float sanitizeDeltaSeconds(float simulationDeltaSeconds, float wallDeltaSeconds) {
        float selected = isFinite(simulationDeltaSeconds) && simulationDeltaSeconds > 0.0001f
                ? simulationDeltaSeconds : wallDeltaSeconds;
        if (!isFinite(selected) || selected <= 0.0001f) selected = 1.0f / 60.0f;
        return Math.max(1.0f / 1000.0f, Math.min(selected, 0.1f));
    }

    private void calculateCenterOfMass(float[] values, float[] output) {
        float centerX = 0.0f;
        float centerY = 0.0f;
        float centerZ = 0.0f;
        for (int bodyPart = 0; bodyPart < BODY_COUNT; bodyPart++) {
            int bodyOffset = bodyPart * BODY_STRIDE;
            float weight = bodyMasses[bodyPart] / totalMass;
            centerX += values[bodyOffset] * weight;
            centerY += values[bodyOffset + 1] * weight;
            centerZ += values[bodyOffset + 2] * weight;
        }
        output[0] = centerX;
        output[1] = centerY;
        output[2] = centerZ;
    }

    private static float bodyDistance(float[] values, int firstBody, int secondBody) {
        int firstOffset = firstBody * BODY_STRIDE;
        int secondOffset = secondBody * BODY_STRIDE;
        return distance(values[firstOffset], values[firstOffset + 1], values[firstOffset + 2],
                values[secondOffset], values[secondOffset + 1], values[secondOffset + 2]);
    }

    private static float bodyDistance(float[] current, float[] prior, int bodyPart) {
        int bodyOffset = bodyPart * BODY_STRIDE;
        return distance(current[bodyOffset], current[bodyOffset + 1], current[bodyOffset + 2],
                prior[bodyOffset], prior[bodyOffset + 1], prior[bodyOffset + 2]);
    }

    private static void angularVelocity(float[] current, float[] prior, int bodyPart,
            float deltaSeconds, float[] output, int outputOffset) {
        int bodyOffset = bodyPart * BODY_STRIDE + 3;
        float currentX = current[bodyOffset];
        float currentY = current[bodyOffset + 1];
        float currentZ = current[bodyOffset + 2];
        float currentW = current[bodyOffset + 3];
        float priorX = prior[bodyOffset];
        float priorY = prior[bodyOffset + 1];
        float priorZ = prior[bodyOffset + 2];
        float priorW = prior[bodyOffset + 3];
        float currentNorm = length(currentX, currentY, currentZ, currentW);
        float priorNorm = length(priorX, priorY, priorZ, priorW);
        currentX /= currentNorm;
        currentY /= currentNorm;
        currentZ /= currentNorm;
        currentW /= currentNorm;
        priorX /= priorNorm;
        priorY /= priorNorm;
        priorZ /= priorNorm;
        priorW /= priorNorm;

        float deltaX = -currentW * priorX + currentX * priorW - currentY * priorZ + currentZ * priorY;
        float deltaY = -currentW * priorY + currentX * priorZ + currentY * priorW - currentZ * priorX;
        float deltaZ = -currentW * priorZ - currentX * priorY + currentY * priorX + currentZ * priorW;
        float deltaW = currentW * priorW + currentX * priorX + currentY * priorY + currentZ * priorZ;
        float deltaNorm = length(deltaX, deltaY, deltaZ, deltaW);
        deltaX /= deltaNorm;
        deltaY /= deltaNorm;
        deltaZ /= deltaNorm;
        deltaW /= deltaNorm;
        if (deltaW < 0.0f) {
            deltaX = -deltaX;
            deltaY = -deltaY;
            deltaZ = -deltaZ;
            deltaW = -deltaW;
        }
        float axisLength = length(deltaX, deltaY, deltaZ);
        if (axisLength < 0.000001f) {
            output[outputOffset] = 0.0f;
            output[outputOffset + 1] = 0.0f;
            output[outputOffset + 2] = 0.0f;
            return;
        }
        float angle = 2.0f * (float) Math.atan2(axisLength, clamp(deltaW, -1.0f, 1.0f));
        float multiplier = angle / (axisLength * deltaSeconds);
        output[outputOffset] = deltaX * multiplier;
        output[outputOffset + 1] = deltaY * multiplier;
        output[outputOffset + 2] = deltaZ * multiplier;
    }

    private static void relativeQuaternion(float[] values, int parentBody, int childBody,
            float[] output) {
        int parentOffset = parentBody * BODY_STRIDE + 3;
        int childOffset = childBody * BODY_STRIDE + 3;
        float parentX = values[parentOffset];
        float parentY = values[parentOffset + 1];
        float parentZ = values[parentOffset + 2];
        float parentW = values[parentOffset + 3];
        float childX = values[childOffset];
        float childY = values[childOffset + 1];
        float childZ = values[childOffset + 2];
        float childW = values[childOffset + 3];
        float parentNorm = length(parentX, parentY, parentZ, parentW);
        float childNorm = length(childX, childY, childZ, childW);
        parentX /= parentNorm;
        parentY /= parentNorm;
        parentZ /= parentNorm;
        parentW /= parentNorm;
        childX /= childNorm;
        childY /= childNorm;
        childZ /= childNorm;
        childW /= childNorm;
        output[0] = parentW * childX - parentX * childW - parentY * childZ + parentZ * childY;
        output[1] = parentW * childY + parentX * childZ - parentY * childW - parentZ * childX;
        output[2] = parentW * childZ - parentX * childY + parentY * childX - parentZ * childW;
        output[3] = parentW * childW + parentX * childX + parentY * childY + parentZ * childZ;
        normalizeQuaternion(output);
    }

    private static float quaternionAngleDifference(float firstX, float firstY, float firstZ,
            float firstW, float secondX, float secondY, float secondZ, float secondW) {
        float firstNorm = length(firstX, firstY, firstZ, firstW);
        float secondNorm = length(secondX, secondY, secondZ, secondW);
        float dot = (firstX * secondX + firstY * secondY + firstZ * secondZ + firstW * secondW)
                / (firstNorm * secondNorm);
        return 2.0f * (float) Math.acos(clamp(Math.abs(dot), 0.0f, 1.0f));
    }

    private static void normalizeQuaternion(float[] quaternion) {
        float norm = length(quaternion[0], quaternion[1], quaternion[2], quaternion[3]);
        quaternion[0] /= norm;
        quaternion[1] /= norm;
        quaternion[2] /= norm;
        quaternion[3] /= norm;
    }

    private static void appendVector(StringBuilder builder, float valueX, float valueY, float valueZ) {
        builder.append(valueX).append(',').append(valueY).append(',').append(valueZ);
    }

    private static void appendQuaternion(StringBuilder builder, float valueX, float valueY,
            float valueZ, float valueW) {
        builder.append(valueX).append(',').append(valueY).append(',').append(valueZ)
                .append(',').append(valueW);
    }

    private static float distance(float firstX, float firstY, float firstZ,
            float secondX, float secondY, float secondZ) {
        return length(firstX - secondX, firstY - secondY, firstZ - secondZ);
    }

    private static float length(float valueX, float valueY) {
        return (float) Math.sqrt(valueX * valueX + valueY * valueY);
    }

    private static float length(float valueX, float valueY, float valueZ) {
        return (float) Math.sqrt(valueX * valueX + valueY * valueY + valueZ * valueZ);
    }

    private static float length(float valueX, float valueY, float valueZ, float valueW) {
        return (float) Math.sqrt(valueX * valueX + valueY * valueY + valueZ * valueZ + valueW * valueW);
    }

    private static float clamp(float value, float minimum, float maximum) {
        return Math.max(minimum, Math.min(value, maximum));
    }

    private static boolean isFinite(float value) {
        return !Float.isNaN(value) && !Float.isInfinite(value);
    }

    private static float sum(float[] values, int start, int end) {
        float total = 0.0f;
        for (int index = start; index < end; index++) total += values[index];
        return total;
    }

    private static int parentBodyPart(int bodyPart) {
        for (int joint = 0; joint < JOINT_COUNT; joint++) {
            if (JOINT_CHILDREN[joint] == bodyPart) return JOINT_PARENTS[joint];
        }
        return -1;
    }
}
