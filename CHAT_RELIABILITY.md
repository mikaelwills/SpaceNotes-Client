# OpenCode Chat Reliability Issues

Identified reliability concerns in the current chat architecture.

---

## Observed Symptoms

Real-world failures encountered in release mode:

### A. Message Stuck on "Ask AI..."
- User sends message, UI stays on placeholder text
- No indication that anything is happening
- No error shown, no spinner, nothing
- **Likely causes:** Session not created, HTTP send failed silently, SSE not connected

### B. Streaming Works But Nothing Prints
- Request goes through (no error)
- SSE connection appears active
- But no text appears in the UI
- **Likely causes:** SSE events not parsed correctly, UI not rebuilding, event type mismatch

### C. Silent Failures
- Something breaks but user has no feedback
- Can't tell if it's network, server, or client issue
- Need to restart app to recover

---

## Regression Tests

The existing chat regression tests help capture real JSON responses from OpenCode. These are valuable for:
- Seeing actual event payloads from production
- Identifying parsing issues with real data
- Improving chat experience based on real responses
- Catching regressions when SSE format changes

---

## 1. ~~No Explicit State Machine~~ ✅ IMPLEMENTED

**Status:** Implemented in ChatBloc with ChatFlowPhase enum.

**Implementation:**
- `ChatFlowPhase` enum: `idle`, `sending`, `awaitingResponse`, `streaming`, `failed`, `reconnecting`
- `ChatTransitions` class validates state transitions
- `ChatReady` state now includes `phase` field with helper getters: `isWorking`, `canSend`, etc.
- Invalid transitions are logged and rejected
- Removed deprecated `ChatSendingMessage` class

---

## 2. SSE Gap During Reconnect

**Problem:** Events can be missed during the 2-30s reconnect window. No event ID tracking for resumption.

**Symptoms:**
- Message appears stuck mid-stream after network blip
- Missing chunks of streamed text
- UI shows streaming but nothing arrives

**Solution Options:**
- Track last event ID, request replay on reconnect (if server supports)
- On reconnect, fetch full message state from REST API to reconcile
- Show "sync" indicator and refresh messages after reconnect

---

## 3. No Idempotency Keys

**Problem:** No client-generated message IDs to prevent duplicates.

**Symptoms:**
- Double-tap on send creates duplicate messages
- Network retry might send same message twice
- Server can't dedupe identical requests

**Solution:**
- Generate UUID client-side before send
- Include in request payload
- Server dedupes by idempotency key
- Track key until confirmed received

---

## Priority Ranking

1. ~~**State Machine** - High impact, Medium effort~~ ✅ DONE
2. **SSE Gap Recovery** - Medium impact, Medium effort
3. **Idempotency Keys** - Low impact, Low effort

---

## Implementation Notes

### State Machine Approach

```
States: idle, sending, awaitingResponse, streaming, failed, reconnecting

Events:
- UserSendMessage
- SendSuccess
- SendFailed
- SSEMessageReceived
- SSEStreamComplete
- SSEDisconnected
- SSEReconnected
- UserRetry
- UserCancel
- Timeout
```

