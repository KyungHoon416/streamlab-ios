# HLS alternate audio listening QA

## Source and scope

Apple official example: https://developer.apple.com/streaming/examples/advanced-stream-dv-atmos.html

Master: https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8

The fetched master declares English and English (DVS), both en-US, across audio
codec groups. DVS adds spoken scene descriptions. This verifies alternate audio,
not a change of spoken language. The external sample may change or be unavailable.
It is streamed from Apple and not copied into this repository. Its availability
and advertised codecs do not prove 4K/HDR playback on a simulator.

## Manual steps (Simulator or device)

1. Run the StreamLab scheme normally (not XCTest). Use an adult profile and open
   a title, then 데모 재생. Turn the Mac/device volume on.
2. Open … → HLS 오디오 비교 · 영어 / 화면 해설. Wait until playing. An error or
   a single available audio option is not a PASS; record the message and options.
3. Open 자막 및 오디오 and choose English. Close the sheet and listen for 15–20
   seconds. Note playback time and what you hear.
4. Choose English (DVS), or the localized audio-description option. Seek back to
   the same interval and listen. Confirm added scene narration, not only a checkmark.
   Return to English and confirm the narration changes back. Choose a different
   interval if the first contains no narration.
5. Check pause, resume, ±10 seconds and close. Playback should remain usable and
   the previous screen orientation should return.
6. Select English (DVS), close the panel/player, reopen playback and reselect this
   HLS source. Confirm DVS is checked and the narration is audible. Repeat after
   terminating and relaunching the app with the same profile.
7. Select ordinary English, close/reopen and confirm ordinary English is restored.
8. With DVS saved on profile A, switch to profile B: it must use its own preference
   (default on a fresh profile). Return to A and confirm DVS remains selected.
9. With DVS saved, play a source without audio description, then return to this
   source. Confirm the temporary fallback did not erase the DVS preference.
10. Select 기본 오디오 and reopen: the source default should be selected rather
    than the previously saved DVS override.

Record commit, OS/device, source, option labels, interval, audible difference,
playback controls and PASS/FAIL. Capture errors if fetching fails. Never count
manifest inspection or a selected checkmark as proof of audible output.

## Outstanding validation

- Actual listening: NOT TESTED until user executes these steps.
- Different spoken language selection/restoration and profile isolation with real
  multi-language HLS: NOT TESTED; this sample cannot establish those results.
- DVS/standard role restoration: implemented; new Core tests and manual HLS restoration NOT TESTED here.
- Distinguishing multiple commentary tracks of the same language/role: NOT IMPLEMENTED.
