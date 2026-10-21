import Foundation

public enum OfflineDownloadFailure {
    public static let insufficientSpace = "기기 저장 공간이 부족해 다운로드가 중단되었습니다. 공간을 확보한 뒤 다시 다운로드해 주세요."
    public static let reservationExceeded = "다운로드가 허용된 파일 크기를 초과해 중단되었습니다."
    public static let generic = "다운로드를 완료하지 못했습니다. Wi-Fi와 저장 공간을 확인한 뒤 다시 다운로드해 주세요."

    /// OS errors may wrap ENOSPC in a URL loading error. Bound traversal for malformed chains.
    public static func message(for error: (any Error)?) -> String {
        var current = error as NSError?
        for _ in 0..<8 {
            guard let value = current else { break }
            if (value.domain == NSCocoaErrorDomain && value.code == CocoaError.fileWriteOutOfSpace.rawValue)
                || (value.domain == NSPOSIXErrorDomain && value.code == 28) {
                return insufficientSpace
            }
            current = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return generic
    }
}
