import 'dart:convert';
import 'dart:typed_data';

/// Minimal, dependency-free .xlsx writer (Office Open XML in a "stored" zip).
/// Supports text, numbers, real dates, a few styles, column widths and a
/// frozen header row - everything the statement export needs.

/// Style ids (indexes into cellXfs in [_stylesXml]).
class XStyle {
  static const int normal = 0;
  static const int header = 1;
  static const int bold = 2;
  static const int money = 3;
  static const int moneyBold = 4;
  static const int date = 5;
}

class XCell {
  const XCell(this.value, [this.style = XStyle.normal]);

  /// String, int, double, DateTime (date only) or null.
  final Object? value;
  final int style;
}

class XSheet {
  XSheet(this.name, {this.freezeHeader = false});
  final String name;
  final bool freezeHeader;
  final List<List<XCell?>> rows = [];
  final Map<int, double> columnWidths = {};

  void addRow(List<XCell?> cells) => rows.add(cells);
}

class SimpleXlsx {
  SimpleXlsx._();

  static Uint8List build(List<XSheet> sheets) {
    final files = <String, String>{
      '[Content_Types].xml': _contentTypes(sheets.length),
      '_rels/.rels': _rootRels,
      'xl/workbook.xml': _workbook(sheets),
      'xl/_rels/workbook.xml.rels': _workbookRels(sheets.length),
      'xl/styles.xml': _stylesXml,
    };
    for (var i = 0; i < sheets.length; i++) {
      files['xl/worksheets/sheet${i + 1}.xml'] = _sheetXml(sheets[i]);
    }
    return _zip(files);
  }

  // ------------------------------------------------------------ XML parts

