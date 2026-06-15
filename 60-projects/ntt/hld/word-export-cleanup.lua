local mermaid_count = 0

function CodeBlock(el)
  if el.classes and el.classes[1] == 'mermaid' then
    mermaid_count = mermaid_count + 1
    return {
      pandoc.Para({pandoc.Str('[Diagram '..tostring(mermaid_count)..' omitted in DOCX export; see Markdown source for Mermaid.]')})
    }
  end
end

function RawInline(el)
  if el.format == 'html' then
    return {}
  end
end

function RawBlock(el)
  if el.format == 'html' then
    return {}
  end
end
