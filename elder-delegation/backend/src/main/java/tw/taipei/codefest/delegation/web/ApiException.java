package tw.taipei.codefest.delegation.web;

import org.springframework.http.HttpStatus;

/** 統一的錯誤：code 給前端判斷，message 是可以直接顯示給使用者的白話中文。 */
public class ApiException extends RuntimeException {
    public final HttpStatus status;
    public final String code;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }

    public static ApiException badRequest(String code, String msg) { return new ApiException(HttpStatus.BAD_REQUEST, code, msg); }
    public static ApiException unauthorized(String msg) { return new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", msg); }
    public static ApiException forbidden(String code, String msg) { return new ApiException(HttpStatus.FORBIDDEN, code, msg); }
    public static ApiException notFound(String msg) { return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", msg); }
    public static ApiException conflict(String code, String msg) { return new ApiException(HttpStatus.CONFLICT, code, msg); }
}