  static const String _xmlHead =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  static const String _ns =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  static String _contentTypes(int n) {
    final b = StringBuffer(_xmlHead)
      ..write(
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
      );
    for (var i = 1; i <= n; i++) {
      b.write(
        '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }
    b.write('</Types>');
    return b.toString();
  }

  static const String _rootRels = '$_xmlHead'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static String _workbook(List<XSheet> sheets) {
    final b = StringBuffer(_xmlHead)
      ..write(
        '<workbook xmlns="$_ns" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>',
      );
    for (var i = 0; i < sheets.length; i++) {
      b.write(
        '<sheet name="${_esc(_safeName(sheets[i].name))}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
      );
    }
    b.write('</sheets></workbook>');
    return b.toString();
  }

  static String _workbookRels(int n) {
    final b = StringBuffer(_xmlHead)
      ..write(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
      );
    for (var i = 1; i <= n; i++) {
      b.write(
        '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>',
      );
    }
    b.write(
      '<Relationship Id="rId${n + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>',
    );
    return b.toString();
  }

  static const String _stylesXml = '$_xmlHead'
      '<styleSheet xmlns="$_ns">'
      '<numFmts count="1"><numFmt numFmtId="164" formatCode="dd\\-mmm\\-yyyy"/></numFmts>'
      '<fonts count="3">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="3">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF0E6E4E"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="6">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="4" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';

  static String _sheetXml(XSheet s) {
    final b = StringBuffer(_xmlHead)..write('<worksheet xmlns="$_ns">');
    b.write('<sheetViews><sheetView workbookViewId="0">');
    if (s.freezeHeader) {
      b.write(
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>',
      );
    }
    b.write('</sheetView></sheetViews>');
    if (s.columnWidths.isNotEmpty) {
      b.write('<cols>');
      final keys = s.columnWidths.keys.toList()..sort();
      for (final c in keys) {
        b.write(
          '<col min="${c + 1}" max="${c + 1}" width="${s.columnWidths[c]}" customWidth="1"/>',
        );
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < s.rows.length; r++) {
      final row = s.rows[r];
      b.write('<row r="${r + 1}">');
      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell == null || cell.value == null) continue;
        final ref = '${_col(c)}${r + 1}';
        final v = cell.value;
        final st = cell.style == 0 ? '' : ' s="${cell.style}"';
        if (v is DateTime) {
          b.write('<c r="$ref"$st><v>${_serial(v)}</v></c>');
        } else if (v is num) {
          final n = v.isFinite ? v : 0;
          b.write('<c r="$ref"$st><v>$n</v></c>');
        } else {
          b.write(
            '<c r="$ref"$st t="inlineStr"><is><t xml:space="preserve">${_esc(v.toString())}</t></is></c>',
          );
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData></worksheet>');
    return b.toString();
  }

  /// 0 -> A, 25 -> Z, 26 -> AA ...
  static String _col(int index) {
    var n = index + 1;
    final out = StringBuffer();
    final chars = <String>[];
    while (n > 0) {
      final rem = (n - 1) % 26;
      chars.add(String.fromCharCode(65 + rem));
      n = (n - 1) ~/ 26;
    }
    for (final ch in chars.reversed) {
      out.write(ch);
    }
    return out.toString();
  }

  /// Excel serial day number for a calendar date.
  static int _serial(DateTime d) => DateTime.utc(d.year, d.month, d.day)
      .difference(DateTime.utc(1899, 12, 30))
      .inDays;

  static String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
    if (cleaned.isEmpty) return 'Sheet';
    return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
  }

  static String _esc(String s) {
    final b = StringBuffer();
    for (final rune in s.runes) {
      if (rune == 0x9 || rune == 0xA || rune == 0xD || rune >= 0x20) {
        switch (rune) {
          case 0x26:
            b.write('&amp;');
          case 0x3C:
            b.write('&lt;');
          case 0x3E:
            b.write('&gt;');
          case 0x22:
            b.write('&quot;');
          case 0x27:
            b.write('&apos;');
          default:
            b.writeCharCode(rune);
        }
      }
    }
    return b.toString();
  }

  // ------------------------------------------------------------------ ZIP

  static final List<int> _crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    return c;
  });

  static int _crc32(List<int> data) {
    var c = 0xFFFFFFFF;
    for (final byte in data) {
      c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static void _u16(BytesBuilder b, int v) {
    b.addByte(v & 0xFF);
    b.addByte((v >> 8) & 0xFF);
  }

  static void _u32(BytesBuilder b, int v) {
    b.addByte(v & 0xFF);
    b.addByte((v >> 8) & 0xFF);
    b.addByte((v >> 16) & 0xFF);
    b.addByte((v >> 24) & 0xFF);
  }

  static Uint8List _zip(Map<String, String> files) {
    // DOS date 2026-01-01, time 00:00.
    const dosDate = ((2026 - 1980) << 9) | (1 << 5) | 1;
    const dosTime = 0;
    final out = BytesBuilder();
    final central = BytesBuilder();
    var count = 0;
    files.forEach((name, text) {
      final nameBytes = utf8.encode(name);
      final data = utf8.encode(text);
      final crc = _crc32(data);
      final offset = out.length;
      // Local file header
      _u32(out, 0x04034b50);
      _u16(out, 20); // version needed
      _u16(out, 0x0800); // UTF-8 names
      _u16(out, 0); // stored
      _u16(out, dosTime);
      _u16(out, dosDate);
      _u32(out, crc);
      _u32(out, data.length);
      _u32(out, data.length);
      _u16(out, nameBytes.length);
      _u16(out, 0);
      out.add(nameBytes);
      out.add(data);
      // Central directory entry
      _u32(central, 0x02014b50);
      _u16(central, 20); // version made by
      _u16(central, 20); // version needed
      _u16(central, 0x0800);
      _u16(central, 0);
      _u16(central, dosTime);
      _u16(central, dosDate);
      _u32(central, crc);
      _u32(central, data.length);
      _u32(central, data.length);
      _u16(central, nameBytes.length);
      _u16(central, 0); // extra
      _u16(central, 0); // comment
      _u16(central, 0); // disk
      _u16(central, 0); // internal attrs
      _u32(central, 0); // external attrs
      _u32(central, offset);
      central.add(nameBytes);
      count++;
    });
    final centralOffset = out.length;
    final centralBytes = central.toBytes();
    out.add(centralBytes);
    _u32(out, 0x06054b50);
    _u16(out, 0);
    _u16(out, 0);
    _u16(out, count);
    _u16(out, count);
    _u32(out, centralBytes.length);
    _u32(out, centralOffset);
    _u16(out, 0);
    return out.toBytes();
  }
}
