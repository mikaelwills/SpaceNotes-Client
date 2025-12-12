# NEVER TRY TO RUN THE APP AFTER MAKING CHANGES, USER ALWAYS HAS THE APP RUNNING IN ANOTHER TERMINAL

## User Commands

### "Look at my notes"
When the user says "look at my notes", use the spacenotes-mcp server to search or list notes from their vault.

```
mcp__spacenotes-mcp__list_notes_in_folder or mcp__spacenotes-mcp__get_note
```

### "Look at note updates"
When the user says "look at note updates", use spacenotes-mcp to get the note containing the list of issues and features that need to be implemented or fixed.

```
mcp__spacenotes-mcp__get_note with path: "Development/SpaceNotes/Spacenotes flutter client updates.md"
```

### Editing the updates note
Future tasks should always remain at the top as clear bullet points. Don't make the user scroll to see what's next. When marking tasks as complete, just remove them.

## Current Server Configuration
- SpacetimeDB: `100.84.184.121:3003` (Tailscale IP)
- **SpacetimeDB Module Source**: `/Users/mikaelwills/Productivity/Development/Rust/spacenotes/spacetime-module/src/lib.rs`
- **SpacetimeDB Database Name**: `spacenotes`
- **SpacetimeDB Dart SDK**: `/Users/mikaelwills/Productivity/Development/Dart/spacetimedb_dart_sdk`

### Regenerating SpacetimeDB Bindings

When the SpacetimeDB schema changes (e.g., after UUID migration), regenerate the Dart bindings:

```bash
# ALWAYS use the local Rust module path (no authentication required)
dart run spacetimedb_dart_sdk:generate \
  --project-path /Users/mikaelwills/Productivity/Development/Rust/spacenotes/spacetime-module \
  --output lib/generated
```

**Why local module path?**
- No authentication required (network method requires tokens)
- Always up-to-date with latest schema changes
- Builds the module and extracts schema directly

**Do NOT use:** `--server` flag unless you have valid authentication tokens configured.

### Manually Checking SpacetimeDB

When the user says "manually check the spacetimedb", use direct SQL queries via the SpacetimeDB CLI.

**Basic Query Syntax:**
```bash
spacetime sql spacenotes "<SQL_QUERY>" --server http://100.84.184.121:3003
```

**Common Queries:**

```bash
# List all notes with path and name
spacetime sql spacenotes "SELECT path, name FROM note" --server http://100.84.184.121:3003

# Check notes in a specific folder (use grep since LIKE is not supported)
spacetime sql spacenotes "SELECT path, name FROM note" --server http://100.84.184.121:3003 | grep "Folder Name"

# Get a specific note by ID
spacetime sql spacenotes "SELECT * FROM note WHERE id = '<uuid>'" --server http://100.84.184.121:3003

# Count total notes
spacetime sql spacenotes "SELECT COUNT(*) FROM note" --server http://100.84.184.121:3003
```

**Important Notes:**
- SpacetimeDB SQL does NOT support `LIKE` operator - use `grep` for filtering instead
- Always use `grep` after the SQL query to filter by folder names or patterns
- The `--server` flag is required to specify which SpacetimeDB instance to query
- Queries run against the `spacenotes` database name

**Example: Checking Notes in a Folder**
```bash
# Query all notes and filter for "Ending Everything Band" folder
spacetime sql spacenotes "SELECT path, name FROM note" --server http://100.84.184.121:3003 | grep "Ending Everything Band"
```

### OLD Obsidian REST API Configuration
- **HTTPS Port**: 27124
- **HTTP Port**: 27123 (insecure, enabled for development)
- **API Key**: `d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b`
- **Base URL**: `http://100.84.184.121:27123` (via Tailscale)
- **Authentication**: `Authorization: Bearer <api-key>` header
- **Status**: ✅ **WORKING** - API tested and functional

## Complete API Reference

### Core Endpoints

#### **1. System Information**
- **GET /** - Get server status and info
  - Returns: Server version, authentication status, plugin info
  - Auth: Not required

#### **2. Vault Operations**
- **GET /vault/** - List all files in vault root
  - Returns: `{"files": ["note1.md", "note2.md", "folder/"]}`
  - Auth: Required

- **GET /vault/{path}** - Get file content or folder contents
  - For files: Returns raw markdown content
  - For folders: Returns `{"files": [...]}`
  - Auth: Required

- **POST /vault/{path}** - Create new note ✅ Tested
  - Content-Type: `text/markdown`
  - Body: Raw markdown content
  - Returns: 200 on success
  - Auth: Required

- **PUT /vault/{path}** - Update existing note
  - Content-Type: `text/markdown`
  - Body: Raw markdown content
  - Auth: Required

- **PATCH /vault/{path}** - Insert content into specific sections ⚠️ Advanced
  - **Purpose**: Insert content relative to headings, block references, or frontmatter
  - **Headers Required**:
    - `Target-Type: heading|block|frontmatter`
    - `Target-Value: <heading name or block reference>`
    - `Operation: append|prepend|replace`
  - **Use Cases**: Add content under specific headings, update frontmatter fields
  - **Note**: Complex API - may need experimentation for exact syntax
  - Auth: Required

- **DELETE /vault/{path}** - Delete note
  - Returns: 204 on success
  - Auth: Required

#### **3. Commands**
- **GET /commands/** - List all available Obsidian commands ✅ Tested
  - Returns: Array of command objects with `id` and `name`
  - Useful for automation and integrations
  - Auth: Required

#### **4. Advanced Features**
- **GET /search/** - Search notes (endpoint exists but may not be functional)
- **GET /search/simple/** - Simple search interface
- **GET /active/** - Get currently active note
- **GET /openapi.yaml** - API specification ✅ Available

### Authentication
- **Method**: `Authorization: Bearer <api-key>`
- **API Key**: `d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b`
- **Required**: All endpoints except `/`

### Example Requests
```bash
# List all notes
curl -H "Authorization: Bearer d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b" \
  "http://100.84.184.121:27123/vault/"

# Get specific note
curl -H "Authorization: Bearer d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b" \
  "http://100.84.184.121:27123/vault/Welcome.md"

# Create new note
curl -X POST \
  -H "Authorization: Bearer d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b" \
  -H "Content-Type: text/markdown" \
  -d "# My New Note\n\nContent here" \
  "http://100.84.184.121:27123/vault/my-note.md"

# Get available commands
curl -H "Authorization: Bearer d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b" \
  "http://100.84.184.121:27123/commands/"
```

### Data Models
```json
// File list response
{
  "files": ["note1.md", "note2.md", "folder/"]
}

// Command object
{
  "id": "editor:save-file",
  "name": "Save current file"
}

// Error response
{
  "message": "Error description",
  "errorCode": 40101
}
```

# File Naming Architecture

## **FILE NAME IS NOT DERIVED FROM THE TOP OF THE CONTENT AT ALL**

- File names and content are completely separate concerns
- Renaming is an explicit user action, not automatic
- Content changes only trigger `updateNoteContent` reducer
- Path changes only triggered by explicit rename operations through UI

### UI Implementation
- File name displayed in NavBar when on NoteScreen (similar to folder name display)
- Rename option available in ellipses menu (⋮)
- Rename triggers dialog/prompt for new name
- Calls `repo.renameNote(noteId, newPath)` directly
