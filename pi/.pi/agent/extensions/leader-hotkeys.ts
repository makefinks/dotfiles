import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isKeyRelease, matchesKey } from "@earendil-works/pi-tui";

const LEADER = "ctrl+x";

// Forward leader actions as the shortcuts already configured in keybindings.json.
// Using a terminal-input listener lets this coexist with extensions such as
// pi-powerline-footer that install their own custom editor.
export default function (pi: ExtensionAPI) {
	let unsubscribe: (() => void) | undefined;
	let leaderActive = false;

	const clearLeader = (ctx: any) => {
		leaderActive = false;
		ctx.ui.setStatus("leader-hotkeys", undefined);
	};

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		unsubscribe?.();
		unsubscribe = ctx.ui.onTerminalInput((data) => {
			// Enhanced keyboard protocols report key releases separately. A Ctrl+X
			// release must not count as the next key and cancel leader mode.
			if (isKeyRelease(data)) return undefined;

			if (leaderActive) {
				clearLeader(ctx);

				if (matchesKey(data, "escape")) return { consume: true };

				if (matchesKey(data, "m")) {
					// Forward the private F12 bridge to Pi's native model picker.
					return { data: "\x1b[24~" };
				}
				if (matchesKey(data, "l")) {
					// Forward the private Ctrl+Q bridge bound to the session picker.
					return { data: "\x11" };
				}

				// Unknown sequences are cancelled, while preserving the second key.
				return { data };
			}

			if (!matchesKey(data, LEADER)) return undefined;

			leaderActive = true;
			ctx.ui.setStatus(
				"leader-hotkeys",
				ctx.ui.theme.fg("accent", "Leader active: [m] Models  [l] Sessions  [Esc] Cancel"),
			);
			return { consume: true };
		});
	});

	pi.on("session_shutdown", (_event, ctx) => {
		unsubscribe?.();
		unsubscribe = undefined;
		if (ctx.hasUI) clearLeader(ctx);
	});
}
