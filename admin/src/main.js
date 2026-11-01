import "./style.css";
import { initializeApp } from "firebase/app";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  onAuthStateChanged,
  signOut,
  browserSessionPersistence,
  setPersistence,
} from "firebase/auth";
import {
  getFirestore,
  collection,
  getDocs,
  query,
  orderBy,
  limit,
  doc,
  runTransaction,
  serverTimestamp,
} from "firebase/firestore";
import config from "./firebase-config.json";
import { canManage, validateTitle } from "./catalog.js";
import {
  getStorage,
  ref as storageRef,
  uploadBytesResumable,
  getDownloadURL,
} from "firebase/storage";
import { VideoUpload } from "./upload.js";
const app = initializeApp(config),
  auth = getAuth(app),
  db = getFirestore(app);
const $ = (id) => document.getElementById(id),
  form = $("editor");
let titles = [],
  selected = null,
  revision = 0,
  epoch = 0,
  allowed = false,
  busy = false;
const message = (text) => {
  $("message").textContent = text;
};
const storage = getStorage(app);
let uploading = false;
function uploadBusy(value) {
  uploading = value;
  busy = value;
  for (const element of form.elements) element.disabled = value;
  form.elements.id.disabled = value || !!selected;
  $("upload-cancel").disabled = false;
  $("upload-cancel").hidden = !value;
  $("upload-progress").hidden = !value;
}
const uploader = new VideoUpload({
  start: (path, file, metadata) =>
    uploadBytesResumable(storageRef(storage, path), file, metadata),
  getURL: getDownloadURL,
  progress: (fraction) => {
    const percent = Math.floor(fraction * 100);
    $("upload-progress").value = percent;
    $("upload-status").textContent =
      percent === 100 ? "영상 URL을 확인하고 있어요…" : `업로드 중 ${percent}%`;
  },
  completed: (url) => {
    form.elements.streamURL.value = url;
    $("video-file").value = "";
    $("upload-status").textContent =
      "업로드 완료. 영상 URL이 입력됐습니다. 저장을 눌러 작품에 반영하세요.";
  },
  failed: (e) => {
    const messages = {
      "storage/unauthorized":
        "업로드 권한이 없습니다. 관리자 계정과 Storage 보안 규칙을 확인하세요.",
      "storage/bucket-not-found":
        "Storage가 아직 준비되지 않았습니다. 결제 연결과 버킷 생성을 확인하세요.",
      "storage/retry-limit-exceeded":
        "전송 시간이 초과됐습니다. 네트워크를 확인하고 다시 업로드하세요.",
      "storage/canceled": "업로드를 취소했습니다.",
      "storage/quota-exceeded": "Storage 사용량 또는 결제 상태를 확인하세요.",
    };
    $("upload-status").textContent =
      messages[e.code] ??
      (e.code
        ? "업로드하지 못했습니다. 네트워크와 Storage 설정을 확인한 뒤 다시 시도하세요."
        : e.message);
  },
  settled: () => uploadBusy(false),
});
function cancelUpload() {
  uploader.cancel();
  if (uploading) {
    uploadBusy(false);
    $("upload-status").textContent =
      "업로드를 취소했습니다. 기존 영상 URL은 유지됩니다. 전송 완료 직후 취소한 파일은 Storage에 남을 수 있습니다.";
  }
}
$("upload-cancel").onclick = cancelUpload;
$("upload-start").onclick = () => {
  if (!allowed || busy) return;
  if (!selected) {
    $("upload-status").textContent = "작품 정보를 먼저 비공개로 저장해 주세요.";
    return;
  }
  const file = $("video-file").files[0];
  uploadBusy(true);
  $("upload-progress").value = 0;
  $("upload-status").textContent = "MP4 파일을 확인하고 있어요…";
  uploader.run(file, `videos/${selected}/${crypto.randomUUID()}.mp4`, {
    contentType: "video/mp4",
    customMetadata: { titleId: selected, uploadedBy: auth.currentUser.uid },
  });
};
window.addEventListener("beforeunload", (event) => {
  if (uploading) {
    event.preventDefault();
    event.returnValue = "";
  }
});
function reset(item = null) {
  selected = item?.id ?? null;
  revision = item?.revision ?? 0;
  form.reset();
  for (const [k, v] of Object.entries(item ?? {})) {
    const el = form.elements.namedItem(k);
    if (el && k !== "updatedAt") {
      if (el.type === "checkbox") el.checked = v;
      else el.value = v;
    }
  }
  form.elements.id.disabled = !!selected;
  $("form-title").textContent = selected ? "작품 수정" : "새 작품";
  $("saved").textContent = "";
  $("upload-status").textContent = "";
}
function render() {
  const term = $("search").value.trim().toLocaleLowerCase();
  $("titles").replaceChildren();
  const filtered = titles.filter((x) =>
    `${x.name} ${x.id}`.toLocaleLowerCase().includes(term),
  );
  $("count").textContent =
    `전체 ${titles.length}개 · 검색 ${filtered.length}개${titles.length === 200 ? " (최대 200개 표시)" : ""}`;
  for (const item of filtered) {
    const b = document.createElement("button");
    b.className = "title-row";
    const title = document.createElement("strong");
    title.textContent = item.name;
    const badge = document.createElement("span");
    badge.className = `badge ${item.published ? "" : "draft"}`;
    badge.textContent = item.published ? "공개" : "비공개";
    const sub = document.createElement("small");
    sub.textContent = `${item.id} · ${item.year} · ${item.rating}`;
    b.append(title, badge, sub);
    b.onclick = () => {
      if (!busy) reset(item);
    };
    $("titles").append(b);
  }
  if (!filtered.length) {
    const p = document.createElement("p");
    p.textContent = "등록된 작품이 없습니다. 새 작품을 등록해 주세요.";
    $("titles").append(p);
  }
}
async function refresh() {
  const ticket = epoch;
  const snap = await getDocs(
    query(collection(db, "titles"), orderBy("name"), limit(200)),
  );
  if (ticket !== epoch || !allowed) return;
  titles = snap.docs.map((x) => ({ ...x.data(), id: x.id }));
  render();
}
function error(e) {
  const known = {
    "auth/popup-closed-by-user": "로그인 창이 닫혔습니다.",
    "auth/operation-not-allowed":
      "Firebase의 Google 로그인이 아직 활성화되지 않았습니다.",
    "auth/unauthorized-domain": "Firebase 인증 허용 도메인 설정을 확인하세요.",
    "permission-denied": "접근 권한이 없거나 저장 형식이 올바르지 않습니다.",
    unavailable: "네트워크에 연결한 뒤 다시 시도하세요.",
  };
  message(
    known[e.code] ??
      (e.message === "CONFLICT"
        ? "다른 화면에서 변경된 작품입니다. 새로고침 후 다시 편집하세요."
        : e.message === "EXISTS"
          ? "이미 사용 중인 작품 ID입니다."
          : "요청을 완료하지 못했습니다. 연결과 입력값을 확인한 뒤 다시 시도하세요."),
  );
}
$("login").onclick = async () => {
  try {
    await setPersistence(auth, browserSessionPersistence);
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (e) {
    error(e);
  }
};
$("logout").onclick = () => {
  cancelUpload();
  signOut(auth).catch(error);
};
onAuthStateChanged(auth, async (user) => {
  cancelUpload();
  const ticket = ++epoch;
  allowed = false;
  titles = [];
  reset();
  render();
  $("workspace").hidden = true;
  $("signin").hidden = false;
  $("logout").hidden = !user;
  $("identity").textContent = user?.email ?? "";
  message("");
  if (!user) return;
  try {
    const token = await user.getIdTokenResult();
    if (ticket !== epoch) return;
    if (!canManage(user, token.claims)) {
      message(
        "이 계정에는 관리자 권한이 없습니다. 승인된 Google 계정으로 로그인하세요.",
      );
      return;
    }
    allowed = true;
    $("signin").hidden = true;
    $("workspace").hidden = false;
    await refresh();
  } catch (e) {
    error(e);
  }
});
$("new").onclick = () => {
  if (!busy) reset();
};
$("refresh").onclick = () => {
  if (!busy) refresh().catch(error);
};
$("search").oninput = render;
form.onsubmit = async (e) => {
  e.preventDefault();
  if (!allowed || busy) return;
  let data;
  try {
    data = validateTitle({
      ...Object.fromEntries(new FormData(form)),
      id: selected ?? form.elements.id.value,
      published: form.elements.published.checked,
    });
  } catch (e) {
    message(e.message);
    return;
  }
  const previous = revision,
    ticket = epoch,
    editing = selected;
  busy = true;
  $("save").disabled = true;
  message("");
  try {
    await runTransaction(db, async (tx) => {
      const ref = doc(db, "titles", data.id),
        snap = await tx.get(ref);
      if (!editing && snap.exists()) throw Error("EXISTS");
      if (editing && (!snap.exists() || snap.data().revision !== previous))
        throw Error("CONFLICT");
      tx.set(ref, {
        ...data,
        revision: previous + 1,
        updatedAt: serverTimestamp(),
      });
    });
    if (ticket !== epoch) return;
    await refresh();
    if (ticket !== epoch || !allowed) return;
    reset(titles.find((x) => x.id === data.id));
    $("saved").textContent = "저장했습니다";
    message(
      data.published
        ? "앱에 공개했습니다. 앱에서 목록을 새로 불러오면 반영됩니다."
        : "비공개로 저장했습니다.",
    );
  } catch (e) {
    error(e);
  } finally {
    busy = false;
    $("save").disabled = false;
  }
};
