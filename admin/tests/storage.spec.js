import assert from "node:assert/strict";
import { test, before, after } from "node:test";
import { readFile } from "node:fs/promises";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import { ref, uploadBytes, getMetadata, listAll, deleteObject } from "firebase/storage";
let env;
const token = {
  email: "Kkh9172@gmail.com",
  email_verified: true,
  firebase: { sign_in_provider: "google.com" },
};
const path = "videos/sample/12345678-1234-1234-1234-123456789abc.mp4";
const bytes = new Uint8Array(12);
const metadata = {
  contentType: "video/mp4",
  customMetadata: { titleId: "sample" },
};
before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-streamlab-admin",
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: await readFile(
        new URL("../../storage.rules", import.meta.url),
        "utf8",
      ),
    },
  });
});
after(async () => {
  await env?.cleanup();
});
test("a visitor uploads a new MP4, lists and reads it, but cannot destroy existing media", async () => {
  const db = env.unauthenticatedContext().storage();
  const file = ref(db, path);
  await assertSucceeds(uploadBytes(file, bytes, metadata));
  assert.equal((await getMetadata(file)).contentType, "video/mp4");
  assert.equal((await listAll(ref(db, "videos/sample"))).items[0].fullPath, path);
  await assertFails(uploadBytes(file, bytes, metadata));
  await assertFails(deleteObject(file));
});
test("invalid metadata, format, empty files and other paths denied", async () => {
  const owner = env.authenticatedContext("owner", token).storage();
  const fresh = "videos/sample/32345678-1234-1234-1234-123456789abc.mp4";
  for (const m of [
    { ...metadata, contentType: "text/html" },
    { contentType: "video/mp4" },
    { ...metadata, customMetadata: { titleId: "wrong", uploadedBy: "owner" } },
  ])
    await assertFails(uploadBytes(ref(owner, fresh), bytes, m));
  await assertFails(
    uploadBytes(ref(owner, fresh), new Uint8Array(0), metadata),
  );
  await assertFails(
    uploadBytes(ref(owner, "outside/test.mp4"), bytes, metadata),
  );
});
