import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type AnimationName = "soundbar" | "comet" | "neural";
type IndicatorTheme = ExtensionContext["ui"]["theme"];

type Animation = {
	description: string;
	intervalMs: number;
	createFrames: (theme: IndicatorTheme) => string[];
};

const BARS = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];
const SOUNDBAR_COUNT = 7;
const SOUNDBAR_FRAME_COUNT = 32;
const SOUNDBAR_KEYFRAME_COUNT = 8;
const COMET_WIDTH = 9;

function smoothstep(amount: number): number {
	return amount * amount * (3 - 2 * amount);
}

function seededRandom(seed: number): number {
	const value = Math.sin(seed * 12.9898) * 43758.5453;
	return value - Math.floor(value);
}

function createSoundbarFrames(theme: IndicatorTheme): string[] {
	const keyframes = Array.from({ length: SOUNDBAR_KEYFRAME_COUNT }, (_, keyframeIndex) =>
		Array.from({ length: SOUNDBAR_COUNT }, (_, barIndex) =>
			0.15 + seededRandom(keyframeIndex * SOUNDBAR_COUNT + barIndex + 1) * 0.85,
		),
	);

	return Array.from({ length: SOUNDBAR_FRAME_COUNT }, (_, frameIndex) => {
		const position = (frameIndex / SOUNDBAR_FRAME_COUNT) * SOUNDBAR_KEYFRAME_COUNT;
		const startIndex = Math.floor(position) % SOUNDBAR_KEYFRAME_COUNT;
		const endIndex = (startIndex + 1) % SOUNDBAR_KEYFRAME_COUNT;
		const amount = smoothstep(position - Math.floor(position));
		const start = keyframes[startIndex] ?? [];
		const end = keyframes[endIndex] ?? start;
		const frame = start
			.map((level, barIndex) => {
				const nextLevel = end[barIndex] ?? level;
				const interpolated = level + (nextLevel - level) * amount;
				return BARS[Math.round(interpolated * (BARS.length - 1))];
			})
			.join("");

		return theme.fg("accent", frame);
	});
}

function createNeuralFrames(theme: IndicatorTheme): string[] {
	const nodeCount = 5;
	const borders = [
		["⟨", "⟩"],
		["[", "]"],
		["(", ")"],
		["{", "}"],
	] as const;
	const positions = [0, 1, 2, 3, 4, 3, 2, 1, 0];
	const frames: string[] = [];

	for (const [leftBorder, rightBorder] of borders) {
		for (const activeNode of positions) {
			const nodes = Array.from({ length: nodeCount }, (_, index) =>
				index === activeNode ? theme.fg("accent", "●") : theme.fg("muted", "○"),
			);
			const pathway = nodes.join(theme.fg("dim", "─"));
			frames.push(`${theme.fg("dim", leftBorder)}${pathway}${theme.fg("dim", rightBorder)}`);
		}
	}

	return frames;
}

function createCometFrames(theme: IndicatorTheme): string[] {
	const forward = Array.from({ length: COMET_WIDTH }, (_, index) => index);
	const backward = Array.from({ length: COMET_WIDTH - 2 }, (_, index) => COMET_WIDTH - index - 2);
	const positions = [...forward, ...backward];

	return positions.map((headPosition, frameIndex) => {
		const firstTailPosition = positions[(frameIndex - 1 + positions.length) % positions.length];
		const secondTailPosition = positions[(frameIndex - 2 + positions.length) % positions.length];
		const track = Array.from({ length: COMET_WIDTH }, (_, index) => {
			if (index === headPosition) return theme.fg("accent", "●");
			if (index === firstTailPosition) return theme.fg("muted", "•");
			if (index === secondTailPosition) return theme.fg("dim", "∙");
			return theme.fg("dim", "·");
		}).join("");

		return `${theme.fg("muted", "(")}${track}${theme.fg("muted", ")")}`;
	});
}

const ANIMATIONS: Record<AnimationName, Animation> = {
	neural: {
		description: "a signal pulsing through a neural pathway",
		intervalMs: 110,
		createFrames: createNeuralFrames,
	},
	soundbar: {
		description: "smooth randomized equalizer bars",
		intervalMs: 75,
		createFrames: createSoundbarFrames,
	},
	comet: {
		description: "a comet gliding from side to side",
		intervalMs: 70,
		createFrames: createCometFrames,
	},
};

function isAnimationName(value: string): value is AnimationName {
	return value in ANIMATIONS;
}

export default function (pi: ExtensionAPI) {
	let activeAnimation: AnimationName = "neural";

	const applyAnimation = (ctx: ExtensionContext) => {
		if (ctx.mode !== "tui") return;

		const animation = ANIMATIONS[activeAnimation];
		ctx.ui.setWorkingIndicator({
			frames: animation.createFrames(ctx.ui.theme),
			intervalMs: animation.intervalMs,
		});
	};

	pi.on("session_start", (_event, ctx) => {
		applyAnimation(ctx);
	});

	pi.registerCommand("indicator", {
		description: "Select a working animation: neural, soundbar, or comet.",
		getArgumentCompletions: (prefix) => {
			const matches = (Object.keys(ANIMATIONS) as AnimationName[])
				.filter((name) => name.startsWith(prefix.toLowerCase()))
				.map((name) => ({ value: name, label: name, description: ANIMATIONS[name].description }));
			return matches.length > 0 ? matches : null;
		},
		handler: async (args, ctx) => {
			const requestedAnimation = args.trim().toLowerCase();
			if (!requestedAnimation) {
				ctx.ui.notify(`Working animation: ${activeAnimation}`, "info");
				return;
			}

			if (!isAnimationName(requestedAnimation)) {
				ctx.ui.notify("Usage: /indicator [neural|soundbar|comet]", "error");
				return;
			}

			activeAnimation = requestedAnimation;
			applyAnimation(ctx);
			ctx.ui.notify(`Working animation set to ${activeAnimation}`, "info");
		},
	});
}
