// Builds data/ai-dev-patterns-session-2026-11.pptx — deck for the AI-dev patterns
// keep/change/drop session. Source content: data/ai-dev-patterns-starting-point-2026-11-10.md
// and specs/spec-v135-ai-dev-patterns-standard.md. Nothing here is decided; every
// pattern is a proposal for the group to mark keep / change / drop.
//
// Usage: node scripts/build-ai-dev-patterns-deck.js [output.pptx]
const pptxgen = require("pptxgenjs");

const OUT = process.argv[2] || "data/ai-dev-patterns-session-2026-11.pptx";

const C = {
  ink: "12303B", // dominant dark teal
  mid: "1F5F6B",
  soft: "E6F0F1",
  accent: "F2A541",
  text: "1B2A30",
  muted: "5B6B70",
  white: "FFFFFF",
};
const HEAD = "Cambria";
const BODY = "Calibri";

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9"; // 10 x 5.625 in
pres.title = "AI-Dev Patterns: Starting Point";

function title(slide, text, dark = false) {
  slide.addText(text, {
    x: 0.5, y: 0.35, w: 9, h: 0.8, margin: 0,
    fontFace: HEAD, fontSize: 32, bold: true,
    color: dark ? C.white : C.ink, valign: "top",
  });
}

function footer(slide, n, dark = false) {
  slide.addText(`AI-Dev Patterns  |  ${n}`, {
    x: 0.5, y: 5.2, w: 9, h: 0.25, margin: 0,
    fontFace: BODY, fontSize: 10, color: dark ? "9DB8BC" : C.muted,
  });
}

// 1. Title
{
  const s = pres.addSlide();
  s.background = { color: C.ink };
  s.addText("AI-Dev Patterns", {
    x: 0.7, y: 1.5, w: 8.6, h: 1.0, margin: 0,
    fontFace: HEAD, fontSize: 48, bold: true, color: C.white,
  });
  s.addText("What is our starting point, and how do we proceed?", {
    x: 0.7, y: 2.6, w: 8.6, h: 0.6, margin: 0,
    fontFace: BODY, fontSize: 22, color: C.accent,
  });
  s.addText("Proposal for a 60-minute keep / change / drop session. Nothing here is decided.", {
    x: 0.7, y: 3.5, w: 8.6, h: 0.5, margin: 0,
    fontFace: BODY, fontSize: 16, color: "CFE0E3",
  });
  s.addNotes("Larry asked: what is our starting point for identifying, deciding on and documenting the AI-dev patterns we should use, and how should we proceed? This deck is one person's proposal. The point of the session is for the group to mark each item keep, change or drop.");
}

// 2. The question and the proposal
{
  const s = pres.addSlide();
  s.background = { color: C.white };
  title(s, "The question, and a proposal");
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.5, y: 1.4, w: 4.3, h: 3.4, fill: { color: C.soft },
  });
  s.addText("The question", {
    x: 0.75, y: 1.55, w: 3.8, h: 0.4, margin: 0,
    fontFace: HEAD, fontSize: 20, bold: true, color: C.mid,
  });
  s.addText("Identify, decide on and document the patterns of AI development the group should use. What is the starting point, and how do we proceed?", {
    x: 0.75, y: 2.05, w: 3.8, h: 2.5, margin: 0,
    fontFace: BODY, fontSize: 16, color: C.text, valign: "top",
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: 5.2, y: 1.4, w: 4.3, h: 3.4, fill: { color: C.ink },
  });
  s.addText("The proposal", {
    x: 5.45, y: 1.55, w: 3.8, h: 0.4, margin: 0,
    fontFace: HEAD, fontSize: 20, bold: true, color: C.accent,
  });
  s.addText("Don't start from a blank page. Start from aidev-toolkit, which already encodes a first cut. Review it, argue with it, and adopt or reject each piece.", {
    x: 5.45, y: 2.05, w: 3.8, h: 2.5, margin: 0,
    fontFace: BODY, fontSize: 16, color: C.white, valign: "top",
  });
  footer(s, 2);
}

// 3. Four areas
{
  const s = pres.addSlide();
  s.background = { color: C.white };
  title(s, "What the toolkit already covers");
  const cards = [
    ["1  Spec-driven development", "Every change starts as a spec with phases, tasks and test criteria. Nothing is done until validated by tests."],
    ["2  Architecture principles", "Seven principles, AP-001 to AP-007, checked against a codebase by /arch-review."],
    ["3  Standard workflow", "Commits, versioning, changelog, test runs and handoffs behave the same in every repo."],
    ["4  Guardrails", "No mocks in tests, a destructive-command guard, and skill verification before install."],
  ];
  cards.forEach(([h, b], i) => {
    const x = 0.5 + (i % 2) * 4.6;
    const y = 1.4 + Math.floor(i / 2) * 1.8;
    s.addShape(pres.shapes.RECTANGLE, {
      x, y, w: 4.4, h: 1.6, fill: { color: C.soft },
    });
    s.addText(h, {
      x: x + 0.2, y: y + 0.12, w: 4.0, h: 0.4, margin: 0,
      fontFace: HEAD, fontSize: 18, bold: true, color: C.ink,
    });
    s.addText(b, {
      x: x + 0.2, y: y + 0.58, w: 4.0, h: 0.95, margin: 0,
      fontFace: BODY, fontSize: 14, color: C.text, valign: "top",
    });
  });
  footer(s, 3);
}

