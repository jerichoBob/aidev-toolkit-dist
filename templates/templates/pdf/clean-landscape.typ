// Clean, minimal template - landscape for wide tables

#set page(
  paper: "us-letter",
  flipped: true,
  margin: (top: 0.75in, bottom: 0.75in, left: 0.75in, right: 0.75in),
  footer: context {
    set text(size: 9pt, fill: rgb("#666666"))
    h(1fr)
    [#counter(page).display("1")]
    h(1fr)
  },
)

#set text(
  font: "Helvetica Neue",
  size: 10pt,
)

#set par(
  justify: false,
  leading: 0.65em,
)

// Headings
#show heading.where(level: 1): it => {
  set text(size: 16pt, weight: "bold")
  v(0.2em)
  it.body
  v(0.4em)
}

#show heading.where(level: 2): it => {
  set text(size: 13pt, weight: "bold")
  v(0.5em)
  it.body
  v(0.25em)
}

// Tables - clean styling, smaller font
#show figure.where(kind: table): it => {
  set text(size: 8pt)
  it
}

#set table(
  stroke: 0.5pt + rgb("#cccccc"),
  inset: 4pt,
  fill: (x, y) => if y == 0 { rgb("#f5f5f5") } else { white },
)

// Code blocks
#show raw.where(block: true): it => {
  set text(font: "Menlo", size: 9pt)
  block(
    width: 100%,
    fill: rgb("#f5f5f5"),
    inset: 10pt,
    it,
  )
}

// Lists
#set list(indent: 1em)
#set enum(indent: 1em)

#let horizontalrule = line(length: 100%, stroke: 0.5pt + rgb("#cccccc"))

$body$
