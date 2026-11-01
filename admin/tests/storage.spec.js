import { test, before, after } from "node:test";
import { readFile } from "node:fs/promises";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import { ref, uploadBytes, getMetadata, deleteObject } from "firebase/storage";
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
  customMetadata: { titleId: "sample", uploadedBy: "owner" },
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
test("admin creates and reads immutable MP4; anonymous cannot read through SDK or write", async () => {
  const owner = env.authenticatedContext("owner", token).storage(),
    anon = env.unauthenticatedContext().storage();
  await assertSucceeds(uploadBytes(ref(owner, path), bytes, metadata));
  await assertSucceeds(getMetadata(ref(owner, path)));
  await assertFails(getMetadata(ref(anon, path)));
  await assertFails(
    uploadBytes(
      ref(anon, "videos/sample/22345678-1234-1234-1234-123456789abc.mp4"),
      bytes,
      metadata,
    ),
  );
  await assertFails(uploadBytes(ref(owner, path), bytes, metadata));
  await assertFails(deleteObject(ref(owner, path)));
});
test("unauthorized accounts, invalid metadata, format, empty files and other paths denied", async () => {
  for (const claims of [
    { ...token, email: "other@example.com" },
    { ...token, email_verified: false },
    { ...token, firebase: { sign_in_provider: "password" } },
  ]) {
    await assertFails(
      uploadBytes(
        ref(env.authenticatedContext("owner", claims).storage(), path),
        bytes,
        metadata,
      ),
    );
  }
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
