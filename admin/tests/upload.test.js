import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { validateMP4, VideoUpload, MAX_VIDEO_BYTES, formatVideoSize, uploadProgressText } from "../src/upload.js";
const file = () =>
  new File(
    [new Uint8Array([0, 0, 0, 12, 102, 116, 121, 112, 105, 115, 111, 109])],
    "sample.mp4",
    { type: "video/mp4" },
  );
test("MP4 validation rejects empty, oversized, wrong extension and disguised data", async () => {
  await validateMP4(file());
  for (const f of [
    null,
    new File([""], "a.mp4"),
    new File(["not an mp4 file"], "a.mp4"),
    new File([file()], "a.txt"),
    { name: "huge.mp4", size: MAX_VIDEO_BYTES + 1 },
  ])
    await assert.rejects(validateMP4(f));
});
test("multi-GB files read only their header; size limit is inclusive and matches Storage rules", async () => {
  for (const size of [3_000_000_000, 4_000_000_000, 4 * 1024 ** 3, MAX_VIDEO_BYTES]) {
    const reads = [];
    await validateMP4({
      name: "long-4k.mp4", type: "video/mp4", size,
      slice: (start, end) => { reads.push([start, end]); return file().slice(start, end); },
      arrayBuffer: () => { throw Error("must not read the entire video"); },
    });
    assert.deepEqual(reads, [[0, 12]]);
  }
  for (const size of [MAX_VIDEO_BYTES + 1, Infinity, NaN]) {
    await assert.rejects(validateMP4({ name: "too-large.mp4", size }), /5 GB/);
  }
  const rules = await readFile(new URL("../../storage.rules", import.meta.url), "utf8");
  assert.equal(Number(rules.match(/request\.resource\.size <= (\d+)/)[1]), MAX_VIDEO_BYTES);
});
test("multi-GB progress remains readable without 32-bit truncation", () => {
  assert.equal(formatVideoSize(4_000_000_000), "4 GB");
  assert.equal(formatVideoSize(250_000_000), "250 MB");
  assert.equal(uploadProgressText({ bytesTransferred: 2_500_000_000, totalBytes: 5_000_000_000 }), "업로드 중 50% · 2.5 GB / 5 GB");
  assert.equal(uploadProgressText({ bytesTransferred: 5_000_000_000, totalBytes: 5_000_000_000 }), "영상 URL을 확인하고 있어요…");
});
function setup(getURL = async () => "https://example.com/a.mp4") {
  const seen = [];
  let callbacks;
  const task = {
    snapshot: { ref: {} },
    cancel() {
      seen.push("cancel");
    },
    on(_, progress, fail, complete) {
      callbacks = { progress, fail, complete };
    },
  };
  const uploader = new VideoUpload({
    start: () => task,
    getURL,
    progress: (x) => seen.push(x),
    completed: (x) => seen.push(x),
    failed: (x) => seen.push(x.code),
    settled: () => seen.push("settled"),
  });
  return { uploader, seen, callbacks: () => callbacks };
}
const tick = () => new Promise((resolve) => setImmediate(resolve));
test('cancel during header validation prevents any network upload',async()=>{
  let starts=0;
  const s=setup(); s.uploader.start=()=>{starts++; throw Error('must not start');};
  const run=s.uploader.run(file(),'p',{}); s.uploader.cancel(); await run;
  assert.equal(starts,0); assert.deepEqual(s.seen,[]);
});
test("progress, URL completion and settlement arrive in order", async () => {
  const s = setup(),
    run = s.uploader.run(file(), "p", {});
  await tick();
  s.callbacks().progress({ bytesTransferred: 5, totalBytes: 10 });
  s.callbacks().complete();
  await run;
  assert.deepEqual(s.seen, [0.5, "https://example.com/a.mp4", "settled"]);
});
test("cancel/logout suppresses late upload and URL callbacks", async () => {
  let finish;
  const s = setup(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  const run = s.uploader.run(file(), "p", {});
  await tick();
  s.callbacks().complete();
  await tick();
  s.uploader.cancel();
  finish("https://example.com/stale.mp4");
  await run;
  assert.deepEqual(s.seen, ["cancel"]);
});
test("failed transfer leaves URL unchanged and permits retry", async () => {
  const s = setup(),
    run = s.uploader.run(file(), "p", {});
  await tick();
  s.callbacks().fail({ code: "storage/unauthorized" });
  await run;
  assert.deepEqual(s.seen, ["storage/unauthorized", "settled"]);
});
