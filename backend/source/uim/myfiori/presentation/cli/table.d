/// Plain-text table rendering for terminal output (UTF-8 aware).
module uim.myfiori.presentation.cli.table;

@safe:

import std.algorithm : max, min;
import std.array : appender, replicate;
import std.range : walkLength;

string renderTable(string[] header, string[][] rows, size_t maxWidth = 60) {
  auto widths = new size_t[header.length];
  foreach (i, h; header) widths[i] = h.walkLength;
  foreach (r; rows) foreach (i, c; r) widths[i] = min(maxWidth, max(widths[i], c.walkLength));

  auto w = appender!string;
  void line(string[] cells) {
    foreach (i, c; cells) {
      auto text = clip(c, widths[i]);
      w ~= text;
      if (i + 1 < cells.length) w ~= " ".replicate(widths[i] - text.walkLength + 2);
    }
    w ~= "\n";
  }
  line(header);
  foreach (i, width; widths) {
    w ~= "-".replicate(width);
    if (i + 1 < widths.length) w ~= "  ";
  }
  w ~= "\n";
  foreach (r; rows) line(r);
  return w.data;
}

private string clip(string s, size_t width) {
  if (s.walkLength <= width) return s;
  import std.utf : toUTF32, toUTF8;
  auto d = s.toUTF32;
  return d[0 .. width - 1].toUTF8 ~ "…";
}

unittest {
  auto t = renderTable(["A", "Bé"], [["xyz", "ü"]]);
  assert(t == "A    Bé\n---  --\nxyz  ü\n", t);
}
