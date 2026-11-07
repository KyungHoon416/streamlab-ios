import { collection, getDocs, orderBy, query } from "firebase/firestore";

export function createViewer(db) {
  const el = id => document.getElementById(id);
  const video = el("browse-player");
  let items = [], request = 0, media = 0, hls;

  function clearDetail() {
    media++;
    hls?.destroy();
    hls = undefined;
    video.pause();
    video.removeAttribute("src");
    video.load();
    video.hidden = true;
    el("browse-detail").hidden = true;
    el("browse-play-status").textContent = "";
  }

  async function select(item) {
    clearDetail();
    const ticket = media;
    el("browse-detail").hidden = false;
    el("browse-title").textContent = item.name;
    el("browse-title").focus();
    el("browse-info").textContent = [item.genre, item.year, item.rating, item.published ? "앱 공개" : "앱 비공개"].filter(Boolean).join(" · ");
    el("browse-synopsis").textContent = item.synopsis || "";
    if (!item.streamURL) {
      el("browse-play-status").textContent = "아직 연결된 영상이 없습니다.";
      return;
    }
    try {
      const url = new URL(item.streamURL);
      if (url.protocol !== "https:") throw Error();
      if (/\.m3u8$/i.test(url.pathname)) {
        const { default: Hls } = await import("hls.js");
        if (ticket !== media) return;
        if (Hls.isSupported()) {
          hls = new Hls();
          hls.on(Hls.Events.ERROR, (_, data) => {
            if (ticket === media && data.fatal) playbackError();
          });
          hls.loadSource(url.href);
          hls.attachMedia(video);
        } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
          video.src = url.href;
        } else {
          throw Error();
        }
      } else {
        video.src = url.href;
      }
      video.hidden = false;
    } catch {
      if (ticket === media) playbackError();
    }
  }

  function playbackError() {
    el("browse-play-status").textContent = "영상을 재생할 수 없습니다. 다른 작품을 선택하거나 잠시 후 다시 시도해 주세요.";
  }
  video.addEventListener("error", () => { if (!video.hidden) playbackError(); });

  function render() {
    const term = el("browse-search").value.trim().toLocaleLowerCase();
    const matches = items.filter(x => (x.name + " " + x.id).toLocaleLowerCase().includes(term));
    el("browse-status").textContent = matches.length ? matches.length + "개 작품" : "표시할 작품이 없습니다.";
    el("browse-list").replaceChildren(...matches.map(item => {
      const button = document.createElement("button");
      button.className = "title-row";
      button.textContent = item.name + " · " + (item.published ? "앱 공개" : "앱 비공개");
      button.onclick = () => select(item);
      return button;
    }));
  }

  async function open() {
    const ticket = ++request;
    clearDetail();
    items = [];
    el("viewer").hidden = false;
    el("browse-list").replaceChildren();
    el("browse-status").textContent = "작품을 불러오는 중입니다.";
    try {
      const snapshot = await getDocs(query(collection(db, "titles"), orderBy("name")));
      if (ticket !== request) return;
      items = snapshot.docs.map(doc => ({ ...doc.data(), id: doc.id })).filter(item => !item.trashed);
      render();
    } catch {
      if (ticket === request) el("browse-status").textContent = "작품을 불러오지 못했습니다. 새로고침해 주세요.";
    }
  }
  el("browse-search").oninput = render;
  el("browse-refresh").onclick = open;
  return { open, close() {
    request++;
    items = [];
    clearDetail();
    el("browse-search").value = "";
    el("browse-list").replaceChildren();
    el("viewer").hidden = true;
  } };
}
