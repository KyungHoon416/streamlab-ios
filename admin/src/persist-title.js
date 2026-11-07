import { doc, runTransaction, serverTimestamp } from "firebase/firestore";

export function persistTitle(db, data, editing, previous) {
  return runTransaction(db, async (tx) => {
    const ref = doc(db, "titles", data.id);
    const snap = await tx.get(ref);
    if (!editing && snap.exists()) throw Error("EXISTS");
    if (editing && (!snap.exists() || snap.data().revision !== previous))
      throw Error("CONFLICT");
    tx.set(ref, { ...data, revision: previous + 1, updatedAt: serverTimestamp() });
  });
}

// Attach the completed upload without saving unrelated editor fields or publishing.
export function attachDraftVideo(db, id, revision, streamURL) {
  return runTransaction(db, async tx => {
    const ref = doc(db, "titles", id);
    const snap = await tx.get(ref);
    if (!snap.exists() || snap.data().published || snap.data().revision !== revision)
      throw Error("CONFLICT");
    tx.update(ref, { streamURL, revision: revision + 1, updatedAt: serverTimestamp() });
  });
}

// Restore to draft so that recovering a title never publishes it to the iOS app.
export function moveTitleToTrash(db, id, revision, trashed) {
  return runTransaction(db, async tx => {
    const ref = doc(db, "titles", id);
    const snap = await tx.get(ref);
    if (!snap.exists() || snap.get("revision") !== revision ||
        Boolean(snap.get("trashed")) === trashed) throw Error("CONFLICT");
    tx.update(ref, { trashed, published: false, revision: revision + 1, updatedAt: serverTimestamp() });
  });
}
