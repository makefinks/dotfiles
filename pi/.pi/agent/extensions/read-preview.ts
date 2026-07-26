import {
	createReadToolDefinition,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";

const MAX_PREVIEW_LINES = 4;

/**
 * Keep successful file reads compact even when Ctrl+O expands other tool output.
 * The complete result is still sent to the model; only the TUI rendering is clipped.
 */
export default function (pi: ExtensionAPI) {
	const builtinRead = createReadToolDefinition(process.cwd());
	const builtinRenderResult = builtinRead.renderResult;

	pi.registerTool({
		...builtinRead,

		// Resolve against the active session cwd rather than the process cwd captured
		// when the extension was loaded.
		execute(toolCallId, params, signal, onUpdate, ctx) {
			return createReadToolDefinition(ctx.cwd).execute(
				toolCallId,
				params,
				signal,
				onUpdate,
				ctx,
			);
		},

		renderResult(result, options, theme, context) {
			if (!builtinRenderResult) {
				throw new Error("Pi's built-in read renderer is unavailable");
			}

			// Preserve Pi's normal collapsed view and full error messages. Only clip a
			// successful read when the global tool-output expansion is enabled.
			if (!options.expanded || context.isError) {
				return builtinRenderResult(result, options, theme, context);
			}

			const previewContent = result.content.map((block) => {
				if (block.type !== "text") return block;

				const lines = block.text.split("\n");
				if (lines.length <= MAX_PREVIEW_LINES) return block;

				const omitted = lines.length - MAX_PREVIEW_LINES;
				return {
					...block,
					text: `${lines.slice(0, MAX_PREVIEW_LINES).join("\n")}\n... (${omitted} more lines hidden in the file-read preview)`,
				};
			});

			return builtinRenderResult(
				{ ...result, content: previewContent },
				options,
				theme,
				context,
			);
		},
	});
}
