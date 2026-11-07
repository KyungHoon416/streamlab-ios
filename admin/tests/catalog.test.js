import { test } from "node:test";
import assert from "node:assert/strict";
import { validateTitle } from "../src/catalog.js";
const title = {
  id: "sample",
  name: "Sample",
  synopsis: "Test",
  genre: "Test",
  year: 2026,
  durationMinutes: 30,
  kind: "movie",
  rating: "ALL",
  artworkURL: "",
  streamURL: "https://example.com/master.m3u8",
  visualSeed: 1,
  popularity: 1,
  published: true,
};
test("draft may omit stream, published content cannot", () => {
  assert.equal(
    validateTitle({ ...title, streamURL: "", published: false }).published,
    false,
  );
  assert.throws(() => validateTitle({ ...title, streamURL: "" }));
  assert.equal(validateTitle({ ...title, year: "2026" }).year, 2026);
});
test("compression form controls cannot leak into draft or published documents", () => {
  for (const published of [false, true]) {
    const result = validateTitle({ ...title, published, "compression-mode": "original", sourceBytes: 4_000_000_000 });
    assert.deepEqual(Object.keys(result).sort(), Object.keys(title).sort());
    assert.equal(result.published, published);
  }
});
test("reject dangerous URLs and malformed metadata", () => {
  for (const streamURL of [
    "http://example.com/a.m3u8",
    "https://user:pass@example.com/a.m3u8",
    "javascript:alert(1)",
    "https://example.com/watch?v=123",
  ])
    assert.throws(() => validateTitle({ ...title, streamURL }));
  for (const patch of [
    { id: "../x" },
    { durationMinutes: 0 },
    { visualSeed: -1 },
    { rating: "unknown" },
    { year: "bad" },
    { published: "true" },
  ])
    assert.throws(() => validateTitle({ ...title, ...patch }));
});

test("accept direct MP4 and HLS URLs with query parameters", () => {
  for (const streamURL of ["https://example.com/a.mp4", "https://example.com/a.mp4?alt=media&token=test", "https://example.com/a.m3u8?version=1"]) {
    assert.equal(validateTitle({...title, streamURL}).streamURL, streamURL);
  }
});