// 4. Principles (decision table)
{
  const s = pres.addSlide();
  s.background = { color: C.white };
  title(s, "The seven principles: keep, change or drop?");
  const hdr = (t) => ({
    text: t,
    options: { bold: true, color: C.white, fill: { color: C.ink }, fontFace: BODY, fontSize: 13 },
  });
  const cell = (t, o = {}) => ({
    text: t,
    options: { fontFace: BODY, fontSize: 13, color: C.text, ...o },
  });
  const box = cell("☐ Keep   ☐ Change   ☐ Drop", { color: C.muted });
  const rows = [
    [hdr("ID"), hdr("Principle"), hdr("Category"), hdr("Decision")],
    ["AP-001", "Secure Development Practices", "security"],
    ["AP-002", "Observable Systems", "observability"],
    ["AP-003", "Intentional Error Handling", "reliability"],
    ["AP-004", "Test Critical Paths", "quality"],
    ["AP-005", "Runtime Security Patterns", "security"],
    ["AP-006", "Supply Chain Integrity", "security"],
    ["AP-007", "Runtime-Adjustable Observability", "observability"],
  ].map((r, i) =>
    i === 0 ? r : [cell(r[0], { bold: true }), cell(r[1]), cell(r[2]), box]
  );
  s.addTable(rows, {
    x: 0.5, y: 1.35, w: 9, colW: [0.9, 3.7, 1.6, 2.8],
    rowH: 0.42, border: { type: "solid", pt: 0.5, color: "C5D3D6" },
    valign: "middle",
  });
  footer(s, 4);
  s.addNotes("All seven are currently marked required. Part of the session is deciding whether that is right. Each one gets a mark in the Decision column.");
}

// 5. Workflow
{
  const s = pres.addSlide();
  s.background = { color: C.white };
  title(s, "Workflow: spec to shipped");
  const steps = [
    ["Spec", "/sdd-spec"],
    ["Build", "/sdd-code"],
    ["Validate", "/test-run"],
    ["Review", "/arch-review"],
    ["Ship", "/commit-push"],
  ];
  steps.forEach(([h, cmd], i) => {
    const x = 0.5 + i * 1.8;
    s.addShape(pres.shapes.OVAL, {
      x: x + 0.45, y: 1.5, w: 0.7, h: 0.7, fill: { color: C.ink },
    });
    s.addText(String(i + 1), {
      x: x + 0.45, y: 1.5, w: 0.7, h: 0.7, margin: 0, align: "center", valign: "middle",
      fontFace: HEAD, fontSize: 22, bold: true, color: C.accent,
    });
    s.addText(h, {
      x, y: 2.35, w: 1.6, h: 0.4, margin: 0, align: "center",
      fontFace: HEAD, fontSize: 18, bold: true, color: C.ink,
    });
    s.addText(cmd, {
      x, y: 2.75, w: 1.6, h: 0.35, margin: 0, align: "center",
      fontFace: "Courier New", fontSize: 12, color: C.mid,
    });
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.5, y: 3.5, w: 9, h: 1.4, fill: { color: C.soft },
  });
  s.addText([
    { text: "Definition of done: ", options: { bold: true } },
    { text: "a task is complete only when implemented and validated by tests. If validation is blocked, it is In Progress, not Complete. Handoffs (/handoff, /continue) carry work across sessions." },
  ], {
    x: 0.75, y: 3.6, w: 8.5, h: 1.2, margin: 0,
    fontFace: BODY, fontSize: 15, color: C.text, valign: "middle",
  });
  footer(s, 5);
}

// 6. Guardrails
{
  const s = pres.addSlide();
  s.background = { color: C.white };
  title(s, "Guardrails");
  const items = [
    ["No mocks in tests", "Use real implementations, fixtures and integration tests. Missing dependency means blocked, not faked."],
    ["Destructive-command guard", "Blocks risky shell commands before they run. The guard stays rigid; narrowing it must not create a bypass."],
    ["Skill verification", "/should-i-trust-it checks skill files for malicious patterns before install."],
  ];
  items.forEach(([h, b], i) => {
    const y = 1.4 + i * 1.15;
    s.addShape(pres.shapes.OVAL, {
      x: 0.5, y: y + 0.1, w: 0.6, h: 0.6, fill: { color: C.ink },
    });
    s.addText("✓", {
      x: 0.5, y: y + 0.1, w: 0.6, h: 0.6, margin: 0, align: "center", valign: "middle",
      fontFace: BODY, fontSize: 20, bold: true, color: C.accent,
    });
    s.addText(h, {
      x: 1.35, y, w: 8.1, h: 0.4, margin: 0,
      fontFace: HEAD, fontSize: 20, bold: true, color: C.ink,
    });
    s.addText(b, {
      x: 1.35, y: y + 0.42, w: 8.1, h: 0.6, margin: 0, valign: "top",
      fontFace: BODY, fontSize: 15, color: C.text,
    });
  });
  footer(s, 6);
}

