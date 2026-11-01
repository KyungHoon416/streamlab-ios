import { test } from "node:test";
import assert from "node:assert/strict";
import { VideoSelection } from "../src/selection.js";
const file = () => new File([new Uint8Array([0,0,0,12,102,116,121,112,0,0,0,0])], "demo.mp4", {type:"video/mp4"});
test("drop/picker selection accepts one MP4 and clears it on invalid replacement", async () => {
  let error;
  const selection = new VideoSelection((_, message) => { error = message; });
  const video = file();
  await selection.choose([video]);
  assert.equal(selection.file, video);
  for (const files of [[video, video], [], [new File(["bad"], "bad.mp4")]]) {
    await selection.choose(files);
    assert.equal(selection.file, null);
    assert.ok(error);
  }
});
test("pending validation cannot restore a file after logout/reset or newer selection", async () => {
  const selection = new VideoSelection(() => {});
  let resolve;
  const slow = {name:"slow.mp4", size:12, slice:()=>({arrayBuffer:()=>new Promise(r=>resolve=r)})};
  const first = selection.choose([slow]);
  const video = file();
  await selection.choose([video]);
  resolve(await video.arrayBuffer());
  await first;
  assert.equal(selection.file, video);
  const pending = selection.choose([slow]);
  selection.clear();
  resolve(await video.arrayBuffer());
  await pending;
  assert.equal(selection.file, null);
});
