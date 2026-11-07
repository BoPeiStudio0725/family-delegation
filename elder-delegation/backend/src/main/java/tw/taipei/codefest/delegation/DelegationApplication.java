/*
 * 長者家屬授權微服務 — 讓長者授權家屬在指定範圍內代辦市政服務
 * Copyright (C) 2026 麻辣燙不加辣
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Affero General Public License for more details. You should have
 * received a copy of the GNU Affero General Public License along
 * with this program. If not, see <https://www.gnu.org/licenses/>.
 */
package tw.taipei.codefest.delegation;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DelegationApplication {
    public static void main(String[] args) {
        SpringApplication.run(DelegationApplication.class, args);
    }
}
