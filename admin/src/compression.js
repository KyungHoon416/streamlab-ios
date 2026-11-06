export const COMPRESSION_THRESHOLD_BYTES = 2_000_000_000;
export const TARGET_BYTES = 1_000_000_000;
export const AUDIO_KBPS = 96;

export const needsCompressionChoice = (bytes) => bytes >= COMPRESSION_THRESHOLD_BYTES;

export function makeCompressionPlan({ durationSeconds, sourceBytes, mode, frameRate = "30", sample }) {
  if (!["ratio40", "size", "quality"].includes(mode)) throw Error("압축 방식을 선택하세요.");
  if (!["30", "source"].includes(frameRate)) throw Error("프레임 설정을 확인하세요.");
  if (!Number.isFinite(durationSeconds) || durationSeconds <= 0)
    throw Error("영상 길이를 확인하거나 직접 입력하세요.");
  const plan = { version: 1, mode, durationSeconds, frameRate, maxHeight: 1080,
    codec: "hevc", audioKbps: AUDIO_KBPS, estimatedBytes: null };
  if (mode === "size" || mode === "ratio40") {
    if (mode === "ratio40" && (!Number.isSafeInteger(sourceBytes) || sourceBytes <= 0))
      throw Error("원본 파일 크기를 확인하세요.");
    const targetBytes = mode === "ratio40" ? Math.floor(sourceBytes * 0.4) : TARGET_BYTES;
    const headroom = mode === "ratio40" ? 0.98 : 0.94;
    // Leave room for muxing and rate-control variation. Validate the actual file
    // after encoding; this arithmetic is a plan, never a promise of final size.
    const videoKbps = Math.floor((targetBytes * headroom * 8 / durationSeconds / 1000 - AUDIO_KBPS) / 10) * 10;
    if (!Number.isFinite(videoKbps) || videoKbps < 50)
      throw Error(`이 길이의 영상은 ${mode === "size" ? "1GB" : "40% 크기"} 목표로 권장 설정을 만들 수 없습니다. 화질 우선을 선택하세요.`);
    return { ...plan, targetBytes, ...(mode === "ratio40" ? { sourceBytes, targetRatio: 0.4 } : {}), videoKbps,
      estimatedBytes: durationSeconds * (videoKbps + AUDIO_KBPS) * 1000 / 8 };
  }
  plan.crf = 28;
  if (sample) {
    if (!Number.isSafeInteger(sample.bytes) || sample.bytes <= 0 ||
        !Number.isFinite(sample.durationSeconds) || sample.durationSeconds < 10 ||
        sample.durationSeconds > durationSeconds)
      throw Error("같은 원본·설정으로 만든 10초 이상의 압축 샘플을 선택하세요.");
    plan.estimatedBytes = sample.bytes / sample.durationSeconds * durationSeconds;
    plan.sample = { bytes: sample.bytes, durationSeconds: sample.durationSeconds };
  }
  return plan;
}

export function compressionNotes(plan) {
  const notes = ["이 페이지는 파일을 압축하지 않습니다. Mac에서 압축을 마친 뒤 완성된 MP4를 다시 선택하세요."];
  if (plan.mode === "ratio40") notes.push("원본의 약 40% 크기, 약 60% 감소를 목표로 합니다. 여유분을 포함한 계획이며 실제 크기는 압축 후 확인합니다.");
  else if (plan.mode === "size") notes.push("용량 우선 설정입니다. 최종 파일이 1GB 이하인지는 압축 후 확인해야 합니다.");
  else notes.push("화질 우선도 손실 압축입니다. 샘플 환산값은 장면 구성에 따라 달라지며 1GB를 넘을 수 있습니다.");
  if (plan.videoKbps < 1000)
    notes.push("영상 비트레이트가 낮아 비·야경·빠른 움직임의 디테일 손실이 클 수 있습니다.");
  if (plan.frameRate === "source")
    notes.push("원본이 60fps일 때만 최대 60fps를 유지합니다. 같은 용량에서는 30fps보다 프레임당 데이터가 줄어들 수 있습니다.");
  return notes;
}

export function formatCompressionRecipe(plan, sourceName) {
  return ["StreamLab · Mac 압축 설정", `원본: ${sourceName}`,
    `길이: ${plan.durationSeconds.toFixed(3)}초`,
    `방식: ${{ ratio40: "원본의 40% 크기 목표 · 약 60% 감소 · 평균 비트레이트", size: "1GB 이하 목표 · 2-pass", quality: "화질 우선 · CRF 28 (샘플 확인 필요)" }[plan.mode]}`,
    "해상도: 최대 1920×1080, 원본 비율 유지, 작은 원본 확대 안 함",
    `프레임: ${plan.frameRate === "30" ? "최대 30fps" : "원본 유지 · 최대 60fps"}`,
    "영상: HEVC MP4 (hvc1) / 오디오: AAC 96kbps",
    ...(plan.videoKbps ? [`영상 평균 비트레이트: ${plan.videoKbps}kbps`] : []),
    "원본을 보관하고 새 파일로 저장하세요. HDR 원본은 SDR 변환 또는 HDR 유지 설정을 별도로 확인하세요.",
    ...compressionNotes(plan),
    "", "계획 데이터 (실행 명령이 아닙니다)", JSON.stringify(plan, null, 2), ""].join("\n");
}
