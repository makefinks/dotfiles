// Carry the last-used model and reasoning effort across restarts and /new:
// changes in a chat are remembered, so the next fresh chat does not use settings.json.
// Auto-discovered at ~/.pi/agent/extensions/
import { readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STATE_FILE = join(homedir(), ".pi", "agent", "keep-last-model.json");

export default function (pi: ExtensionAPI) {
	async function save(
		provider: string,
		id: string,
		thinkingLevel: ReturnType<ExtensionAPI["getThinkingLevel"]>,
	) {
		try {
			await writeFile(STATE_FILE, JSON.stringify({ provider, id, thinkingLevel }));
		} catch {
			// non-fatal: next model or reasoning change retries
		}
	}

	pi.on("model_select", (event) =>
		save(event.model.provider, event.model.id, pi.getThinkingLevel()),
	);
	pi.on("thinking_level_select", (event, ctx) => {
		if (ctx.model) return save(ctx.model.provider, ctx.model.id, event.level);
	});

	// Fresh startup and /new use the recorded model. Resume/fork restore their
	// own model, and reload keeps the active model.
	pi.on("session_start", async (event, ctx) => {
		if (event.reason === "reload") {
			if (ctx.model) await save(ctx.model.provider, ctx.model.id, ctx.thinkingLevel);
			return;
		}
		if (event.reason !== "startup" && event.reason !== "new") return;
		try {
			const { provider, id, thinkingLevel } = JSON.parse(
				await readFile(STATE_FILE, "utf8"),
			);
			const model = ctx.modelRegistry.find(provider, id);
			if (!model) return;
			const ok = await pi.setModel(model);
			if (!ok) {
				ctx.ui.notify(`No auth for last model ${provider}/${id}`, "warning");
				return;
			}
			if (thinkingLevel) pi.setThinkingLevel(thinkingLevel);
		} catch {
			// no state file yet — first run keeps the settings default
		}
	});
}