// 7. Gaps
{
  const s = pres.addSlide();
  s.background = { color: C.ink };
  title(s, "Gaps the group needs to decide", true);
  const gaps = [
    "Prompt and skill authoring conventions",
    "Model selection and cost guidance",
    "Data-handling rules for client code",
    "Review expectations for AI-generated code",
    "How teams contribute back",
  ];
  gaps.forEach((g, i) => {
    const y = 1.4 + i * 0.62;
    s.addText(String(i + 1), {
      x: 0.5, y, w: 0.5, h: 0.5, margin: 0, valign: "middle",
      fontFace: HEAD, fontSize: 26, bold: true, color: C.accent,
    });
    s.addText(g, {
      x: 1.15, y, w: 6.0, h: 0.5, margin: 0, valign: "middle",
      fontFace: BODY, fontSize: 20, color: C.white,
    });
    s.addText("Owner: ______   Status: ______", {
      x: 6.6, y, w: 2.9, h: 0.5, margin: 0, valign: "middle",
      fontFace: BODY, fontSize: 12, color: "9DB8BC",
    });
  });
  footer(s, 7, true);
  s.addNotes("Each gap needs an owner and a status: drafted, deferred or rejected. Which one comes first is an open question for the group.");
}

// 8. Session plan
{
  const s = pres.addSlide();
  s.background = { color: C.white };
  title(s, "Proposed 60-minute session");
  const rows = [
    ["0–10", "Frame", "Agree who decides and how decisions are recorded"],
    ["10–35", "Walk the principles", "Mark each of AP-001 to AP-007 keep, change or drop"],
    ["35–45", "Workflow and guardrails", "Same pass over the workflow commands and guardrails"],
    ["45–55", "Gaps", "Assign an owner and a status to each of the five gaps"],
    ["55–60", "Wrap up", "Agree the format and home of the published standard"],
  ];
  rows.forEach(([t, h, b], i) => {
    const y = 1.35 + i * 0.72;
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0.5, y, w: 1.3, h: 0.58, fill: { color: C.ink },
    });
    s.addText(t + " min", {
      x: 0.5, y, w: 1.3, h: 0.58, margin: 0, align: "center", valign: "middle",
      fontFace: BODY, fontSize: 14, bold: true, color: C.white,
    });
    s.addText(h, {
      x: 2.0, y, w: 2.6, h: 0.58, margin: 0, valign: "middle",
      fontFace: HEAD, fontSize: 16, bold: true, color: C.ink,
    });
    s.addText(b, {
      x: 4.65, y, w: 4.85, h: 0.58, margin: 0, valign: "middle",
      fontFace: BODY, fontSize: 14, color: C.text,
    });
  });
  footer(s, 8);
}

// 9. Decisions needed
{
  const s = pres.addSlide();
  s.background = { color: C.white };
  title(s, "Decisions we need from the group");
  const qs = [
    "Who decides what goes into the standard: one person, a small group, or consensus?",
    "What format and home: extend architecture-principles with /arch-review checks, a standalone document, or a shared wiki?",
    "Is aidev-toolkit accepted as the starting point, or should we also look at other sources?",
    "Which of the five gaps comes first?",
  ];
  s.addText(
    qs.map((q, i) => ({
      text: q,
      options: { bullet: { type: "number" }, breakLine: i < qs.length - 1, paraSpaceAfter: 10 },
    })),
    {
      x: 0.5, y: 1.4, w: 9, h: 3.5, margin: 0, valign: "top",
      fontFace: BODY, fontSize: 18, color: C.text,
    }
  );
  footer(s, 9);
}

// 10. Close
{
  const s = pres.addSlide();
  s.background = { color: C.ink };
  s.addText("Next step", {
    x: 0.7, y: 1.6, w: 8.6, h: 0.9, margin: 0,
    fontFace: HEAD, fontSize: 44, bold: true, color: C.white,
  });
  s.addText("Agree the session, then mark every item keep, change or drop. Anything that changes toolkit behavior becomes its own spec.", {
    x: 0.7, y: 2.7, w: 8.6, h: 1.2, margin: 0, valign: "top",
    fontFace: BODY, fontSize: 20, color: C.accent,
  });
}

pres.writeFile({ fileName: OUT }).then((f) => console.log("wrote " + f));
