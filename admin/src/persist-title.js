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
