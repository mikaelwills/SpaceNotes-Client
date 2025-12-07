# OpenCode Response Fixtures

This directory contains real responses captured from the OpenCode server during integration tests. These fixtures serve multiple purposes:

1. **Documentation**: Shows what OpenCode actually sends in various scenarios
2. **Regression Testing**: Validates that parsing logic handles real-world responses
3. **Debugging**: Reference for troubleshooting parsing issues

## Captured Response Types

### Simple Responses
- `simple_text.json` - Basic text-only response
- `greeting.json` - Short conversational response

### Tool-Using Responses
- `file_list.json` - Response with Glob/Bash tool usage
- `file_read.json` - Response with Read tool usage
- `file_write.json` - Response with Write/Edit tool usage

### Complex Multi-Part Responses
- `multi_tool.json` - Multiple tool calls in sequence
- `code_modification.json` - Response with diffs and edits
- `complex_analysis.json` - Long response with mixed part types

### Streaming Responses
- `streaming_incomplete.json` - Response captured mid-stream
- `streaming_complete.json` - Same response after completion

### Error Responses
- `error_response.json` - Server error format

## Recording New Fixtures

Run integration tests in record mode:

```bash
flutter test test/integration/opencode_response_parsing_test.dart --dart-define=RECORD_MODE=true
```

## Response Structure Notes

OpenCode responses typically have this structure:

```json
{
  "id": "message-id",
  "sessionID": "session-id",
  "role": "assistant",
  "time": {
    "created": 1234567890,
    "completed": 1234567890
  },
  "parts": [
    {
      "id": "part-id",
      "type": "text|tool|diff|plan-options",
      "text": "content here",
      "metadata": {...}
    }
  ]
}
```

### Known Variations

- Field names: `sessionID` vs `sessionId` vs `session_id`
- Timestamps: milliseconds (int) vs ISO strings
- Content fields: `text` vs `content`
- Tool metadata: varies by tool type
