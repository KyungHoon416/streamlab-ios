export const MAX_VIDEO_BYTES = 500_000_000;

export async function validateMP4(file) {
  if (!file || !/\.mp4$/i.test(file.name))
    throw Error("MP4 파일을 선택하세요.");
  if (file.size < 12 || file.size > MAX_VIDEO_BYTES)
    throw Error("12바이트 이상, 500MB 이하의 MP4 파일만 업로드할 수 있습니다.");
  if (file.type && file.type !== "video/mp4")
    throw Error("MP4 영상 형식이 아닙니다.");
  const bytes = new Uint8Array(await file.slice(0, 12).arrayBuffer());
  if (String.fromCharCode(...bytes.slice(4, 8)) !== "ftyp")
    throw Error(
      "MP4 파일 헤더를 확인하지 못했습니다. MP4로 내보낸 파일을 선택하세요.",
    );
}

// Cancelling invalidates URL lookup as well as the active upload. Late callbacks
// cannot modify the form after logout, cancellation or a replacement operation.
export class VideoUpload {
  constructor({ start, getURL, progress, completed, failed, settled }) {
    Object.assign(this, {
      start,
      getURL,
      progress,
      completed,
      failed,
      settled,
    });
    this.generation = 0;
    this.task = null;
  }
  cancel() {
    this.generation++;
    this.task?.cancel();
    this.task = null;
  }
  async run(file, path, metadata) {
    this.cancel();
    const generation = this.generation;
    const current = () => generation === this.generation;
    try {
      await validateMP4(file);
      if (!current()) return;
      const task = this.start(path, file, metadata);
      this.task = task;
      await new Promise((resolve, reject) =>
        task.on(
          "state_changed",
          (snapshot) => {
            if (current())
              this.progress(
                snapshot.totalBytes
                  ? snapshot.bytesTransferred / snapshot.totalBytes
                  : 0,
              );
          },
          reject,
          resolve,
        ),
      );
      if (!current()) return;
      const url = await this.getURL(task.snapshot.ref);
      if (current()) await this.completed(url);
    } catch (error) {
      if (current()) this.failed(error);
    } finally {
      if (current()) {
        this.task = null;
        this.settled();
      }
    }
  }
}
