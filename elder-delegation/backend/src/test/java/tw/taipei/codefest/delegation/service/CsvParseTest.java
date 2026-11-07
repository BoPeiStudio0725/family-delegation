package tw.taipei.codefest.delegation.service;

import org.junit.jupiter.api.Test;

import java.io.BufferedReader;
import java.io.StringReader;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class CsvParseTest {
    @Test
    void parsesQuotedFields() {
        List<String> row = DataSeeder.parseCsvLine("a,\"b,c\",\"d\"\"e\",");
        assertEquals(List.of("a", "b,c", "d\"e", ""), row);
    }

    @Test
    void findsDistrictInAddress() {
        assertEquals("士林區", DataSeeder.districtFromAddress("臺北市士林區忠誠路二段101號"));
    }

    @Test
    void readsRecordsWithLineBreaksInsideQuotes() throws Exception {
        BufferedReader br = new BufferedReader(new StringReader(
                "甲,\"社區照顧關懷據點\n10個時段\",臺北市士林區,63000110\n乙,類型,地址,63000020\n"));
        String first = DataSeeder.readRecord(br);
        assertEquals(List.of("甲", "社區照顧關懷據點\n10個時段", "臺北市士林區", "63000110"),
                DataSeeder.parseCsvLine(first));
        assertEquals("乙,類型,地址,63000020", DataSeeder.readRecord(br));
        assertNull(DataSeeder.readRecord(br));
    }

    @Test
    void cleansLineBreaks() {
        assertEquals("社區照顧關懷據點 10個時段", DataSeeder.joinLines("社區照顧關懷據點\n 10個時段", " "));
        assertEquals("臺北市中山區", DataSeeder.joinLines("臺北市\r\n中山區", ""));
    }

    @Test
    void mapsDistrictCode() {
        assertEquals("士林區", DataSeeder.districtFromCode("63000110"));
        assertNull(DataSeeder.districtFromCode("99999999"));
    }
}
