import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { isAbsolute, relative, resolve, sep } from "node:path";

// Single-line footer: pwd + stats + model in one line, via pi config
// Auto-discovered at ~/.pi/agent/extensions/
function formatCwdForFooter(cwd: string, home?: string): string {
  if (!home) return cwd;
  const rcwd = resolve(cwd);
  const rhome = resolve(home);
  const rel = relative(rhome, rcwd);
  const inside = rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel));
  if (!inside) return cwd;
  return rel === "" ? "~" : `~${sep}${rel}`;
}

function formatTokens(n: number): string {
  if (n < 1000) return `${n}`;
  if (n < 10000) return `${(n / 1000).toFixed(1)}k`;
  if (n < 1000000) return `${Math.round(n / 1000)}k`;
  if (n < 10000000) return `${(n / 1000000).toFixed(1)}M`;
  return `${Math.round(n / 1000000)}M`;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());
      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          // -- pwd (left part) --
          let pwd = formatCwdForFooter(
            ctx.sessionManager.getCwd(),
            process.env.HOME || process.env.USERPROFILE,
          );
          const branch = footerData.getGitBranch();
          if (branch) pwd += ` (${branch})`;
          const name = ctx.sessionManager.getSessionName();
          if (name) pwd += ` • ${name}`;

          // -- stats (from Footer's usageTotals + context) --
          let input = 0, output = 0, cacheRead = 0, cacheWrite = 0, cost = 0;
          for (const e of ctx.sessionManager.getEntries() as any[]) {
            if (e.type === "message" && e.message?.role === "assistant" && e.message?.usage) {
              const u = e.message.usage;
              input += u.input ?? 0;
              output += u.output ?? 0;
              cacheRead += u.cacheRead ?? 0;
              cacheWrite += u.cacheWrite ?? 0;
              cost += u.cost?.total ?? 0;
            } else if (e.type === "message" && e.message?.role === "toolResult" && e.message?.usage) {
              const u = e.message.usage;
              input += u.input ?? 0;
              output += u.output ?? 0;
              cacheRead += u.cacheRead ?? 0;
              cacheWrite += u.cacheWrite ?? 0;
              cost += u.cost?.total ?? 0;
            } else if ((e.type === "branch_summary" || e.type === "compaction") && (e as any).usage) {
              const u = (e as any).usage;
              input += u.input ?? 0;
              output += u.output ?? 0;
              cacheRead += u.cacheRead ?? 0;
              cacheWrite += u.cacheWrite ?? 0;
              cost += u.cost?.total ?? 0;
            }
          }
          const usage = ctx.getContextUsage();
          const pctVal = usage?.percent ?? 0;
          // Fresh session returns percent: 0 (a real number) — meaningless until the
          // first LLM response, so treat zero tokens as unknown like the null case.
          const pctIsKnown = usage?.percent !== null && usage?.percent !== undefined && (usage.tokens ?? 0) > 0;
          const parts: string[] = [];
          if (input) parts.push(` ${formatTokens(input)}`);
          if (output) parts.push(` ${formatTokens(output)}`);
          if (cacheRead) parts.push(` ${formatTokens(cacheRead)}`);
          if (cacheWrite) parts.push(` ${formatTokens(cacheWrite)}`);
          if (cost) parts.push(`${cost.toFixed(3)}`);
          if (pctIsKnown) {
            const ctxDisp = (pctVal > 90 ? theme.fg("error", ` ${pctVal.toFixed(0)}%`) : pctVal > 70 ? theme.fg("warning", ` ${pctVal.toFixed(0)}%`) : theme.fg("dim", ` ${pctVal.toFixed(0)}%`)) as string;
            parts.push(ctxDisp);
          }
          let statsLeft = parts.join(" ");

          // Keep the path left-aligned and all usage metrics right-aligned.
          let leftPlain = pwd;
          let rightPlain = statsLeft;
          const minGap = 2;
          const maxRightW = Math.max(0, width - visibleWidth(leftPlain) - minGap);
          if (visibleWidth(rightPlain) > maxRightW) {
            rightPlain = truncateToWidth(rightPlain, maxRightW, "...");
          }
          const leftRendered = theme.fg("dim", leftPlain) as string;
          const rightRendered = theme.fg("dim", rightPlain) as string;
          const gap = " ".repeat(Math.max(minGap, width - visibleWidth(leftRendered) - visibleWidth(rightRendered)));
          return [truncateToWidth(leftRendered + gap + rightRendered, width, theme.fg("dim", "...") as string)];
        },
      };
    });
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    try { ctx.ui.setFooter(undefined); } catch {}
  });
}
