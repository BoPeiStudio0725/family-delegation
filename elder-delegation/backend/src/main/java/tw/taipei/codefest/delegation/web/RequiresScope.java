package tw.taipei.codefest.delegation.web;

import tw.taipei.codefest.delegation.domain.Enums;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 標在 controller 方法上：路徑必須含 {elderId}。
 * 長者本人可直接通過；家屬必須有「有效且包含此範圍」的授權，否則回 403。
 * 家屬成功操作後會自動寫一筆操作紀錄。
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequiresScope {
    Enums.Scope value();
}
