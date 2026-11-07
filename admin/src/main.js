import "./style.css";
import { createViewer } from "./viewer.js";
import { initializeApp } from "firebase/app";
import {
  getFirestore,
  collection,
  getDocs,
  query,
  orderBy,
} from "firebase/firestore";
import { attachDraftVideo, persistTitle, moveTitleToTrash } from "./persist-title.js";
import config from "./firebase-config.json";
import { validateTitle } from "./catalog.js";
import {
  getStorage,
  ref as storageRef,
  uploadBytesResumable,
  getDownloadURL,
  getMetadata,
  listAll,
} from "firebase/storage";
import { VideoSelection } from "./selection.js";
import { VideoUpload, MAX_VIDEO_BYTES, formatVideoSize, uploadProgressText, validateMP4 } from "./upload.js";
import { CompressionPanel } from "./compression-panel.js";
const app = initializeApp(config),
  db = getFirestore(app);
const $ = (id) => document.getElementById(id),
  form = $("editor");
let titles = [],
  selected = null,
  revision = 0,
  epoch = 0,
  editingMode = false,
  busy = false;
const message = (text) => {
  $("message").textContent = text;
};
const storage = getStorage(app);
$("video-limit").textContent = `업로드 최대 ${formatVideoSize(MAX_VIDEO_BYTES)} · 2GB 이상은 압축 계획 안내`;
let uploading = false;
const compression = new CompressionPanel($("compression-panel"), () => {
  $("upload-start").disabled = busy || !compression.allowsUpload();
  $("upload-start").textContent = compression.file && compression.file.size >= 2_000_000_000
    ? "원본 파일 업로드" : "파일 업로드";
});
const selection = new VideoSelection((file, error) => {
  compression.select(file);
  $("video-selection").textContent = file
    ? `${file.name} · ${formatVideoSize(file.size)}`
    : "선택된 파일 없음";
  $("upload-status").textContent = error || (file ? (file.size >= 2_000_000_000 ? "파일이 선택됐습니다. 압축 계획을 확인하거나 원본 업로드를 선택하세요." : "파일이 선택됐습니다. 파일 업로드를 눌러 전송하세요.") : "");
}, file => validateMP4(file, { forUpload: false }));
const dropzone = $("video-dropzone");
let dragDepth = 0;
function clearDrag() {
  dragDepth = 0;
  dropzone.classList.remove("drag-over");
}
function chooseFiles(files) {
  if (!editingMode || busy) return;
  ++recoveryGeneration;
  $("recover-options").replaceChildren();
  const candidates = Array.from(files);
  $("video-file").value = "";
  selection.choose(candidates);
}
$("video-file").addEventListener("change", (event) => chooseFiles(event.target.files));
const isFileDrag = (event) => Array.from(event.dataTransfer?.types ?? []).includes("Files");
dropzone.addEventListener("dragenter", (event) => {
  if (!isFileDrag(event)) return;
  event.preventDefault();
  if (editingMode && !busy && ++dragDepth === 1) dropzone.classList.add("drag-over");
});
dropzone.addEventListener("dragleave", () => {
  if (--dragDepth <= 0) clearDrag();
});
dropzone.addEventListener("dragover", (event) => {
  if (!isFileDrag(event)) return;
  event.preventDefault();
  event.dataTransfer.dropEffect = editingMode && !busy ? "copy" : "none";
});
dropzone.addEventListener("drop", (event) => {
  if (!isFileDrag(event)) return;
  event.preventDefault();
  clearDrag();
  chooseFiles(event.dataTransfer.files);
});
// A missed drop must not navigate away from an unsaved editor.
for (const type of ["dragover", "drop"]) document.addEventListener(type, (event) => {
  if (isFileDrag(event)) event.preventDefault();
  if (type === "drop") clearDrag();
});
function uploadBusy(value) {
  uploading = value;
  clearDrag();
  busy = value;
  for (const element of form.elements) element.disabled = value;
  form.elements.id.disabled = value || !!selected;
  $("upload-cancel").disabled = false;
  $("upload-cancel").hidden = !value;
  $("upload-progress").hidden = !value;
  compression.setBusy(value);
}
const uploader = new VideoUpload({
  start: (path, file, metadata) =>
    uploadBytesResumable(storageRef(storage, path), file, metadata),
  getURL: getDownloadURL,
  progress: (fraction, snapshot) => {
    const percent = Math.floor(fraction * 100);
    $("upload-progress").value = percent;
    $("upload-status").textContent = uploadProgressText(snapshot);
  },
  completed: async (url) => {
    const item = titles.find(title => title.id === selected);
    const ticket = epoch;
    form.elements.streamURL.value = url;
    $("video-file").value = "";
    selection.clear();
    if (item && !item.published) {
      $("upload-cancel").disabled = true;
      $("upload-status").textContent = "영상 URL을 비공개 작품에 저장하고 있습니다…";
      try {
        await attachDraftVideo(db, item.id, revision, url);
      } catch (err) {
        if (ticket === epoch) {
          $("upload-status").textContent = "파일 전송은 완료됐지만 URL 저장에 실패했습니다. 작품을 다시 열고 ‘기존 업로드 찾기’를 눌러 주세요.";
          error(err);
        }
        return;
      }
      if (epoch !== ticket || selected !== item.id) return;
      item.streamURL = url;
      item.revision = ++revision;
      $("recover-options").replaceChildren();
      $("upload-status").textContent = "영상 URL을 저장했습니다. 공개하려면 ‘앱에 공개’를 체크하고 저장하세요.";
    } else {
      $("upload-status").textContent = "업로드 완료. 저장을 눌러 공개 작품의 영상을 교체하세요.";
    }
  },
  failed: (e) => {
    const messages = {
      "storage/unauthorized":
        "업로드 권한이 없습니다. 파일 형식과 업로드 경로를 확인하세요.",
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
$("upload-cancel").onclick = () => {
  uploader.cancel();
  uploadBusy(false);
  $("upload-status").textContent = "업로드를 취소했습니다.";
};
$("upload-start").onclick = async () => {
  if (!editingMode || busy) return;
  const file = selection.file;
  if (!file) {
    $("upload-status").textContent = "유효한 MP4 파일을 먼저 선택하세요.";
    return;
  }
  if (!compression.allowsUpload()) return;
  let draft;
  if (!selected) {
    if (!form.reportValidity()) return;
    try {
      draft = validateTitle({ ...Object.fromEntries(new FormData(form)), streamURL: "", published: false });
    } catch (err) {
      $("upload-status").textContent = err.message;
      return;
    }
  }
  ++recoveryGeneration;
  $("recover-options").replaceChildren();
  uploadBusy(true);
  $("upload-progress").value = 0;
  if (draft) {
    const ticket = epoch;
    $("upload-status").textContent = "비공개 작품을 저장하고 있어요…";
    $("upload-cancel").disabled = true;
    try {
      await persistTitle(db, draft, null, 0);
    } catch (err) {
      if (epoch === ticket) {
        uploadBusy(false);
        error(err);
        $("upload-status").textContent = err.message === "EXISTS"
          ? "이미 등록된 작품 ID입니다. 다른 ID를 입력하거나 기존 작품을 선택하세요."
          : "비공개 작품을 저장하지 못했습니다. 다시 시도해 주세요.";
      }
      return;
    }
    if (epoch !== ticket || !editingMode) return;
    selected = draft.id;
    $("trash-title").hidden = false;
    revision = 1;
    $("form-title").textContent = "작품 수정";
    $("upload-cancel").disabled = false;
    $("recover-video").hidden = false;
    titles.push({ ...draft, revision });
    render();
  }
  $("upload-status").textContent = "MP4 파일을 확인하고 있어요…";
  uploader.run(file, `videos/${selected}/${crypto.randomUUID()}.mp4`, {
    contentType: "video/mp4",
    customMetadata: { titleId: selected },
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
  ++recoveryGeneration;
  $("recover-options").replaceChildren();
  $("recover-video").hidden = !item;
  form.reset();
  selection.clear();
  clearDrag();
  for (const [k, v] of Object.entries(item ?? {})) {
    const el = form.elements.namedItem(k);
    if (el && k !== "updatedAt") {
      if (el.type === "checkbox") el.checked = v;
      else el.value = v;
    }
  }
  form.elements.id.disabled = !!selected;
  $("trash-title").hidden = !selected;
  $("form-title").textContent = selected ? "작품 수정" : "새 작품";
  $("saved").textContent = "";
  $("upload-status").textContent = "";
}
let recoveryGeneration = 0;
$("recover-video").onclick = async () => {
  if (!editingMode || busy || !selected) return;
  const generation = ++recoveryGeneration;
  const current = () => editingMode && !busy && generation === recoveryGeneration;
  const options = $("recover-options");
  options.replaceChildren();
  $("upload-status").textContent = "이 작품에 업로드한 파일을 찾고 있습니다…";
  try {
    const folder = storageRef(storage, `videos/${selected}`);
    const { items } = await listAll(folder);
    const files = await Promise.all(items.map(async ref => ({ ref, meta: await getMetadata(ref) })));
    if (!current()) return;
    files.sort((a, b) => b.meta.timeCreated.localeCompare(a.meta.timeCreated));
    $("upload-status").textContent = files.length ? "연결할 파일을 선택한 뒤 공개 여부를 확인하고 저장하세요." : "이 작품에 업로드된 파일이 없습니다.";
    let linked;
    try {
      linked = storageRef(storage, form.elements.streamURL.value);
    } catch {
      // External catalog URLs do not identify an object in this bucket.
    }
    for (const { ref, meta } of files) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = `${new Date(meta.timeCreated).toLocaleString("ko-KR")} · ${(meta.size / 1e6).toFixed(2)} MB · ${ref.name.slice(0, 8)} 연결`;
      if (linked?.bucket === ref.bucket && linked.fullPath === ref.fullPath) {
        button.textContent = button.textContent.replace(/ 연결$/, " · 현재 연결됨");
        button.disabled = true;
      }
      button.onclick = async () => {
        if (!current()) return;
        const choice = ++recoveryGeneration;
        options.replaceChildren();
        try {
          const url = await getDownloadURL(ref);
          if (choice !== recoveryGeneration || !editingMode || busy) return;
          selection.clear();
          form.elements.streamURL.value = url;
          $("upload-status").textContent = "기존 파일을 연결했습니다. 공개 여부를 확인하고 저장하세요.";
        } catch (err) { if (choice === recoveryGeneration) error(err); }
      };
      options.append(button);
    }
  } catch (err) { if (current()) { $("upload-status").textContent = "파일 목록을 불러오지 못했습니다."; error(err); } }
};
function render() {
  const term = $("search").value.trim().toLocaleLowerCase();
  $("titles").replaceChildren();
  const visible = titles.filter(item => Boolean(item.trashed) === $("show-trash").checked);
  const filtered = visible.filter((x) =>
    `${x.name} ${x.id}`.toLocaleLowerCase().includes(term),
  );
  $("count").textContent =
    `전체 ${visible.length}개 · 검색 ${filtered.length}개`;
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
    if (item.trashed) b.append(" · 복구");
    b.onclick = () => {
      if (busy) return;
      if (item.trashed) changeTrash(item, false);
      else reset(item);
    };
    $("titles").append(b);
  }
  if (!filtered.length) {
    const p = document.createElement("p");
    p.textContent = "표시할 작품이 없습니다.";
    $("titles").append(p);
  }
}
async function refresh() {
  const ticket = epoch;
  const snap = await getDocs(
    query(collection(db, "titles"), orderBy("name")),
  );
  if (ticket !== epoch || !editingMode) return;
  titles = snap.docs.map((x) => ({ ...x.data(), id: x.id }));
  render();
}
function error(e) {
  const known = {
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
const viewer = createViewer(db);
async function switchMode(edit) {
  if (busy) return;
  ++epoch;
  editingMode = edit;
  message("");
  viewer.close();
  reset();
  $("show-trash").checked = false;
  $("workspace").hidden = !edit;
  $("edit-mode").hidden = edit;
  $("browse-mode").hidden = !edit;
  if (edit) await refresh().catch(error);
  else await viewer.open();
}
async function changeTrash(item, trashed) {
  if (!item || busy) return;
  if (trashed && !window.confirm(item.name + " 작품을 휴지통으로 옮길까요?")) return;
  busy = true;
  try {
    await moveTitleToTrash(db, item.id, item.revision, trashed);
    reset();
    await refresh();
    message(trashed ? "휴지통으로 옮겼습니다." : "앱 비공개로 복구했습니다.");
  } catch (e) { error(e); }
  finally { busy = false; }
}
$("trash-title").onclick = () => changeTrash({ id: selected, revision, name: form.elements.name.value }, true);
$("show-trash").onchange = () => { if (!busy) { reset(); render(); } };
$("edit-mode").onclick = () => switchMode(true);
$("browse-mode").onclick = () => switchMode(false);
switchMode(false);
$("new").onclick = () => {
  if (!busy) reset();
};
$("refresh").onclick = () => {
  if (!busy) refresh().catch(error);
};
$("search").oninput = render;
form.onsubmit = async (e) => {
  e.preventDefault();
  if (!editingMode || busy) return;
  if (selection.file) {
    $("upload-status").textContent = compression.allowsUpload()
      ? "선택한 MP4의 파일 업로드를 먼저 눌러 주세요."
      : "Mac에서 압축한 파일을 다시 선택하거나, 압축 계획에서 원본 업로드를 선택하세요.";
    if (compression.allowsUpload()) $("upload-start").focus();
    else $("compression-panel").querySelector("input:checked")?.focus();
    return;
  }
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
    await persistTitle(db, data, editing, previous);
    if (ticket !== epoch) return;
    await refresh();
    if (ticket !== epoch || !editingMode) return;
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
