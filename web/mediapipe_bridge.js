(function () {
  let camera = null;
  let activeMode = null;
  let container = null;
  let videoEl = null;
  let canvasEl = null;
  let canvasCtx = null;
  let detector = null;

  function findElementByIdDeep(id, root) {
    const currentRoot = root || document;
    if (!currentRoot) {
      return null;
    }

    if (typeof currentRoot.getElementById === 'function') {
      const direct = currentRoot.getElementById(id);
      if (direct) {
        return direct;
      }
    }

    const all = currentRoot.querySelectorAll ? currentRoot.querySelectorAll('*') : [];
    for (let i = 0; i < all.length; i++) {
      const el = all[i];
      if (el.id === id) {
        return el;
      }
      if (el.shadowRoot) {
        const fromShadow = findElementByIdDeep(id, el.shadowRoot);
        if (fromShadow) {
          return fromShadow;
        }
      }
    }

    return null;
  }

  async function waitForContainer(containerId) {
    for (let i = 0; i < 120; i++) {
      const el = findElementByIdDeep(containerId, document);
      if (el) {
        return el;
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    throw new Error('MediaPipe container not found: ' + containerId);
  }

  const latest = {
    face: {
      faceDetected: false,
      emotion: 'Unknown',
      advice: 'Look at the camera for analysis.',
    },
    hand: {
      leftHand: false,
      rightHand: false,
      missing: ['left hand', 'right hand'],
      summary: 'No hands detected',
    },
    shoulder: {
      leftShoulder: false,
      rightShoulder: false,
      movement: false,
      feedback: 'Keep upper body in frame.',
    },
    live: {
      faceDetected: false,
      emotion: 'Unknown',
      shoulderActive: false,
      handActive: false,
      elbowAngle: 180,
      kneeAngle: 180,
      armsUp: false,
      legsOpen: false,
      bodyLineScore: 0.5,
    },
  };

  function clearContainer() {
    if (!container) {
      return;
    }
    container.innerHTML = '';
  }

  function stop() {
    try {
      if (camera && camera.video && camera.video.srcObject) {
        const tracks = camera.video.srcObject.getTracks();
        tracks.forEach((t) => t.stop());
      }
      if (camera && typeof camera.stop === 'function') {
        camera.stop();
      }
    } catch (e) {
      console.warn('camera stop error', e);
    }
    camera = null;
    detector = null;
    activeMode = null;
    clearContainer();
    container = null;
    videoEl = null;
    canvasEl = null;
    canvasCtx = null;
  }

  async function setupDom(containerId) {
    container = await waitForContainer(containerId);

    container.style.position = 'relative';
    container.style.width = '100%';
    container.style.height = '100%';
    container.style.background = 'black';
    container.innerHTML = '';

    videoEl = document.createElement('video');
    videoEl.setAttribute('playsinline', 'true');
    videoEl.autoplay = true;
    videoEl.muted = true;
    videoEl.style.position = 'absolute';
    videoEl.style.width = '100%';
    videoEl.style.height = '100%';
    videoEl.style.objectFit = 'cover';
    videoEl.style.transform = 'scaleX(-1)';

    canvasEl = document.createElement('canvas');
    canvasEl.style.position = 'absolute';
    canvasEl.style.left = '0';
    canvasEl.style.top = '0';
    canvasEl.style.width = '100%';
    canvasEl.style.height = '100%';
    canvasEl.style.pointerEvents = 'none';

    container.appendChild(videoEl);
    container.appendChild(canvasEl);
    canvasCtx = canvasEl.getContext('2d');
  }

  function resizeCanvas() {
    if (!videoEl || !canvasEl) {
      return;
    }
    canvasEl.width = videoEl.videoWidth || 1280;
    canvasEl.height = videoEl.videoHeight || 720;
  }

  function inferEmotionFromFaceMesh(multiFaceLandmarks) {
    if (!multiFaceLandmarks || multiFaceLandmarks.length === 0) {
      latest.face.faceDetected = false;
      latest.face.emotion = 'No face detected';
      latest.face.advice = 'Keep full face in frame and improve lighting.';
      return;
    }

    const lm = multiFaceLandmarks[0];
    const leftMouth = lm[61];
    const rightMouth = lm[291];
    const topLip = lm[13];
    const bottomLip = lm[14];

    const mouthWidth = Math.abs((rightMouth.x - leftMouth.x) || 0.001);
    const mouthOpen = Math.abs((bottomLip.y - topLip.y) || 0.001);
    const mouthOpenRatio = mouthOpen / Math.max(mouthWidth, 0.001);
    const smileRatio = mouthWidth / Math.max(mouthOpen, 0.001);

    latest.face.faceDetected = true;
    // Priority rule: big mouth opening should be classified as Astonished.
    if (mouthOpenRatio >= 0.23) {
      latest.face.emotion = 'Astonished';
      latest.face.advice = 'Surprised expression detected. Slow breathing can help you reset focus.';
    } else if (smileRatio > 8.2) {
      latest.face.emotion = 'Happy';
      latest.face.advice = 'Great mood. Keep this positive energy.';
    } else if (smileRatio < 6.2) {
      latest.face.emotion = 'Sad';
      latest.face.advice = 'Try laughter breathing and light movement to lift mood.';
    } else {
      latest.face.emotion = 'Neutral';
      latest.face.advice = 'Try a short smiling drill and mobility warm-up.';
    }
  }

  function updateHands(multiHandLandmarks, multiHandedness) {
    let left = false;
    let right = false;
    const missing = [];

    if (!multiHandLandmarks || multiHandLandmarks.length === 0) {
      latest.hand.leftHand = false;
      latest.hand.rightHand = false;
      latest.hand.missing = ['left hand', 'right hand'];
      latest.hand.summary = 'No hands detected';
      return;
    }

    for (let i = 0; i < multiHandLandmarks.length; i++) {
      const handedness = multiHandedness && multiHandedness[i] && multiHandedness[i].label;
      const lm = multiHandLandmarks[i];
      if (handedness === 'Left') {
        left = true;
      }
      if (handedness === 'Right') {
        right = true;
      }

      const tipIdx = [4, 8, 12, 16, 20];
      const pipIdx = [3, 6, 10, 14, 18];
      const extended = tipIdx.map((t, j) => lm[t].y < lm[pipIdx[j]].y);
      if (handedness === 'Left') {
        ['thumb', 'index', 'middle', 'ring', 'pinky'].forEach((name, j) => {
          if (!extended[j]) missing.push('left ' + name);
        });
      }
      if (handedness === 'Right') {
        ['thumb', 'index', 'middle', 'ring', 'pinky'].forEach((name, j) => {
          if (!extended[j]) missing.push('right ' + name);
        });
      }
    }

    if (!left) missing.push('left hand');
    if (!right) missing.push('right hand');

    latest.hand.leftHand = left;
    latest.hand.rightHand = right;
    latest.hand.missing = missing;
    latest.hand.summary = missing.length === 0 ? 'All fingers visible and active.' : 'Missing: ' + missing.join(', ');
  }

  let prevLeftShoulderY = null;
  let prevRightShoulderY = null;
  function updateShoulders(poseLandmarks) {
    if (!poseLandmarks || poseLandmarks.length === 0) {
      latest.shoulder.leftShoulder = false;
      latest.shoulder.rightShoulder = false;
      latest.shoulder.movement = false;
      latest.shoulder.feedback = 'Keep upper body in frame.';
      return;
    }

    const left = poseLandmarks[11];
    const right = poseLandmarks[12];
    const leftOk = !!left;
    const rightOk = !!right;

    let movement = false;
    if (left && prevLeftShoulderY !== null && Math.abs(left.y - prevLeftShoulderY) > 0.01) {
      movement = true;
    }
    if (right && prevRightShoulderY !== null && Math.abs(right.y - prevRightShoulderY) > 0.01) {
      movement = true;
    }
    prevLeftShoulderY = left ? left.y : prevLeftShoulderY;
    prevRightShoulderY = right ? right.y : prevRightShoulderY;

    latest.shoulder.leftShoulder = leftOk;
    latest.shoulder.rightShoulder = rightOk;
    latest.shoulder.movement = movement;
    latest.shoulder.feedback = !leftOk || !rightOk
      ? 'Keep both shoulders visible.'
      : (movement ? 'Good shoulder movement detected.' : 'Move shoulders slightly to trigger detection.');

    const leftElbow = poseLandmarks[13];
    const rightElbow = poseLandmarks[14];
    const leftWrist = poseLandmarks[15];
    const rightWrist = poseLandmarks[16];
    const leftHip = poseLandmarks[23];
    const rightHip = poseLandmarks[24];
    const leftKnee = poseLandmarks[25];
    const rightKnee = poseLandmarks[26];
    const leftAnkle = poseLandmarks[27];
    const rightAnkle = poseLandmarks[28];

    const shoulderWidth = (left && right) ? Math.abs(left.x - right.x) : 0;
    const ankleWidth = (leftAnkle && rightAnkle) ? Math.abs(leftAnkle.x - rightAnkle.x) : 0;
    const shoulderY = (left && right) ? ((left.y + right.y) / 2) : null;
    const wristY = (leftWrist && rightWrist) ? ((leftWrist.y + rightWrist.y) / 2) : null;

    const elbowAngle = averageAngles(
      angle(left, leftElbow, leftWrist),
      angle(right, rightElbow, rightWrist),
    );
    const kneeAngle = averageAngles(
      angle(leftHip, leftKnee, leftAnkle),
      angle(rightHip, rightKnee, rightAnkle),
    );
    const bodyLine = angle(left, leftHip, leftAnkle);
    const bodyLineScore = bodyLine ? clamp(1 - (Math.abs(180 - bodyLine) / 70), 0, 1) : 0.5;

    latest.live.shoulderActive = movement;
    latest.live.handActive = !!leftWrist || !!rightWrist;
    latest.live.elbowAngle = elbowAngle ?? 180;
    latest.live.kneeAngle = kneeAngle ?? 180;
    latest.live.armsUp = (shoulderY != null && wristY != null) ? wristY < (shoulderY - 0.05) : false;
    latest.live.legsOpen = shoulderWidth > 0 ? ankleWidth > (shoulderWidth * 1.55) : false;
    latest.live.bodyLineScore = bodyLineScore;
  }

  function clamp(v, min, max) {
    return Math.max(min, Math.min(max, v));
  }

  function averageAngles(a, b) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return (a + b) / 2;
  }

  function angle(a, b, c) {
    if (!a || !b || !c) return null;
    const abx = a.x - b.x;
    const aby = a.y - b.y;
    const cbx = c.x - b.x;
    const cby = c.y - b.y;
    const dot = (abx * cbx) + (aby * cby);
    const mag1 = Math.hypot(abx, aby);
    const mag2 = Math.hypot(cbx, cby);
    if (!mag1 || !mag2) return null;
    const cosine = clamp(dot / (mag1 * mag2), -1, 1);
    return Math.acos(cosine) * (180 / Math.PI);
  }

  async function start(mode, containerId) {
    stop();
    activeMode = mode;
    await setupDom(containerId);

    if (typeof Camera === 'undefined') {
      throw new Error('MediaPipe Camera util not loaded.');
    }

    if (mode === 'face') {
      if (typeof FaceMesh === 'undefined') {
        throw new Error('FaceMesh library not loaded.');
      }
      detector = new FaceMesh({
        locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/${file}`,
      });
      detector.setOptions({
        maxNumFaces: 1,
        refineLandmarks: true,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5,
      });
      detector.onResults((results) => {
        resizeCanvas();
        canvasCtx.save();
        canvasCtx.clearRect(0, 0, canvasEl.width, canvasEl.height);
        if (results.image) {
          canvasCtx.drawImage(results.image, 0, 0, canvasEl.width, canvasEl.height);
        }
        if (results.multiFaceLandmarks) {
          results.multiFaceLandmarks.forEach((lms) => {
            drawConnectors(canvasCtx, lms, FACEMESH_TESSELATION, { color: '#00E5FF', lineWidth: 1 });
          });
        }
        canvasCtx.restore();
        inferEmotionFromFaceMesh(results.multiFaceLandmarks);
      });
    }

    if (mode === 'hand') {
      if (typeof Hands === 'undefined') {
        throw new Error('Hands library not loaded.');
      }
      detector = new Hands({
        locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${file}`,
      });
      detector.setOptions({
        maxNumHands: 2,
        modelComplexity: 1,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5,
      });
      detector.onResults((results) => {
        resizeCanvas();
        canvasCtx.save();
        canvasCtx.clearRect(0, 0, canvasEl.width, canvasEl.height);
        if (results.image) {
          canvasCtx.drawImage(results.image, 0, 0, canvasEl.width, canvasEl.height);
        }
        if (results.multiHandLandmarks) {
          results.multiHandLandmarks.forEach((lms) => {
            drawConnectors(canvasCtx, lms, HAND_CONNECTIONS, { color: '#4ADE80', lineWidth: 3 });
            drawLandmarks(canvasCtx, lms, { color: '#E2E8F0', lineWidth: 2 });
          });
        }
        canvasCtx.restore();
        updateHands(results.multiHandLandmarks, results.multiHandedness);
      });
    }

    if (mode === 'shoulder') {
      if (typeof Pose === 'undefined') {
        throw new Error('Pose library not loaded.');
      }
      detector = new Pose({
        locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`,
      });
      detector.setOptions({
        modelComplexity: 1,
        smoothLandmarks: true,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5,
      });
      detector.onResults((results) => {
        resizeCanvas();
        canvasCtx.save();
        canvasCtx.clearRect(0, 0, canvasEl.width, canvasEl.height);
        if (results.image) {
          canvasCtx.drawImage(results.image, 0, 0, canvasEl.width, canvasEl.height);
        }
        if (results.poseLandmarks) {
          drawConnectors(canvasCtx, results.poseLandmarks, POSE_CONNECTIONS, { color: '#F472B6', lineWidth: 3 });
          drawLandmarks(canvasCtx, results.poseLandmarks, { color: '#F8FAFC', lineWidth: 2 });
        }
        canvasCtx.restore();
        updateShoulders(results.poseLandmarks);
      });
    }

    if (mode === 'live') {
      if (typeof Holistic === 'undefined') {
        throw new Error('Holistic library not loaded.');
      }
      detector = new Holistic({
        locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/holistic/${file}`,
      });
      detector.setOptions({
        modelComplexity: 1,
        smoothLandmarks: true,
        refineFaceLandmarks: true,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5,
      });
      detector.onResults((results) => {
        resizeCanvas();
        canvasCtx.save();
        canvasCtx.clearRect(0, 0, canvasEl.width, canvasEl.height);
        if (results.image) {
          canvasCtx.drawImage(results.image, 0, 0, canvasEl.width, canvasEl.height);
        }
        if (results.poseLandmarks) {
          drawConnectors(canvasCtx, results.poseLandmarks, POSE_CONNECTIONS, { color: '#67E8F9', lineWidth: 3 });
        }
        if (results.leftHandLandmarks) {
          drawConnectors(canvasCtx, results.leftHandLandmarks, HAND_CONNECTIONS, { color: '#86EFAC', lineWidth: 2 });
        }
        if (results.rightHandLandmarks) {
          drawConnectors(canvasCtx, results.rightHandLandmarks, HAND_CONNECTIONS, { color: '#86EFAC', lineWidth: 2 });
        }
        canvasCtx.restore();

        inferEmotionFromFaceMesh(results.faceLandmarks ? [results.faceLandmarks] : []);
        latest.live.faceDetected = latest.face.faceDetected;
        latest.live.emotion = latest.face.emotion;
        updateShoulders(results.poseLandmarks);
      });
    }

    camera = new Camera(videoEl, {
      onFrame: async () => {
        if (detector) {
          await detector.send({ image: videoEl });
        }
      },
      width: 1280,
      height: 720,
    });

    await camera.start();
    return true;
  }

  function getLatest(mode) {
    if (mode === 'face') return latest.face;
    if (mode === 'hand') return latest.hand;
    if (mode === 'shoulder') return latest.shoulder;
    if (mode === 'live') return latest.live;
    return {};
  }

  window.nutriMediaPipe = {
    start,
    stop,
    getLatest,
  };
})();
