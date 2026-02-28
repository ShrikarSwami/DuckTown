extends Node
# Gemini client - handles HTTP calls to the backend proxy

# TODO: Implement backend communication

var backend_url: String = "http://localhost:8080"
var http_client: HTTPClient
var is_connected: bool = false
var request_timeout: float = 30.0

signal request_completed(response: Dictionary)
signal request_failed(error: String)

func _ready():
    # TODO: Load backend URL from settings / environment
    # For now, use localhost for development
    backend_url = "http://localhost:8080"
    print("Gemini client initialized. Backend: %s" % backend_url)

func _process(delta):
    # TODO: Handle async HTTP requests
    # Check if any requests are in progress and handle responses
    pass

func call_api(request_data: Dictionary) -> Dictionary:
    # TODO: Send HTTP POST request to backend /api/gemini endpoint
    # request_data should contain:
    # - npc_id, npc_name, npc_personality
    # - player_message, player_relationship
    # - dialogue_history, known_rumors
    
    var json_string = JSON.stringify(request_data)
    print("Calling backend: %s" % json_string)
    
    # TODO: Create HTTP request
    # var http_request = HTTPRequest.new()
    # add_child(http_request)
    # http_request.request_completed.connect(_on_request_completed)
    # var error = http_request.request(
    #     backend_url + "/api/gemini",
    #     ["Content-Type: application/json"],
    #     HTTPClient.METHOD_POST,
    #     json_string
    # )
    
    # For now, return placeholder response
    return {
        "success": false,
        "error": "TODO: Implement HTTP client"
    }

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
    # TODO: Handle HTTP response from backend
    
    if result != HTTPRequest.RESULT_SUCCESS:
        var error_msg = "HTTP request failed: %d" % result
        print(error_msg)
        request_failed.emit(error_msg)
        return
    
    if response_code != 200:
        var error_msg = "Backend returned status %d" % response_code
        print(error_msg)
        request_failed.emit(error_msg)
        return
    
    # Parse JSON response
    var response_string = body.get_string_from_utf8()
    var json = JSON.new()
    var parse_error = json.parse(response_string)
    
    if parse_error != OK:
        var error_msg = "Failed to parse JSON response"
        print(error_msg)
        request_failed.emit(error_msg)
        return
    
    var response_data = json.data
    print("Backend response: %s" % response_string)
    
    # TODO: Validate response against expected schema
    # Validate required fields: success, npc_reply
    # Validate optional fields: rumor, relationship_delta, quest_progress
    
    if validate_response(response_data):
        request_completed.emit(response_data)
    else:
        request_failed.emit("Response validation failed")

func validate_response(response: Dictionary) -> bool:
    # TODO: Validate response JSON schema
    # Required fields:
    # - success: bool
    # - npc_reply: string (if success == true)
    #
    # Optional fields:
    # - rumor: object with text, tags, confidence
    # - relationship_delta: int (-50 to 50)
    # - quest_progress: object
    # - npc_mood_change: string
    # - metadata: object
    
    # Basic validation
    if not response.has("success"):
        print("Response missing 'success' field")
        return false
    
    if response["success"] == true:
        if not response.has("npc_reply"):
            print("Response missing 'npc_reply' field")
            return false
        
        var npc_reply = response["npc_reply"]
        if typeof(npc_reply) != TYPE_STRING or npc_reply.is_empty():
            print("Invalid npc_reply: not a non-empty string")
            return false
        
        # TODO: Validate optional fields
        if response.has("relationship_delta"):
            if typeof(response["relationship_delta"]) != TYPE_INT:
                print("Invalid relationship_delta: not an int")
                return false
            if response["relationship_delta"] < -50 or response["relationship_delta"] > 50:
                print("relationship_delta out of range")
                return false
    
    return true

func is_backend_available() -> bool:
    # TODO: Ping backend to check if it's running
    # For now, just return true
    return true

func set_backend_url(url: String):
    # TODO: Update backend URL (from settings menu)
    backend_url = url
    print("Backend URL updated to: %s" % backend_url)

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
