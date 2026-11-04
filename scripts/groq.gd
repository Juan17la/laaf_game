class_name Groq
extends RefCounted
## The final report's closing paragraph on the player's habits, written by Groq's API from the run's numbers (scripts/run_report.gd). Optional: the
## only network access in the game, and it happens only when a key is set: GROQ_API_KEY, user://groq_key.txt, or the
## RELEASE_KEY_FILE that installer/build.sh packs into a release. The key is never in the repo. Only the facts passed
## in are sent. No key, no network or a bad answer: "" (the report falls back on its own line).

const URL := "https://api.groq.com/openai/v1/chat/completions"
const MODEL := "openai/gpt-oss-120b"
const KEY_FILE := "user://groq_key.txt"
const RELEASE_KEY_FILE := "res://groq_release_key.txt"  ## only in release builds (gitignored, made by installer/build.sh)
const TIMEOUT := 10.0
const MAX_LEN := 560  ## what fits the report's paragraph; longer is a model ignoring its brief
static var last_error := ""  ## why the last verdict() came back "" (for the DEV tab's AI result; never holds the key)

const NARRATOR := "You are the unseen narrator of LAAF, a bleak fog-bound survival horror set in the town of Hollowmere. Write a closing paragraph of three sentences and at most 60 words, addressed to the player as \"you\", describing the habits they showed while playing: how they fought, moved and hid, where they kept returning, and what the enemies learned about them. Write about behaviour, not statistics: do not list numbers, and quote at most two exact figures. Each habit is rated faint, moderate or strong: how clearly the enemies read it by the end. Paraphrase the habits and ratings in natural language, never repeating those labels. Use only what the data shows and invent no events or characters. Keep the tone dry and unsettling. Output only the paragraph, with no quotes, markdown or emoji. Write in %s."


static func api_key() -> String:
	var key := OS.get_environment("GROQ_API_KEY").strip_edges()
	for file in [KEY_FILE, RELEASE_KEY_FILE]:
		if key == "" and FileAccess.file_exists(file):
			key = FileAccess.get_file_as_string(file).strip_edges()
	return key


static func verdict(host: Node, facts: Dictionary, language: String) -> String:
	## Coroutine: the line, or "". The request lives on `host` and dies with it.
	last_error = ""
	var key := api_key()
	if key == "":
		last_error = "no key set"
		return ""
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	host.add_child(http)
	var body := JSON.stringify({"model": MODEL, "temperature": 0.9, "max_completion_tokens": 1000,
		"reasoning_effort": "low", "messages": [{"role": "system", "content": NARRATOR % language},
		{"role": "user", "content": JSON.stringify(facts)}]})
	var headers := PackedStringArray(["Authorization: Bearer " + key, "Content-Type: application/json"])
	if http.request(URL, headers, HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()
		last_error = "request not sent"
		return ""
	var r: Array = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		last_error = "no connection (result %d)" % r[0]
		return ""
	if r[1] != 200:
		last_error = "HTTP %d" % r[1]
		return ""
	var line := clean(answer((r[3] as PackedByteArray).get_string_from_utf8()))
	if line == "":
		last_error = "unusable answer"
	return line


static func answer(json: String) -> String:
	## The message text out of a chat completion, "" if it isn't one or it was cut off mid-sentence.
	var data: Variant = JSON.parse_string(json)
	if not data is Dictionary or not data.get("choices") is Array or data.choices.is_empty():
		return ""
	var choice: Variant = data.choices[0]
	if not choice is Dictionary or not choice.get("message") is Dictionary or choice.get("finish_reason") == "length":
		return ""
	var content: Variant = choice.message.get("content")
	return content if content is String else ""


static func clean(s: String) -> String:
	## One plain paragraph, or "" when what came back can't be shown in the report.
	if s.contains("</think>"):
		s = s.get_slice("</think>", 1)
	s = " ".join(s.split("\n", false)).strip_edges().lstrip("\"'“”*").rstrip("\"'“”*")
	if s.length() <= MAX_LEN:
		return s
	var end := s.left(MAX_LEN).rfind(". ")  # (models overrun their word limit: keep the sentences that fit)
	return s.left(end + 1) if end > 0 else ""
