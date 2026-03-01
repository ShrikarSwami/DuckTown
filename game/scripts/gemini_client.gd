extends Node
# Gemini client - handles HTTP calls to the backend proxy

var backend_url: String = "http://localhost:8080"
var http_request: HTTPRequest

signal request_completed(response: Dictionary)
signal request_failed(error: String)

func _ready():
	backend_url = "http://localhost:8080"
	
	# Create HTTPRequest node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	print("[GeminiClient] Initialized. Backend: %s" % backend_url)

func call_api(request_data: Dictionary) -> void:
	"""
	Send HTTP POST request to backend /api/gemini endpoint.
	Results are returned via request_completed or request_failed signals.
	
	request_data should contain:
	- npc_id, npc_name, npc_personality
	- player_message, player_relationship
	- dialogue_history, known_rumors
	"""
	if http_request == null:
		request_failed.emit("HTTP request node not initialized")
		return
	
	var json_string = JSON.stringify(request_data)
	print("[GeminiClient] Sending request ... npc=%s endpoint=%s" % [
		request_data.get("npc_name", "unknown"),
		backend_url + "/api/gemini"
	])
	
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(
		backend_url + "/api/gemini",
		headers,
		HTTPClient.METHOD_POST,
		json_string
	)
	
	if error != OK:
		var error_msg = "Failed to send request: error code %d" % error
		print("[GeminiClient] ERROR: %s" % error_msg)
		request_failed.emit(error_msg)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle HTTP response from backend"""
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "HTTP request failed: result code %d" % result
		print("[GeminiClient] ERROR: %s" % error_msg)
		request_failed.emit(error_msg)
		return
	
	if response_code != 200:
		var error_msg = "Backend returned status %d" % response_code
		print("[GeminiClient] ERROR: %s" % error_msg)
		request_failed.emit(error_msg)
		return
	
	# Parse JSON response
	var response_string = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_error = json.parse(response_string)
	
	if parse_error != OK:
		var error_msg = "Failed to parse JSON response: %s" % response_string
		print("[GeminiClient] ERROR: %s" % error_msg)
		request_failed.emit(error_msg)
		return
	
	var response_data = json.data
	if typeof(response_data) != TYPE_DICTIONARY:
		var type_error_msg = "Invalid JSON shape from backend (expected object)"
		print("[GeminiClient] ERROR: %s" % type_error_msg)
		request_failed.emit(type_error_msg)
		return

	print("[GeminiClient] Backend response received (success=%s)" % response_data.get("success", false))
	
	# Response is valid - emit it
	request_completed.emit(response_data)

func is_backend_available() -> bool:
	"""Check if backend is accessible"""
	# For now, just return true - actual check would use a health endpoint
	return true

func set_backend_url(url: String):
	"""Update backend URL"""
	backend_url = url
	print("[GeminiClient] Backend URL updated to: %s" % backend_url)


# TODO: Implement these methods
# - async_call_api(request_data: Dictionary) -> void
#   Non-blocking version using signals
#
# - retry_request(max_retries: int = 3) -> void
#   Retry failed requests with exponential backoff
#
# - cache_request(request_hash: String, response: Dictionary) -> void
#   Cache responses to avoid duplicate API calls
#
# - get_cached_response(request_hash: String) -> Dictionary
#   Retrieve cached response if available
