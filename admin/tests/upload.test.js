import { test } from "node:test";
import assert from "node:assert/strict";
import { validateMP4, VideoUpload, MAX_VIDEO_BYTES } from "../src/upload.js";
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
