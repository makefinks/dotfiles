import type {
	ExtensionAPI,
	Theme,
} from "@earendil-works/pi-coding-agent";
import {
	fuzzyFilter,
	Input,
	isKeyRelease,
	Key,
	matchesKey,
	SelectList,
	type SelectItem,
	truncateToWidth,
	visibleWidth,
	type Focusable,
} from "@earendil-works/pi-tui";
import { basename, dirname } from "node:path";

const MAX_RESULTS = 200;
const MAX_VISIBLE = 12;

async function listFiles(pi: ExtensionAPI, cwd: string): Promise<string[]> {
	const gitFiles = await pi.exec(
		"git",
		["ls-files", "--cached", "--others", "--exclude-standard"],
		{ cwd, timeout: 10_000 },
	);

	const output =
		gitFiles.code === 0
			? gitFiles.stdout
			: (
					await pi.exec(
						"fd",
						["--type", "f", "--hidden", "--exclude", ".git", ".", "."],
						{ cwd, timeout: 10_000 },
					)
				).stdout;

	return [...new Set(output.split("\n").map((path) => path.trim()).filter(Boolean))].sort(
		(a, b) => a.localeCompare(b),
	);
}

function fileReference(path: string): string {
	return path.includes(" ") ? `@"${path}" ` : `@${path} `;
}

class FilePicker implements Focusable {
	private readonly input = new Input();
	private list: SelectList;
	private _focused = false;

	constructor(
		private readonly paths: string[],
		private readonly theme: Theme,
		private readonly requestRender: () => void,
		private readonly done: (path: string | undefined) => void,
	) {
		this.list = this.createList(this.paths.slice(0, MAX_RESULTS));
	}

	get focused(): boolean {
		return this._focused;
	}

	set focused(value: boolean) {
		this._focused = value;
		this.input.focused = value;
	}

	private createList(paths: string[]): SelectList {
		const items: SelectItem[] = paths.map((path) => ({
			value: path,
			label: basename(path),
			description: dirname(path) === "." ? undefined : dirname(path),
		}));
		const list = new SelectList(items, MAX_VISIBLE, {
			selectedPrefix: (text) => this.theme.fg("accent", text),
			selectedText: (text) => {
				const marked = text.replace(/^→ /, "▌ ");
				return this.theme.bg(
					"selectedBg",
					this.theme.fg("accent", this.theme.bold(marked)),
				);
			},
			description: (text) => this.theme.fg("muted", text),
			scrollInfo: (text) => this.theme.fg("dim", text),
			noMatch: (text) => this.theme.fg("warning", text),
		});
		list.onSelect = (item) => this.done(item.value);
		list.onCancel = () => this.done(undefined);
		return list;
	}

	private updateResults(): void {
		const query = this.input.getValue().trim();
		const matches = query
			? fuzzyFilter(this.paths, query, (path) => path)
			: this.paths;
		this.list = this.createList(matches.slice(0, MAX_RESULTS));
	}

	handleInput(data: string): void {
		if (matchesKey(data, Key.escape)) {
			this.done(undefined);
			return;
		}

		const moveUp = matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p"));
		const moveDown = matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n"));
		if (moveUp || moveDown || matchesKey(data, Key.enter)) {
			// SelectList follows Pi's configured arrow bindings. Translate the
			// Emacs-style navigation keys so they work regardless of that config.
			this.list.handleInput(moveUp ? "\x1b[A" : moveDown ? "\x1b[B" : data);
		} else {
			const previousQuery = this.input.getValue();
			this.input.handleInput(data);
			if (this.input.getValue() !== previousQuery) this.updateResults();
		}

		this.requestRender();
	}

	private row(content: string, innerWidth: number): string {
		const clipped = truncateToWidth(content, innerWidth, "");
		const padding = " ".repeat(Math.max(0, innerWidth - visibleWidth(clipped)));
		return (
			this.theme.fg("border", "│") +
			clipped +
			padding +
			this.theme.fg("border", "│")
		);
	}

	render(width: number): string[] {
		const innerWidth = Math.max(1, width - 2);
		const inputWidth = Math.max(1, innerWidth - 10);
		const inputLine = this.input.render(inputWidth)[0] ?? "";
		const listLines = this.list.render(Math.max(1, innerWidth - 2));
		const lines = [
			this.theme.fg("border", `╭${"─".repeat(innerWidth)}╮`),
			this.row(` ${this.theme.fg("accent", this.theme.bold("File picker"))}`, innerWidth),
			this.row(` ${this.theme.fg("muted", "Search:")} ${inputLine}`, innerWidth),
			this.theme.fg("border", `├${"─".repeat(innerWidth)}┤`),
		];

		for (const line of listLines) lines.push(this.row(` ${line}`, innerWidth));
		for (let index = listLines.length; index < MAX_VISIBLE + 1; index += 1) {
			lines.push(this.row("", innerWidth));
		}

		lines.push(
			this.theme.fg("border", `├${"─".repeat(innerWidth)}┤`),
			this.row(
				` ${this.theme.fg("dim", "Type to filter • ↑↓/Ctrl+P/N navigate • Enter select • Esc close")}`,
				innerWidth,
			),
			this.theme.fg("border", `╰${"─".repeat(innerWidth)}╯`),
		);
		return lines;
	}

	invalidate(): void {
		this.input.invalidate();
		this.list.invalidate();
	}
}

export default function (pi: ExtensionAPI): void {
	let unsubscribe: (() => void) | undefined;
	let pickerOpen = false;
	let enabled = true;

	pi.registerCommand("file-picker-toggle", {
		description: "Toggle the @ file-picker popup",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			ctx.ui.notify(
				`File-picker popup ${enabled ? "enabled" : "disabled"}`,
				"info",
			);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		const paths = await listFiles(pi, ctx.cwd);
		unsubscribe?.();
		unsubscribe = ctx.ui.onTerminalInput((data) => {
			if (
				!enabled ||
				pickerOpen ||
				isKeyRelease(data) ||
				!matchesKey(data, Key.at)
			) {
				return undefined;
			}

			pickerOpen = true;
			void ctx.ui
				.custom<string | undefined>(
					(tui, theme, _keybindings, done) =>
						new FilePicker(paths, theme, () => tui.requestRender(), done),
					{
						overlay: true,
						overlayOptions: {
							anchor: "center",
							width: "70%",
							minWidth: 50,
							maxHeight: "80%",
							margin: 1,
						},
					},
				)
				.then((path) => {
					if (path) ctx.ui.pasteToEditor(fileReference(path));
				})
				.catch((error: unknown) => {
					const message = error instanceof Error ? error.message : String(error);
					ctx.ui.notify(`File picker failed: ${message}`, "error");
				})
				.finally(() => {
					pickerOpen = false;
				});

			return { consume: true };
		});
	});

	pi.on("session_shutdown", () => {
		unsubscribe?.();
		unsubscribe = undefined;
		pickerOpen = false;
	});
}
