package tw.taipei.codefest.delegation.web;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

/** 所有錯誤都回 {"code": "...", "message": "..."}，Flutter 端直接顯示 message。 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, String>> handleApi(ApiException e) {
        return ResponseEntity.status(e.status).body(Map.of("code", e.code, "message", e.getMessage()));
    }

    /** 其他所有錯誤也回中文 message，前端才看得出問題在哪（黑客松除錯用）。 */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleOther(Exception e) {
        if (e instanceof org.springframework.web.ErrorResponse er) {
            // 404 找不到 API、405 方法不對… 保留原本的狀態碼
            int code = er.getStatusCode().value();
            String msg = code == 404 ? "找不到這個 API（後端可能還是舊版本，請重新啟動）" : "請求格式不正確（HTTP " + code + "）";
            return ResponseEntity.status(er.getStatusCode()).body(Map.of("code", "HTTP_" + code, "message", msg));
        }
        org.slf4j.LoggerFactory.getLogger(GlobalExceptionHandler.class).error("未預期的錯誤", e);
        String detail = e.getClass().getSimpleName() + (e.getMessage() == null ? "" : "：" + e.getMessage());
        if (detail.length() > 200) detail = detail.substring(0, 200);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("code", "SERVER_ERROR", "message", "後端發生錯誤：" + detail));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidation(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(f -> f.getField() + "：" + f.getDefaultMessage())
                .orElse("資料格式不正確");
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("code", "VALIDATION", "message", msg));
    }
}
