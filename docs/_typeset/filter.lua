--[[
Pandoc filter for the typeset course documents (see template.tex).

It keeps the Markdown sources plain and moves the presentation here:
  * headings: drops the hand-written "6.3" numbers, because LaTeX numbers the
    sections, and warns if the two numberings ever disagree;
  * requirements: an SRS paragraph that starts with **FR-n** or **NFR-n**
    becomes a requirement block, with its rationale and verification lines
    set apart;
  * tables: written as booktabs longtables with a tinted header row, zebra
    rows, and the column widths of the pipe table's separator row;
  * code: inline code gets break points; code blocks become framed listings;
  * images: a diagram "x.png" is replaced by the vector "x.pdf" when the build
    produced one.
]]

local stringify = pandoc.utils.stringify

-- ------------------------------------------------------------------ helpers

local function latex_escape_code(text)
  -- Escape text for \texttt and allow a line break after separators, so
  -- long identifiers and paths do not run into the margin.
  local out = {}
  local n = utf8.len(text) or #text
  local i = 0
  for _, cp in utf8.codes(text) do
    i = i + 1
    local ch = utf8.char(cp)
    local rep
    if ch == "\\" then rep = "\\textbackslash{}"
    elseif ch == "{" then rep = "\\{"
    elseif ch == "}" then rep = "\\}"
    elseif ch == "$" then rep = "\\$"
    elseif ch == "&" then rep = "\\&"
    elseif ch == "#" then rep = "\\#"
    elseif ch == "%" then rep = "\\%"
    elseif ch == "_" then rep = "\\_"
    elseif ch == "~" then rep = "\\textasciitilde{}"
    elseif ch == "^" then rep = "\\textasciicircum{}"
    elseif ch == " " then rep = "\\pimsp{}"
    elseif ch == "-" then rep = "-{}"
    elseif ch == "'" then rep = "\\textquotesingle{}"
    elseif ch == "`" then rep = "\\textasciigrave{}"
    elseif ch == "⌫" or ch == "⏎" then rep = "{\\symbolfallback " .. ch .. "}"
    else rep = ch end
    out[#out + 1] = rep
    if i > 1 and i < n and (ch == "_" or ch == "/" or ch == "|"
        or ch == "," or ch == "(" or ch == "=") then
      out[#out + 1] = "\\allowbreak{}"
    end
  end
  return table.concat(out)
end

local function to_latex_blocks(blocks)
  local doc = pandoc.Pandoc(blocks)
  return pandoc.write(doc, "latex", { wrap_text = "none" })
end

local function to_latex_inlines(inlines)
  return to_latex_blocks({ pandoc.Plain(inlines) })
end

local function raw(text)
  return pandoc.RawBlock("latex", text)
end

-- ------------------------------------------------------------------ inline code

function Code(el)
  -- Pipe tables need `\|` for a literal `|`; pandoc keeps the backslash.
  local text = el.text:gsub("\\|", "|")
  return pandoc.RawInline("latex", "\\pimcode{" .. latex_escape_code(text) .. "}")
end

-- ------------------------------------------------------------------ symbols

-- Charter has no arrows; set them (and the Backspace sign) in Source Sans 3.
local SANS_SYMBOLS = { ["→"] = true, ["←"] = true, ["↑"] = true, ["↓"] = true, ["⌫"] = true }

function Str(el)
  local found = false
  for _, cp in utf8.codes(el.text) do
    if SANS_SYMBOLS[utf8.char(cp)] then found = true break end
  end
  if not found then return nil end
  local out, buf = {}, {}
  local function flush()
    if #buf > 0 then out[#out + 1] = pandoc.Str(table.concat(buf)) buf = {} end
  end
  for _, cp in utf8.codes(el.text) do
    local ch = utf8.char(cp)
    if SANS_SYMBOLS[ch] then
      flush()
      out[#out + 1] = pandoc.RawInline("latex", "\\textsf{" .. ch .. "}")
    else
      buf[#buf + 1] = ch
    end
  end
  flush()
  return out
end

-- ------------------------------------------------------------------ code blocks

function CodeBlock(el)
  local body = el.text:gsub("%s+$", "")
  return raw("\\begin{pimcodeblock}\n\\begin{Verbatim}\n" .. body ..
    "\n\\end{Verbatim}\n\\end{pimcodeblock}")
end

-- ------------------------------------------------------------------ images

local build_dir = os.getenv("PIM_BUILD_DIR")

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

function Image(el)
  if build_dir then
    local name = el.src:match("^diagrams/(.+)%.png$")
    if name then
      local pdf = build_dir .. "/diagrams/" .. name .. ".pdf"
      if file_exists(pdf) then el.src = pdf end
    end
  end
  return el
end

-- ------------------------------------------------------------------ headings

local counters = { 0, 0, 0, 0, 0, 0 }

function Header(el)
  counters[el.level] = counters[el.level] + 1
  for l = el.level + 1, #counters do counters[l] = 0 end
  local first = el.content[1]
  if first and first.t == "Str" and first.text:match("^%d+[%.%d]*$") then
    local written = first.text:gsub("%.$", "")
    local parts = {}
    for l = 1, el.level do parts[#parts + 1] = tostring(counters[l]) end
    local expected = table.concat(parts, ".")
    if written ~= expected then
      io.stderr:write(string.format(
        "filter: heading '%s' is numbered %s in the source but %s in the PDF\n",
        stringify(el.content), written, expected))
    end
    el.content:remove(1)
    if el.content[1] and el.content[1].t == "Space" then el.content:remove(1) end
  end
  return el
end

-- ------------------------------------------------------------------ tables

local function cell_latex(cell)
  local text = to_latex_blocks(cell.contents):gsub("%s+$", "")
  return text
end

local function column_widths(tbl)
  local specs = tbl.colspecs
  local widths, total = {}, 0
  for i, spec in ipairs(specs) do
    local w = spec[2]
    if type(w) ~= "number" then w = nil end
    widths[i] = w
    total = total + (w or 0)
  end
  if total > 0 then
    for i = 1, #widths do widths[i] = (widths[i] or 0.1) / total end
    return widths
  end
  -- No widths in the source: weight each column by its longest cell.
  local longest = {}
  local function scan(rows)
    for _, row in ipairs(rows) do
      for i, cell in ipairs(row.cells) do
        local len = utf8.len(stringify(cell.contents)) or 0
        longest[i] = math.max(longest[i] or 4, math.min(len, 60))
      end
    end
  end
  scan(tbl.head.rows)
  for _, body in ipairs(tbl.bodies) do scan(body.body) end
  total = 0
  for i = 1, #specs do
    longest[i] = math.sqrt(longest[i] or 4)
    total = total + longest[i]
  end
  for i = 1, #specs do widths[i] = longest[i] / total end
  return widths
end

function Table(tbl)
  local widths = column_widths(tbl)
  local ncols = #widths
  local colspec = {}
  for i = 1, ncols do
    colspec[#colspec + 1] = string.format(
      ">{\\raggedright\\arraybackslash}p{(\\linewidth-%d\\tabcolsep)*\\real{%.4f}}",
      2 * ncols, widths[i])
  end

  local function row_latex(row, is_head)
    local cells = {}
    for _, cell in ipairs(row.cells) do
      local text = cell_latex(cell)
      if is_head then text = "\\pimhead{" .. text .. "}" end
      cells[#cells + 1] = "\\pimcellstart " .. text .. "\\pimcellend"
    end
    return table.concat(cells, " & ") .. " \\\\"
  end

  local head = {}
  for _, row in ipairs(tbl.head.rows) do
    head[#head + 1] = "\\rowcolor{tablehead}" .. row_latex(row, true)
  end
  local head_block = "\\toprule\n" .. table.concat(head, "\n") .. "\n\\midrule\n"

  local lines = {
    "\\begingroup\\pimtablefont",
    "\\arrayrulecolor{accent}",
    "\\begin{longtable}[l]{" .. table.concat(colspec) .. "}",
    head_block .. "\\endfirsthead",
    head_block .. "\\endhead",
    "\\arrayrulecolor{accent}\\bottomrule\\endfoot",
    "\\arrayrulecolor{accent}\\bottomrule\\endlastfoot",
  }
  local n = 0
  for _, body in ipairs(tbl.bodies) do
    for _, row in ipairs(body.body) do
      n = n + 1
      local prefix = (n % 2 == 0) and "\\rowcolor{tablezebra}" or ""
      if n > 1 then lines[#lines + 1] = "\\arrayrulecolor{rulegray}\\specialrule{0.3pt}{0pt}{0pt}" end
      lines[#lines + 1] = prefix .. row_latex(row, false)
    end
  end
  lines[#lines + 1] = "\\end{longtable}"
  lines[#lines + 1] = "\\endgroup"
  return raw(table.concat(lines, "\n"))
end

-- ------------------------------------------------------------------ requirements

local function starts_with_strong_req(block)
  if block.t ~= "Para" then return nil end
  local first = block.content[1]
  if not first or first.t ~= "Strong" then return nil end
  local text = stringify(first)
  local id, rest = text:match("^(N?FR%-%d+)%s*(.*)$")
  if not id then return nil end
  local title = rest:match("^%((.*)%)$") or rest
  return id, title
end

local function emph_label(inl)
  -- "*Verification:* text" or "*Rationale: text*" -> kind, label
  if not inl or inl.t ~= "Emph" then return nil end
  local text = stringify(inl)
  if text:match("^Verification") then return "verification" end
  if text:match("^Rationale") then return "rationale" end
  return nil
end

local function styled_line(inlines)
  -- inlines start with an Emph label; render one rationale/verification line.
  local kind = emph_label(inlines[1])
  if kind == "rationale" then
    return raw("\\pimrationale{" .. to_latex_inlines(inlines) .. "}")
  end
  local label = stringify(inlines[1]):gsub(":%s*$", "")
  local rest = pandoc.Inlines({})
  for i = 2, #inlines do rest:insert(inlines[i]) end
  while rest[1] and rest[1].t == "Space" do rest:remove(1) end
  return raw("\\pimverification{" .. to_latex_inlines(pandoc.Inlines({ pandoc.Str(label) })) ..
    "}{" .. to_latex_inlines(rest) .. "}")
end

local function split_lines(inlines)
  -- Split a paragraph at soft or hard breaks that precede a labelled Emph.
  local parts, current = {}, pandoc.Inlines({})
  for i, inl in ipairs(inlines) do
    if (inl.t == "SoftBreak" or inl.t == "LineBreak") and emph_label(inlines[i + 1]) then
      parts[#parts + 1] = current
      current = pandoc.Inlines({})
    else
      current:insert(inl)
    end
  end
  parts[#parts + 1] = current
  return parts
end

local function render_para_parts(inlines, out)
  for _, part in ipairs(split_lines(inlines)) do
    if emph_label(part[1]) then
      out[#out + 1] = styled_line(part)
    elseif #part > 0 then
      out[#out + 1] = pandoc.Para(part)
    end
  end
end

function Pandoc(doc)
  local out = {}
  local open = nil -- "requirement" or "reqgroup"

  local function close()
    if open then out[#out + 1] = raw("\\end{" .. open .. "}") end
    open = nil
  end

  for _, block in ipairs(doc.blocks) do
    local id, title = starts_with_strong_req(block)
    if id then
      close()
      local inlines = pandoc.Inlines({})
      for i = 2, #block.content do inlines:insert(block.content[i]) end
      while inlines[1] and inlines[1].t == "Space" do inlines:remove(1) end
      out[#out + 1] = raw("\\begin{requirement}{" .. id .. "}{" ..
        to_latex_inlines(pandoc.Inlines({ pandoc.Str(title) })) .. "}")
      open = "requirement"
      render_para_parts(inlines, out)
    elseif block.t == "Para" and emph_label(block.content[1]) then
      -- A verification line on its own: inside the open requirement, or a
      -- shared line for a run of requirements ("Verification of FR-17 – FR-23").
      local text = stringify(block.content[1])
      if text:match("^Verification of") or not open then
        close()
        out[#out + 1] = raw("\\begin{reqgroup}")
        open = "reqgroup"
        render_para_parts(block.content, out)
        close()
      else
        render_para_parts(block.content, out)
      end
    elseif block.t == "Para" and #block.content == 1 and block.content[1].t == "Strong" then
      -- A bold line on its own ("**Relationships.**") is a small heading:
      -- keep it with the paragraph that follows.
      close()
      local text = to_latex_inlines(block.content[1].content):gsub("%.%s*$", "")
      out[#out + 1] = raw("\\minisec{" .. text .. "}")
    elseif block.t == "Para" and open == "requirement" then
      -- A later paragraph of the requirement may end in its verification line.
      render_para_parts(block.content, out)
    elseif block.t == "Header" or block.t == "HorizontalRule" then
      close()
      out[#out + 1] = block
    else
      out[#out + 1] = block
    end
  end
  close()
  doc.blocks = out
  return doc
end
