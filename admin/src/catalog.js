export const adminEmail = "kkh9172@gmail.com";
export function canManage(user, token) {
  return (
    user?.email?.toLowerCase() === adminEmail &&
    user.emailVerified === true &&
    token?.firebase?.sign_in_provider === "google.com"
  );
}
export function validateTitle(input) {
  const d = { ...input };
  for (const key of [
    "id",
    "name",
    "synopsis",
    "genre",
    "artworkURL",
    "streamURL",
  ])
    d[key] = String(d[key] ?? "").trim();
  if (!/^[a-z0-9][a-z0-9-]{0,63}$/.test(d.id))
    throw Error("작품 ID는 영문 소문자·숫자·하이픈 1~64자로 입력하세요.");
  if (
    !d.name ||
    d.name.length > 120 ||
    !d.genre ||
    d.genre.length > 60 ||
    d.synopsis.length > 5000
  )
    throw Error("제목·장르·소개 길이를 확인하세요.");
  for (const [key, min, max] of [
    ["year", 1888, 2100],
    ["durationMinutes", 1, 10000],
    ["visualSeed", 0, 1000000],
    ["popularity", 0, 1000000],
  ]) {
    d[key] = Number(d[key]);
    if (!Number.isInteger(d[key]) || d[key] < min || d[key] > max)
      throw Error(`${key}: ${min}~${max} 정수를 입력하세요.`);
  }
  if (
    !["movie", "series"].includes(d.kind) ||
    !["ALL", "7+", "12+", "15+", "19+"].includes(d.rating)
  )
    throw Error("종류·등급을 확인하세요.");
  for (const key of ["artworkURL", "streamURL"])
    if (d[key]) {
      let u;
      try {
        u = new URL(d[key]);
      } catch {
        throw Error("올바른 HTTPS 주소를 입력하세요.");
      }
      if (
        u.protocol !== "https:" ||
        !u.hostname ||
        u.username ||
        u.password ||
        d[key].length > 2048
      )
        throw Error("자격 증명이 없는 HTTPS 주소만 사용할 수 있습니다.");
      if (key === "streamURL" && ! /\.(m3u8|mp4)$/.test(u.pathname))
        throw Error("영상 주소는 HLS .m3u8 또는 MP4 .mp4 주소여야 합니다.");
    }
  if (typeof d.published !== "boolean" || (d.published && !d.streamURL))
    throw Error("공개하려면 영상 주소를 입력하세요.");
  return d;
}
