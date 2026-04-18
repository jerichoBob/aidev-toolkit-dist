// Clean, minimal template for professional documents

#set page(
  paper: "us-letter",
  margin: (top: 1in, bottom: 1in, left: 1in, right: 1in),
  footer: context {
    set text(size: 9pt, fill: rgb("#666666"))
    h(1fr)
    [#counter(page).display("1")]
    h(1fr)
  },
)

#set text(
  font: "Helvetica Neue",
  size: 11pt,
)

#set par(
  justify: false,
  leading: 0.65em,
)

// Headings
#show heading.where(level: 1): it => {
  set text(size: 18pt, weight: "bold")
  v(0.3em)
  it.body
  v(0.5em)
}

#show heading.where(level: 2): it => {
  set text(size: 14pt, weight: "bold")
  v(0.6em)
  it.body
  v(0.3em)
}

#show heading.where(level: 3): it => {
  set text(size: 12pt, weight: "bold")
  v(0.4em)
  it.body
  v(0.2em)
}

// Tables - clean styling
#show figure.where(kind: table): it => {
  set text(size: 9pt)
  it
}

#set table(
  stroke: 0.5pt + rgb("#cccccc"),
  inset: 5pt,
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

#show raw.where(block: false): it => {
  box(
    fill: rgb("#f0f0f0"),
    outset: (x: 2pt, y: 2pt),
    radius: 2pt,
    text(font: "Menlo", size: 9pt, it),
  )
}

// Lists
#set list(indent: 1em)
#set enum(indent: 1em)

// Horizontal rule
#let horizontalrule = line(length: 100%, stroke: 0.5pt + rgb("#cccccc"))

$body$
