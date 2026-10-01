import { render, type TemplateResult } from "lit";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { ReaderSettings } from "../models/types.js";
import { DEFAULT_SETTINGS } from "../services/defaults.js";
import type { PlaybackState } from "../services/rsvp-engine.js";
import { RsvpReader } from "./rsvp-reader.js";

vi.mock("../services/theme-service.js", () => ({ applyTheme: vi.fn() }));

const containers: HTMLElement[] = [];

afterEach(() => {
	for (const container of containers) container.remove();
	containers.length = 0;
});

function renderWordDisplay(
	settings: ReaderSettings,
	displayWordIndex: number,
): HTMLElement {
	const reader = new RsvpReader();
	const internals = reader as unknown as {
		settings: ReaderSettings;
		engine: {
			load: (text: string, settings: ReaderSettings) => void;
			tokens: Array<{ text: string }>;
		};
		renderWordDisplay: (state: PlaybackState) => TemplateResult;
	};
	internals.settings = settings;
	internals.engine.load("first middle last", settings);
	const currentToken = internals.engine.tokens[displayWordIndex];
	const state: PlaybackState = {
		playing: false,
		wordIndex: displayWordIndex,
		displayWordIndex,
		totalWords: internals.engine.tokens.length,
		currentTokens: [currentToken] as PlaybackState["currentTokens"],
		currentOrp: null,
		elapsedMs: 0,
		startTime: null,
		baseWpm: settings.wpm,
		currentWpm: settings.wpm,
	};
	const container = document.createElement("div");
	containers.push(container);
	render(internals.renderWordDisplay(state), container);
	return container;
}

describe("peripheral context layout", () => {
	it.each([
		{ index: 0, emptySide: 0 },
		{ index: 2, emptySide: 1 },
	])("keeps both peripheral rows at document edge $index", ({
		index,
		emptySide,
	}) => {
		const container = renderWordDisplay(
			{ ...DEFAULT_SETTINGS, peripheralContext: true },
			index,
		);
		const spans = container.querySelectorAll(".peripheral-context");
		const emptySpan = spans.item(emptySide);

		expect(spans).toHaveLength(2);
		expect(emptySpan).not.toBeNull();
		expect(emptySpan?.classList.contains("invisible")).toBe(true);
		expect(emptySpan?.textContent).toContain("\u00a0");
	});

	it("omits peripheral rows when the feature is disabled", () => {
		const container = renderWordDisplay(
			{ ...DEFAULT_SETTINGS, peripheralContext: false },
			0,
		);

		expect(container.querySelectorAll(".peripheral-context")).toHaveLength(0);
	});
});
