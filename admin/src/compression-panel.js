import { needsCompressionChoice, makeCompressionPlan, compressionNotes, formatCompressionRecipe } from "./compression.js";
import { MAX_VIDEO_BYTES, formatVideoSize, validateMP4 } from "./upload.js";
import { readVideoMetadata } from "./video-metadata.js";

export class CompressionPanel {
  constructor(root, changed, readMetadata = readVideoMetadata) {
    this.root = root;
    this.changed = changed;
    this.readMetadata = readMetadata;
    this.generation = 0;
    this.sampleGeneration = 0;
    this.busy = false;
    this.$ = (id) => root.querySelector(`#${id}`);
    for (const input of root.querySelectorAll('input[name="compression-mode"]'))
      input.addEventListener("change", () => { this.clearSample(); this.render(); });
    this.$("compression-fps").addEventListener("change", () => { this.clearSample(); this.render(); });
    this.$("compression-minutes").addEventListener("input", () => this.render());
    this.$("compression-sample").addEventListener("change", event => this.selectSample(event.target.files?.[0]));
    this.$("compression-recipe").addEventListener("click", () => this.downloadRecipe());
  }
  get mode() { return this.root.querySelector('input[name="compression-mode"]:checked')?.value ?? "ratio40"; }
  get durationSeconds() {
    return this.metadata?.durationSeconds ?? Number(this.$("compression-minutes").value) * 60;
  }
  allowsUpload() {
    return !this.file || (this.file.size <= MAX_VIDEO_BYTES &&
      (!needsCompressionChoice(this.file.size) || this.mode === "original"));
  }
  setBusy(value) { this.busy = value; this.render(); }
  clearSample() {
    ++this.sampleGeneration;
    this.sampleAbort?.abort();
    this.sample = null;
    this.$("compression-sample").value = "";
    this.$("compression-sample-status").textContent = "";
  }
  async select(file) {
    const generation = ++this.generation;
    this.sourceAbort?.abort();
    this.clearSample();
    this.file = file;
    this.metadata = null;
    this.$("compression-minutes").value = "";
    this.$("compression-fps").value = "30";
    this.root.querySelector('input[value="ratio40"]').checked = true;
    this.root.hidden = !file || !needsCompressionChoice(file.size);
    this.$("compression-source").textContent = "영상 길이와 해상도를 읽고 있어요…";
    this.render();
    if (this.root.hidden) return;
    this.sourceAbort = new AbortController();
    try {
      const metadata = await this.readMetadata(file, { signal: this.sourceAbort.signal });
      if (generation !== this.generation) return;
      this.metadata = metadata;
      this.$("compression-source").textContent = `${formatVideoSize(file.size)} · ${metadata.width}×${metadata.height} · ${(metadata.durationSeconds / 60).toFixed(1)}분`;
    } catch (error) {
      if (generation !== this.generation || error.name === "AbortError") return;
      this.$("compression-source").textContent = `${formatVideoSize(file.size)} · ${error.message} 아래에 실제 길이를 입력해 주세요.`;
    }
    this.render();
  }
  async selectSample(file) {
    this.clearSample();
    if (!file || this.busy || this.mode !== "quality") return;
    const generation = this.generation, sampleGeneration = this.sampleGeneration;
    const current = () => generation === this.generation && sampleGeneration === this.sampleGeneration;
    this.sampleAbort = new AbortController();
    this.$("compression-sample-status").textContent = "샘플 정보를 읽고 있어요…";
    try {
      await validateMP4(file, { forUpload: false });
      if (!current()) return;
      const metadata = await this.readMetadata(file, { signal: this.sampleAbort.signal });
      if (!current()) return;
      if (metadata.width > 1920 || metadata.height > 1080)
        throw Error("최대 1080p로 압축한 샘플을 선택하세요.");
      this.sample = { bytes: file.size, durationSeconds: metadata.durationSeconds };
      makeCompressionPlan({ durationSeconds: this.durationSeconds, mode: this.mode, sample: this.sample });
      this.$("compression-sample-status").textContent = `${file.name} · ${formatVideoSize(file.size)} · ${metadata.durationSeconds.toFixed(1)}초`;
    } catch (error) {
      if (!current() || error.name === "AbortError") return;
      this.sample = null;
      this.$("compression-sample-status").textContent = error.message;
    }
    this.render();
  }
  render() {
    const active = !!this.file && needsCompressionChoice(this.file.size);
    const original = this.mode === "original";
    const quality = this.mode === "quality";
    this.$("compression-settings").hidden = original;
    this.$("compression-manual-duration").hidden = !!this.metadata;
    this.$("compression-minutes").disabled = this.busy || original || !!this.metadata || !active;
    this.$("compression-quality-sample").hidden = !quality;
    this.$("compression-sample").disabled = this.busy || !quality || !active;
    this.$("compression-fps").disabled = this.busy || original || !active;
    for (const input of this.root.querySelectorAll('input[name="compression-mode"]')) input.disabled = this.busy || !active;
    const result = this.$("compression-estimate");
    result.replaceChildren();
    this.plan = null;
    if (active) {
      const add = (text, className = "") => {
        const p = document.createElement("p"); p.textContent = text; p.className = className; result.append(p);
      };
      if (original) {
        add(`업로드 용량 ${formatVideoSize(this.file.size)} · 압축 없음`, "estimate-value");
        if (this.file.size > MAX_VIDEO_BYTES) add("원본이 업로드 한도 5GB를 넘습니다. Mac에서 압축한 파일을 다시 선택하세요.");
      } else {
        try {
          this.plan = makeCompressionPlan({ durationSeconds: this.durationSeconds, mode: this.mode,
            sourceBytes: this.file.size, frameRate: this.$("compression-fps").value, sample: this.sample });
          if (this.plan.estimatedBytes !== null) {
            const ratio = (1 - this.plan.estimatedBytes / this.file.size) * 100;
            add(`예상 약 ${formatVideoSize(this.plan.estimatedBytes)}${ratio >= 0 ? ` · 원본 대비 약 ${ratio.toFixed(1)}% 감소` : " · 원본보다 커질 수 있음"}`, "estimate-value");
            add(quality ? "같은 원본·설정의 샘플 크기를 전체 길이로 환산한 예상입니다. 전체 영상의 보장 용량이 아닙니다."
              : `${this.mode === "ratio40" ? "원본의 40% 크기 목표" : "1GB 이하 목표"} · 영상 ${this.plan.videoKbps}kbps + 오디오 96kbps로 계산한 값입니다. 실제 용량은 압축 후 확인합니다.`);
            if (this.plan.estimatedBytes > MAX_VIDEO_BYTES)
              add("예상 크기가 업로드 한도 5GB를 넘습니다. 용량 목표를 낮추거나 압축 설정을 조정하세요.");
          } else add("예상 용량은 샘플 확인 후 표시됩니다.", "estimate-value");
          for (const note of compressionNotes(this.plan)) add(note);
        } catch (error) { add(error.message); }
      }
    }
    this.$("compression-recipe").disabled = this.busy || !this.plan || !active;
    this.$("compression-upload-note").textContent = original
      ? "선택한 원본 파일을 그대로 전송합니다."
      : "Mac에서 압축한 MP4를 위 영역에 다시 넣으세요. 완성본도 2GB 이상이면 ‘원본 그대로 업로드’를 선택해 해당 파일을 전송하세요.";
    this.changed();
  }
  downloadRecipe() {
    if (!this.plan || !this.file || this.busy) return;
    const url = URL.createObjectURL(new Blob([formatCompressionRecipe(this.plan, this.file.name)], { type: "text/plain;charset=utf-8" }));
    const link = document.createElement("a");
    link.href = url; link.download = "streamlab-compression-plan.txt";
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}
