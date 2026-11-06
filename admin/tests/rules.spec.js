import { persistTitle, attachDraftVideo } from "../src/persist-title.js";
import assert from "node:assert/strict";
import { test, after, before } from "node:test";
import { readFile } from "node:fs/promises";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import {
  doc,
  setDoc,
  getDoc,
  getDocs,
  getDocsFromServer,
  collection,
  query,
  where,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} from "firebase/firestore";
let env;
const token = {
  email: "Kkh9172@gmail.com",
  email_verified: true,
  firebase: { sign_in_provider: "google.com" },
};
const data = (id, published = false) => ({
  id,
  name: "Sample",
  synopsis: "Test",
  genre: "Test",
  year: 2026,
  durationMinutes: 30,
  kind: "movie",
  rating: "ALL",
  artworkURL: "",
  streamURL: published ? "https://example.com/a.m3u8" : "",
  visualSeed: 1,
  popularity: 1,
  published,
  revision: 1,
  updatedAt: serverTimestamp(),
});
before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-streamlab-admin",
    firestore: {
      host: "127.0.0.1",
      port: 8088,
      rules: await readFile(
        new URL("../../firestore.rules", import.meta.url),
        "utf8",
      ),
    },
  });
});
after(async () => {
  await env?.cleanup();
});

test("admin can publish MP4, but not a web page URL", async () => {
  const db=env.authenticatedContext('owner',token).firestore();
  await assertSucceeds(setDoc(doc(db,'titles/mp4'),{...data('mp4',true),streamURL:'https://example.com/video.mp4?alt=media&token=test'}));
  await assertFails(setDoc(doc(db,'titles/webpage'),{...data('webpage',true),streamURL:'https://example.com/watch?v=123'}));
});
test("four-hour MP4 metadata can be published and read by the app", async () => {
  const admin = env.authenticatedContext("owner", token).firestore();
  const anon = env.unauthenticatedContext().firestore();
  const movie = { ...data("four-hours", true), durationMinutes: 240, streamURL: "https://example.com/four-hours.mp4" };
  await assertSucceeds(setDoc(doc(admin, "titles/four-hours"), movie));
  const saved = await assertSucceeds(getDoc(doc(anon, "titles/four-hours")));
  assert.equal(saved.data().durationMinutes, 240);
});
test("admin create, revision update, public query, unpublish and denied deletion", async () => {
  const admin = env.authenticatedContext("owner", token).firestore(),
    anon = env.unauthenticatedContext().firestore();
  await assertSucceeds(
    setDoc(doc(admin, "titles/public"), data("public", true)),
  );
  await assertSucceeds(setDoc(doc(admin, "titles/draft"), data("draft")));
  await assertSucceeds(getDoc(doc(anon, "titles/public")));
  await assertSucceeds(
    getDocs(query(collection(anon, "titles"), where("published", "==", true))),
  );
  await assertFails(getDoc(doc(anon, "titles/draft")));
  await assertFails(getDocs(collection(anon, "titles")));
  await assertFails(setDoc(doc(anon, "titles/attack"), data("attack", true)));
  await assertFails(
    updateDoc(doc(admin, "titles/public"), {
      name: "bad revision",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(doc(admin, "titles/public"), {
      published: false,
      revision: 2,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(getDoc(doc(anon, "titles/public")));
  await assertFails(deleteDoc(doc(admin, "titles/public")));
});
test("wrong email, unverified email and password provider cannot write", async () => {
  for (const claims of [
    { ...token, email: "other@example.com" },
    { ...token, email_verified: false },
    { ...token, firebase: { sign_in_provider: "password" } },
  ]) {
    const db = env.authenticatedContext("outsider", claims).firestore();
    await assertFails(setDoc(doc(db, "titles/noaccess"), data("noaccess")));
  }
});
test("schema, timestamps and publish URL enforced server-side", async () => {
  const db = env.authenticatedContext("owner", token).firestore();
  for (const patch of [
    { published: true },
    { streamURL: "http://example.com/a.m3u8" },
    { admin: true },
    { revision: 7 },
    { durationMinutes: 0 },
    { updatedAt: new Date(0) },
  ]) {
    await assertFails(
      setDoc(doc(db, "titles/invalid"), { ...data("invalid"), ...patch }),
    );
  }
  await assertFails(setDoc(doc(db, "users/owner"), { role: "admin" }));
});

test("fresh iOS playback lookup follows unpublish and replacement on republish", async () => {
  const id = "playback-visibility";
  const admin = env.authenticatedContext("owner", token).firestore();
  const viewer = env.unauthenticatedContext().firestore();
  const title = doc(admin, "titles", id);
  const lookup = query(collection(viewer, "titles"), where("published", "==", true), where("id", "==", id));
  const playbackURLs = async () =>
    (await getDocsFromServer(lookup)).docs.map(snapshot => snapshot.get("streamURL"));

  const published = data(id, true);
  await setDoc(title, published);
  assert.deepEqual(await playbackURLs(), [published.streamURL]);
  await updateDoc(title, { published: false, revision: 2, updatedAt: serverTimestamp() });
  assert.deepEqual(await playbackURLs(), []);
  const replacement = "https://example.com/replacement.mp4";
  await updateDoc(title, { published: true, streamURL: replacement, revision: 3, updatedAt: serverTimestamp() });
  assert.deepEqual(await playbackURLs(), [replacement]);
});

test("a new file upload reserves a private ID before attaching the MP4 URL", async () => {
  const db = env.authenticatedContext("owner", token).firestore();
  const viewer = env.unauthenticatedContext().firestore();
  const id = "new-file-draft";
  const draft = data(id);
  await persistTitle(db, draft, null, 0);
  await assertFails(getDoc(doc(viewer, "titles", id)));
  await assert.rejects(persistTitle(db, draft, null, 0), /EXISTS/);
  const ready = { ...draft, published: true, streamURL: "https://example.com/upload.mp4" };
  await attachDraftVideo(db, id, 1, ready.streamURL);
  await assertFails(getDoc(doc(viewer, "titles", id)));
  const reopened = (await getDoc(doc(db, "titles", id))).data();
  assert.equal(reopened.streamURL, ready.streamURL);
  await assert.rejects(attachDraftVideo(db, id, 1, ready.streamURL), /CONFLICT/);
  await persistTitle(db, { ...reopened, published: true }, id, 2);
  const saved = await getDoc(doc(viewer, "titles", id));
  assert.equal(saved.get("streamURL"), ready.streamURL);
  assert.equal(saved.get("revision"), 3);
});

test("an existing upload can replace the published video without overwriting a newer edit", async () => {
  const id = "published-file-switch";
  const admin = env.authenticatedContext("owner", token).firestore();
  const viewer = env.unauthenticatedContext().firestore();
  const original = { ...data(id, true), streamURL: "https://example.com/original.mp4" };
  const replacement = { ...original, streamURL: "https://example.com/previous-upload.mp4" };
  await persistTitle(admin, original, null, 0);
  await persistTitle(admin, replacement, id, 1);
  await assert.rejects(persistTitle(admin, original, id, 1), /CONFLICT/);
  const saved = await getDoc(doc(viewer, "titles", id));
  assert.equal(saved.get("streamURL"), replacement.streamURL);
  assert.equal(saved.get("published"), true);
});
