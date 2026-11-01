import { validateMP4 } from "./upload.js";

// Picker and drop share validation. Old reads cannot restore a file after reset.
export class VideoSelection {
  constructor(changed) {
    this.changed = changed;
    this.generation = 0;
    this.file = null;
  }
  clear() {
    this.generation++;
    this.file = null;
    this.changed(null, "");
  }
  async choose(files) {
    this.clear();
    const generation = this.generation;
    try {
      if (files.length !== 1) throw Error("MP4 파일을 한 개씩 선택해 주세요.");
      await validateMP4(files[0]);
      if (generation !== this.generation) return;
      this.file = files[0];
      this.changed(this.file, "");
    } catch (error) {
      if (generation === this.generation) this.changed(null, error.message);
    }
  }
}
