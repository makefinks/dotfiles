import type {
	ExtensionAPI,
	ExtensionContext,
	KeybindingsManager,
} from "@earendil-works/pi-coding-agent";
import type { EditorComponent, EditorTheme, TUI } from "@earendil-works/pi-tui";

const WRAPPER_MARKER = Symbol.for("reasoning-animation.editor-wrapper");
const WRAPPER_BASE = Symbol.for("reasoning-animation.editor-base");
const LEVELS = new Set(["high", "xhigh", "max"]);
const FRAME_COUNTS: Record<string, number> = { high: 20, xhigh: 38, max: 24 };
const FRAME_INTERVAL_MS = 60;

type Rgb = readonly [red: number, green: number, blue: number];

const BLUE_DARK: Rgb = [35, 70, 175];
const BLUE_BRIGHT: Rgb = [80, 205, 255];
const MAX_PALETTE: readonly Rgb[] = [
	[255, 65, 95],
	[255, 190, 45],
	[35, 225, 210],
	[70, 125, 255],
	[205, 70, 255],
];

type EditorFactory = NonNullable<Parameters<ExtensionContext["ui"]["setEditorComponent"]>[0]>;
type MarkedFactory = EditorFactory & Record<symbol, unknown>;

function stripAnsi(value: string): string {
	return value.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "");
}

function mixColor(from: Rgb, to: Rgb, amount: number): Rgb {
	return from.map((channel, index) =>
		Math.round(channel + ((to[index] ?? channel) - channel) * amount),
	) as unknown as Rgb;
}

function gradientColor(palette: readonly Rgb[], position: number): Rgb {
	const wrapped = ((position % 1) + 1) % 1;
	const scaled = wrapped * palette.length;
	const index = Math.floor(scaled);
	return mixColor(
		palette[index % palette.length] ?? [255, 255, 255],
		palette[(index + 1) % palette.length] ?? [255, 255, 255],
		scaled - index,
	);
}

function renderBlueSweep(level: string, frameIndex: number): string {
	const frameCount = FRAME_COUNTS[level] ?? 20;
	const progress = frameIndex / Math.max(1, frameCount - 1);
	const directionProgress =
		level === "xhigh" ? (progress <= 0.5 ? progress * 2 : (1 - progress) * 2) : progress;
	const hotspot = -0.35 + directionProgress * 1.7;

	return [...level]
		.map((character, index) => {
			const position = index / Math.max(1, level.length - 1);
			const brightness = Math.max(0, 1 - Math.abs(position - hotspot) * 2.5);
			const [red, green, blue] = mixColor(BLUE_DARK, BLUE_BRIGHT, brightness);
			return `\x1b[38;2;${red};${green};${blue}m${character}`;
		})
		.join("");
}

function renderMaxSweep(frameIndex: number): string {
	const frameCount = FRAME_COUNTS.max ?? 24;
	const progress = frameIndex / Math.max(1, frameCount - 1);

	return [..."max"]
		.map((character, index) => {
			const position = index / 2 - progress;
			const [red, green, blue] = gradientColor(MAX_PALETTE, position);
			return `\x1b[38;2;${red};${green};${blue}m${character}`;
		})
		.join("");
}

function renderGradientFrame(level: string, frameIndex: number): string {
	return level === "max" ? renderMaxSweep(frameIndex) : renderBlueSweep(level, frameIndex);
}

function replaceReasoningToken(lines: string[], level: string, frame: string): string[] {
	for (let index = lines.length - 1; index >= 0; index--) {
		const line = lines[index];
		if (!line || !stripAnsi(line).match(new RegExp(`(^|\\s)${level}(?=\\s|$)`))) continue;

		const tokenIndex = line.indexOf(level);
		if (tokenIndex < 0) continue;

		return [
			...lines.slice(0, index),
			`${line.slice(0, tokenIndex)}${frame}${line.slice(tokenIndex + level.length)}`,
			...lines.slice(index + 1),
		];
	}

	return lines;
}

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setTimeout> | undefined;
	let editorFactory: EditorFactory | undefined;
	let baseEditorFactory: EditorFactory | undefined;
	let requestEditorRender: (() => void) | undefined;
	let activeLevel: string | undefined;
	let activeFrame: string | undefined;
	let animationId = 0;

	const stopAnimation = () => {
		animationId++;
		if (timer) clearTimeout(timer);
		timer = undefined;
		activeLevel = undefined;
		activeFrame = undefined;
	};

	const wrapEditor = (ctx: ExtensionContext) => {
		const currentFactory = ctx.ui.getEditorComponent();
		if (!currentFactory || currentFactory === editorFactory) return;

		const markedFactory = currentFactory as MarkedFactory;
		const baseFactory = markedFactory[WRAPPER_MARKER]
			? (markedFactory[WRAPPER_BASE] as EditorFactory | undefined) ?? currentFactory
			: currentFactory;
		const wrappedFactory = ((tui: TUI, theme: EditorTheme, keybindings: KeybindingsManager) => {
			requestEditorRender = () => tui.requestRender();
			const base = baseFactory(tui, theme, keybindings);
			const editor = new Proxy(base as EditorComponent, {
				get(target, property, receiver) {
					if (property === "render") {
						return (width: number) => {
							const lines = target.render(width);
							if (!activeLevel || !activeFrame) return lines;
							return replaceReasoningToken(lines, activeLevel, activeFrame);
						};
					}
					return Reflect.get(target, property, receiver);
				},
			}) as EditorComponent;

			return editor;
		}) as MarkedFactory;

		wrappedFactory[WRAPPER_MARKER] = true;
		wrappedFactory[WRAPPER_BASE] = baseFactory;
		baseEditorFactory = baseFactory;
		editorFactory = wrappedFactory;
		ctx.ui.setEditorComponent(wrappedFactory);
	};

	const animate = (ctx: ExtensionContext, level: string) => {
		wrapEditor(ctx);
		stopAnimation();
		activeLevel = level;

		const currentAnimationId = ++animationId;
		const frameCount = FRAME_COUNTS[level] ?? 20;
		let frameIndex = 0;

		const renderFrame = () => {
			if (currentAnimationId !== animationId) return;

			activeFrame = renderGradientFrame(level, frameIndex);
			frameIndex = (frameIndex + 1) % frameCount;
			requestEditorRender?.();
			timer = setTimeout(renderFrame, FRAME_INTERVAL_MS);
		};

		renderFrame();
	};

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		stopAnimation();
		editorFactory = undefined;
		baseEditorFactory = undefined;
		requestEditorRender = undefined;
		setTimeout(() => wrapEditor(ctx), 0);
	});

	pi.on("thinking_level_select", (event, ctx) => {
		if (ctx.mode !== "tui") return;
		if (!LEVELS.has(event.level)) {
			stopAnimation();
			requestEditorRender?.();
			return;
		}
		animate(ctx, event.level);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		stopAnimation();
		if (editorFactory && baseEditorFactory && ctx.ui.getEditorComponent() === editorFactory) {
			ctx.ui.setEditorComponent(baseEditorFactory);
		}
		editorFactory = undefined;
		baseEditorFactory = undefined;
		requestEditorRender = undefined;
	});
}
