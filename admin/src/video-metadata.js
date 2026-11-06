// Native blob playback reads metadata without loading a multi-GB file into JS.
// The browser does not expose a reliable source FPS here; never infer it from a filename.
export function readVideoMetadata(file, { signal, timeoutMs = 15000, documentObject = document, urls = URL } = {}) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) { reject(new DOMException("Cancelled", "AbortError")); return; }
    const video = documentObject.createElement("video");
    const url = urls.createObjectURL(file);
    let timer, done = false;
    const finish = (error, value) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
      video.onloadedmetadata = video.onerror = null;
      video.removeAttribute("src");
      video.load();
      urls.revokeObjectURL(url);
      if (error) reject(error); else resolve(value);
    };
    const abort = () => finish(new DOMException("Cancelled", "AbortError"));
    video.preload = "metadata";
    video.muted = true;
    video.onloadedmetadata = () => {
      const { duration, videoWidth: width, videoHeight: height } = video;
      if (!Number.isFinite(duration) || duration <= 0 || !width || !height)
        finish(Error("영상 정보를 읽지 못했습니다."));
      else finish(null, { durationSeconds: duration, width, height });
    };
    video.onerror = () => finish(Error("이 브라우저에서 영상 정보를 읽지 못했습니다."));
    signal?.addEventListener("abort", abort, { once: true });
    timer = setTimeout(() => finish(Error("영상 정보 읽기 시간이 초과됐습니다.")), timeoutMs);
    video.src = url;
  });
}
