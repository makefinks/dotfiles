import { CustomEditor, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// Hide the bottom border line of the input editor while keeping the
// top border + footer top line (pwd/branch) visible.
// Config-driven: auto-discovered via ~/.pi/agent/extensions/
function stripAnsi(s: string): string {
  return s
    .replace(/\x1b\[[0-9;]*m/g, "")
    .replace(/\x1b\]8;;.*?\x1b\\/g, "")
    .replace(/\x07/g, "");
}

function isBorderLine(line: string): boolean {
  const t = stripAnsi(line).trim();
  if (!t) return false;
  // Plain horizontal border: ───...
  if (/^─+$/.test(t)) return true;
  // Scroll indicators: ─── ↑ 2 more ───  /  ─── ↓ 5 more ───
  if (t.includes("more") && t.includes("─")) return true;
  return false;
}

type RGB = readonly [number, number, number];

const BLUE_FILL: RGB = [90, 175, 245];

function parseAnsiRgb(ansi: string, fallback: RGB): RGB {
  const match = ansi.match(/\x1b\[38;2;(\d+);(\d+);(\d+)m/);
  return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : fallback;
}

function mixRgb(from: RGB, to: RGB, amount: number): RGB {
  return [
    Math.round(from[0] + (to[0] - from[0]) * amount),
    Math.round(from[1] + (to[1] - from[1]) * amount),
    Math.round(from[2] + (to[2] - from[2]) * amount),
  ];
}

function colorRgb([r, g, b]: RGB, text: string): string {
  return `\x1b[38;2;${r};${g};${b}m${text}\x1b[39m`;
}

function paintProgress(
  text: string,
  offset: number,
  end: number,
  active: (text: string) => string,
  base: (text: string) => string,
): string {
  const chars = [...stripAnsi(text)];
  const activeLength = Math.max(0, Math.min(chars.length, Math.floor(end - offset)));
  return active(chars.slice(0, activeLength).join("")) + base(chars.slice(activeLength).join(""));
}

function fitTopBorder(
  left: string,
  right: string,
  width: number,
  theme: Pick<Theme, "fg" | "getFgAnsi">,
  fillProgress?: number,
): string {
  if (width <= 0) return "";
  if (width === 1) return theme.fg("dim", "─");

  const minimumGap = right ? 3 : 0;
  while (visibleWidth(left) + visibleWidth(right) + minimumGap > width && right) {
    right = truncateToWidth(right, Math.max(0, visibleWidth(right) - 1), "");
  }
  while (visibleWidth(left) + visibleWidth(right) + minimumGap > width && left) {
    left = truncateToWidth(left, Math.max(0, visibleWidth(left) - 1), "");
  }

  const fillWidth = Math.max(0, width - visibleWidth(left) - visibleWidth(right));
  const fill = "─".repeat(fillWidth);
  if (fillProgress !== undefined) {
    const fade = fillProgress <= 1 ? 1 : Math.max(0, 1 - (fillProgress - 1));
    if (fade === 0) {
      return theme.fg("accent", left) + theme.fg("dim", fill) + theme.fg("muted", right);
    }

    const amount = 1 - fade;
    const accent = parseAnsiRgb(theme.getFgAnsi("accent"), [138, 190, 183]);
    const dim = parseAnsiRgb(theme.getFgAnsi("dim"), [102, 102, 102]);
    const muted = parseAnsiRgb(theme.getFgAnsi("muted"), [128, 128, 128]);
    const activeFor = (base: RGB) => (text: string): string =>
      colorRgb(mixRgb(BLUE_FILL, base, amount), text);
    const leftWidth = visibleWidth(left);
    const rightStart = leftWidth + fillWidth;
    const end = Math.min(width, Math.floor(Math.min(1, fillProgress) * width));
    return (
      paintProgress(left, 0, end, activeFor(accent), (text) => theme.fg("accent", text)) +
      paintProgress(fill, leftWidth, end, activeFor(dim), (text) => theme.fg("dim", text)) +
      paintProgress(right, rightStart, end, activeFor(muted), (text) => theme.fg("muted", text))
    );
  }
  return theme.fg("accent", left) + theme.fg("dim", fill) + theme.fg("muted", right);
}

const FILL_DURATION_MS = 500;
const FILL_FADE_DURATION_MS = 1500;

const BLUE: readonly (readonly [number, number, number])[] = [
  [45, 90, 170],
  [70, 135, 220],
  [110, 185, 250],
  [190, 235, 255],
] as const;

function scaleBlue(t: number): RGB {
  const clamped = Math.max(0, Math.min(1, t));
  const seg = clamped * (BLUE.length - 1);
  const i = Math.min(BLUE.length - 2, Math.floor(seg));
  const [r1, g1, b1] = BLUE[i]!;
  const [r2, g2, b2] = BLUE[i + 1]!;
  const f = seg - i;
  return [Math.round(r1 + (r2 - r1) * f), Math.round(g1 + (g2 - g1) * f), Math.round(b1 + (b2 - b1) * f)];
}

function pingpong(f: number, length: number): number {
  const cycle = Math.max(1, length * 2 - 2);
  const p = ((f % cycle) + cycle) % cycle;
  return p < length ? p : cycle - p;
}

// 10 looping variants, same blues as the site demo. Each maps (index, t) to 0..1 brightness.
function variantBrightness(variant: number, i: number, n: number, t: number): number {
  switch (variant % 10) {
    case 0: return 1 - Math.min(1, Math.abs(i - pingpong(t, n)) / 3);
    case 1: return 1 - Math.min(Math.abs(i - pingpong(t, n)), Math.abs(i - pingpong(t + 7.3, n))) / 3;
    case 2: return 0.5 + 0.5 * Math.sin(i * 0.9 - t * 0.25);
    case 3: return 0.55 + 0.45 * Math.sin(t * 0.12);
    case 4: { const p = ((t * 0.35) % (n + 6)) - 3; return Math.max(0, 1 - Math.abs(i - p) / 1.6); }
    case 5: return 0.5 + 0.5 * Math.sin(i * 1.1 - t * 0.3);
    case 6: { const track = n + 12; // margins let the head fly out of bounds
      const h = (((t * 0.6) % track) + track) % track - 6;
      const tr = h - i; // >= 0 behind the head (always travels left to right)
      return tr >= 0 ? Math.max(0, 1 - tr / 5) : Math.max(0, 1 + tr / 1.2); }
    case 7: { const ph = (t * 0.09) % 1.6; return ph < 0.12 ? 1 : ph < 0.24 ? 0.35 : ph < 0.36 ? 0.9 : 0.25; }
    case 8: { const r = Math.sin(i * 127.1 + Math.floor(t / 4) * 311.7) * 43758.5; return r - Math.floor(r) > 0.82 ? 1 : 0.18; }
    default: return 1 - Math.min(Math.abs(i - pingpong(t * 0.7, n)), Math.abs(i - pingpong(-t * 1.1 + 5, n))) / 2.4;
  }
}

function shimmerText(text: string, frame: number, baseColor: string, variant = 0, phase = 0): string {
  const chars = [...text];
  const t = frame * 1.7 + phase;
  const rendered = chars.map((char, index) => {
    const [r, g, b] = scaleBlue(variantBrightness(variant, index, chars.length, t));
    return `\x1b[38;2;${r};${g};${b}m${char}`;
  }).join("");
  return `${rendered}\x1b[39m${baseColor}`;
}

export default function (pi: ExtensionAPI) {
  let extensionStatuses: ReadonlyMap<string, string> = new Map();
  let spinnerFrame = 0;
  let headOffset = 0;
  let runCount = 0;
  let wasStreaming = false;
  let finishFillStartedAt: number | undefined;
  let requestRender = () => {};
  let spinnerTimer: ReturnType<typeof setInterval> | undefined;

  pi.on("session_start", async (_event, ctx) => {
    // Replace the verbose working row with a subtle KITT-style model-name shimmer.
    ctx.ui.setWorkingVisible(false);
    wasStreaming = false;
    finishFillStartedAt = undefined;
    spinnerTimer = setInterval(() => {
      const streaming = !ctx.isIdle();
      const now = Date.now();
      if (streaming && !wasStreaming) { headOffset = Math.floor(Math.random() * 1000); runCount++; }
      if (wasStreaming && !streaming) finishFillStartedAt = now;
      wasStreaming = streaming;
      if (
        finishFillStartedAt !== undefined &&
        now - finishFillStartedAt > FILL_DURATION_MS + FILL_FADE_DURATION_MS + 120
      ) {
        finishFillStartedAt = undefined;
      }
      if (streaming || finishFillStartedAt !== undefined) {
        spinnerFrame++;
        requestRender();
      }
    }, 80);

    // Capture the live status map; single-line-footer replaces this temporary
    // capture footer later in startup.
    ctx.ui.setFooter((_tui, _theme, footerData) => {
      extensionStatuses = footerData.getExtensionStatuses();
      return { render: () => [], invalidate() {} };
    });

    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      requestRender = () => tui.requestRender();
      const editor = new CustomEditor(tui, theme, keybindings, { paddingX: 0 });
      const origRender = editor.render.bind(editor);
      editor.render = (width: number): string[] => {
        const prompt = "❯ ";
        const promptWidth = visibleWidth(prompt);
        const renderWidth = Math.max(1, width - promptWidth);
        const lines = origRender(renderWidth).map((line, index) => {
          const prefixed = index === 1 ? prompt + line : line;
          return prefixed + " ".repeat(Math.max(0, width - visibleWidth(prefixed)));
        });
        if (lines.length <= 1) return lines;
        // Find bottom border index in original to split content vs autocomplete
        let bordersSeenOrig = 0;
        let bottomIdx = -1;
        for (let i = 0; i < lines.length; i++) {
          if (isBorderLine(lines[i]!)) {
            bordersSeenOrig++;
            if (bordersSeenOrig === 2) {
              bottomIdx = i;
              break;
            }
          }
        }
        const contentLen = bottomIdx >= 0 ? bottomIdx - 1 : -1;
        const hasBottom = bottomIdx >= 0;
        // Keep top, drop bottom, keep autocomplete
        let bordersSeen = 0;
        const out: string[] = [];
        for (const line of lines) {
          if (isBorderLine(line)) {
            bordersSeen++;
            if (bordersSeen === 1) out.push(line);
            else if (bordersSeen === 2) continue;
            else out.push(line);
          } else {
            out.push(line);
          }
        }
        // Replace top border with model label at very left (overlapping border)
        if (out.length > 0 && isBorderLine(out[0]!)) {
          const t = stripAnsi(out[0]!).trim();
          const isScroll = t.includes("more");
          if (!isScroll) {
            const uiTheme = ctx.ui.theme;
            const model: any = (ctx as any).model;
            const modelName = model?.id ?? "no-model";
            const animated = !ctx.isIdle();
            const displayName = animated
              ? shimmerText(modelName, spinnerFrame, uiTheme.getFgAnsi("accent"), 6, headOffset)
              : modelName;
            let label = displayName;
            if (model?.reasoning) {
              const lvl = (ctx as any).thinkingLevel ?? "off";
              label += lvl === "off" ? " • thinking off" : ` • ${lvl}`;
            }
            const usage = extensionStatuses.get("usage")?.replace(/[\r\n\t]/g, " ").trim();
            const fillProgress = finishFillStartedAt === undefined
              ? undefined
              : (() => {
                  const elapsed = Date.now() - finishFillStartedAt;
                  if (elapsed <= FILL_DURATION_MS) return elapsed / FILL_DURATION_MS;
                  return 1 + Math.min(1, (elapsed - FILL_DURATION_MS) / FILL_FADE_DURATION_MS);
                })();
            out[0] = fitTopBorder(` ${label} `, usage ? ` ${usage} ` : "", width, uiTheme, fillProgress);
          }
          out.splice(1, 0, " ".repeat(width));
        }
        // One blank line padding below last input row (before autocomplete/footer)
        const blank = " ".repeat(width);
        if (hasBottom && contentLen >= 0) {
          // contentLen = original content lines count
          // out = [top, blankTop, ...content, ...autocomplete]
          // insert after content: index = 1 (top) +1 (blankTop) + contentLen
          const insertAt = 2 + contentLen;
          out.splice(Math.min(insertAt, out.length), 0, blank);
        } else {
          // fallback: just before end (or before autocomplete if we can guess)
          out.push(blank);
        }
        return out;
      };
      return editor;
    });
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (spinnerTimer) clearInterval(spinnerTimer);
    spinnerTimer = undefined;
    wasStreaming = false;
    finishFillStartedAt = undefined;
    requestRender = () => {};
    // restore default editor on shutdown/reload
    try {
      ctx.ui.setEditorComponent(undefined);
    } catch {}
  });
}
