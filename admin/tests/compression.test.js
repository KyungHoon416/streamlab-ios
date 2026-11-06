import { test } from "node:test";
import assert from "node:assert/strict";
import { needsCompressionChoice, makeCompressionPlan, compressionNotes, formatCompressionRecipe } from "../src/compression.js";
import { validateMP4 } from "../src/upload.js";
import { VideoSelection } from "../src/selection.js";
import { readVideoMetadata } from "../src/video-metadata.js";

test("2GB selection boundary uses decimal bytes; large input can be analysed but cannot bypass upload limit", async () => {
  assert.equal(needsCompressionChoice(1_999_999_999), false);
  assert.equal(needsCompressionChoice(2_000_000_000), true);
  const slices = [];
  const source = { name: "large.mp4", size: 8_881_545_500, type: "video/mp4", slice(start, end) {
    slices.push([start, end]);
    return new Blob([new Uint8Array([0,0,0,12,102,116,121,112,0,0,0,0])]);
  } };
  const selection = new VideoSelection(() => {}, file => validateMP4(file, { forUpload: false }));
  await selection.choose([source]);
  assert.equal(selection.file, source);
  assert.deepEqual(slices, [[0,12]]);
  await assert.rejects(validateMP4(source), /5 GB/);
  assert.deepEqual(slices, [[0,12]]);
});

test("1GB plans account for actual duration, audio and headroom, including a four-hour film", () => {
  const tokyo = makeCompressionPlan({ durationSeconds: 11926.837, mode: "size" });
  const long = makeCompressionPlan({ durationSeconds: 14400, mode: "size" });
  assert.equal(tokyo.videoKbps, 530);
  assert.equal(long.videoKbps, 420);
  for (const plan of [tokyo, long]) {
    assert.ok(plan.estimatedBytes <= 940_000_000);
    assert.equal(plan.targetBytes, 1_000_000_000);
    assert.equal(plan.audioKbps, 96);
    assert.ok(compressionNotes(plan).some(note => note.includes("디테일 손실")));
  }
});

test("60fps preserves the same size budget instead of pretending to improve detail", () => {
  const base = { durationSeconds: 14400, mode: "size" };
  const thirty = makeCompressionPlan(base);
  const source = makeCompressionPlan({ ...base, frameRate: "source" });
  assert.equal(thirty.videoKbps, source.videoKbps);
  assert.equal(thirty.estimatedBytes, source.estimatedBytes);
  assert.ok(compressionNotes(source).some(note => note.includes("원본이 60fps일 때만")));
});

test("40 percent means remaining size, not a 40 percent reduction; validates source and duration budgets", () => {
  const base = { durationSeconds: 11926.837, mode: "ratio40", sourceBytes: 8_881_545_500 };
  const plan = makeCompressionPlan(base);
  assert.equal(plan.targetBytes, 3_552_618_200);
  assert.equal(plan.targetRatio, 0.4);
  assert.equal(plan.videoKbps, 2230);
  assert.ok(plan.estimatedBytes <= plan.targetBytes * 0.98);
  assert.ok(plan.estimatedBytes > 3_400_000_000);
  assert.ok(compressionNotes(plan).some(note => note.includes("60% 감소")));
  assert.ok(formatCompressionRecipe(plan, "tokyo.mp4").includes("원본의 40% 크기"));
  for (const sourceBytes of [undefined, 0, -1, Infinity, NaN, 1.5])
    assert.throws(() => makeCompressionPlan({ ...base, sourceBytes }));
});

test("quality size is unknown before a sample; sample projection uses measured duration and bytes", () => {
  const base = { durationSeconds: 11926.837, mode: "quality" };
  assert.equal(makeCompressionPlan(base).estimatedBytes, null);
  const plan = makeCompressionPlan({ ...base, sample: { bytes: 23_215_912, durationSeconds: 60.06 } });
  assert.ok(plan.estimatedBytes > 4_600_000_000 && plan.estimatedBytes < 4_620_000_000);
  assert.equal(plan.targetBytes, undefined);
  const recipe = formatCompressionRecipe(plan, "a;$(echo secret).mp4");
  assert.ok(recipe.includes("실행 명령이 아닙니다"));
  assert.ok(recipe.includes("a;$(echo secret).mp4"));
  assert.ok(recipe.includes("CRF 28"));
});

test("invalid metadata and infeasible targets never produce a misleading estimate", () => {
  for (const durationSeconds of [0, -1, Infinity, NaN, undefined])
    assert.throws(() => makeCompressionPlan({ durationSeconds, mode: "size" }));
  assert.throws(() => makeCompressionPlan({ durationSeconds: 600, mode: "unknown" }));
  assert.throws(() => makeCompressionPlan({ durationSeconds: 600, mode: "size", frameRate: "120" }));
  assert.throws(() => makeCompressionPlan({ durationSeconds: 100000, mode: "size" }), /1GB/);
  for (const sample of [{bytes:0,durationSeconds:60},{bytes:100,durationSeconds:1},{bytes:100,durationSeconds:601},{bytes:Infinity,durationSeconds:60}])
    assert.throws(() => makeCompressionPlan({ durationSeconds: 600, mode: "quality", sample }));
});

function nativeMetadataFixture() {
  const events = [];
  const video = { duration: 11926.837, videoWidth:1920, videoHeight:1080,
    removeAttribute(name) { events.push(`remove:${name}`); }, load() { events.push("load"); } };
  return { video, events, options: {
    documentObject: { createElement: () => video },
    urls: { createObjectURL: () => { events.push("create"); return "blob:local"; }, revokeObjectURL: url => events.push(`revoke:${url}`) }
  } };
}
test("metadata reader releases the blob and native media resource after completion", async () => {
  const f = nativeMetadataFixture();
  const result = readVideoMetadata({}, f.options);
  f.video.onloadedmetadata();
  assert.deepEqual(await result, {durationSeconds:11926.837,width:1920,height:1080});
  assert.deepEqual(f.events, ["create","remove:src","load","revoke:blob:local"]);
  assert.equal(f.video.onloadedmetadata, null);
});
test("metadata reader cleans up on replacement/logout, unsupported media and timeout", async () => {
  for (const cause of ["abort", "error", "invalid", "timeout"]) {
    const f = nativeMetadataFixture(), controller = new AbortController();
    const result = readVideoMetadata({}, {...f.options, signal:controller.signal, timeoutMs:cause === "timeout" ? 1 : 10000});
    const rejected = assert.rejects(result);
    if (cause === "abort") controller.abort();
    if (cause === "error") f.video.onerror();
    if (cause === "invalid") { f.video.duration = Infinity; f.video.onloadedmetadata(); }
    await rejected;
    assert.deepEqual(f.events, ["create","remove:src","load","revoke:blob:local"]);
  }
  const f = nativeMetadataFixture(), controller = new AbortController();
  controller.abort();
  await assert.rejects(readVideoMetadata({}, {...f.options, signal:controller.signal}), {name:"AbortError"});
  assert.deepEqual(f.events, []);
});
