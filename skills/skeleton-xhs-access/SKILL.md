---
name: skeleton-xhs-access
description: "Fetch hot content and user posts from Xiaohongshu (Little Red Book) in parallel. Use when user needs to: (1) Get latest posts from multiple Xiaohongshu users, (2) Fetch trending content from multiple topics with filters (most liked, within a week), (3) Batch crawl Xiaohongshu data for analysis, (4) Monitor popular content across topics or users. Outputs structured JSON with post titles, authors, likes, cover images, and URLs."
---

# Xiaohongshu Hot Content Fetcher

Batch fetch and analyze hot content from Xiaohongshu (小红书) using parallel browser automation.

## Prerequisites

**Dependencies:**
- This skill requires a headless browser server provided by the `web-access` skill. See `https://github.com/eze-is/web-access`.
- The browser server must be running at `http://localhost:3456` before executing these scripts

**System requirements:**
- `curl`, `jq` installed
- Logged-in Xiaohongshu session in the browser

**Note:** This skill provides specialized batch crawling scripts for Xiaohongshu content. For general web access or single-item fetching, consider using the `web-access` skill directly.

## Usage

### Fetch User Posts

Get latest posts from multiple Xiaohongshu users:

```bash
scripts/fetch-parallel-users.sh 用户名1 用户名2 用户名3
```

**Output**: One JSON file per user named `{username}_最新笔记.json` containing:
- User info
- Latest 15 posts with title, cover image, likes, and note URL
- Crawl timestamp

**Example**:
```bash
scripts/fetch-parallel-users.sh 张三 李四 王五
```

### Fetch Topic Hot Content

Get trending posts from multiple topics with filters:

```bash
scripts/fetch-parallel-topics.sh 话题1 话题2 话题3 ...
```

**Example**:
```bash
scripts/fetch-parallel-topics.sh agent openclaw 人工智能 大模型 subagent claude openai
```

**Filters applied**:
- Sort by: Most liked (最多点赞)
- Time range: Within a week (一周内)

**Output**: One JSON file per topic named `{topic}话题_一周内最多点赞.json` containing:
- Topic name
- Filter settings
- Top 20 hot posts with title, author, publish time, likes, cover image, and note URL
- Crawl timestamp

**Customizing batch size**:
```bash
# Edit line 11 in scripts/fetch-parallel-topics.sh
BATCH_SIZE=5  # Change to desired batch size (1-10 recommended)
```

## How It Works

Both scripts use parallel browser automation with batch processing:

### Batch Processing (Topics)

To ensure stability and prevent rate limiting, the topic fetcher processes topics in batches:

1. **Batch size**: 5 topics per batch (configurable via `BATCH_SIZE` variable)
2. **Per batch workflow**:
   - Open tabs: Create browser tabs for all topics in the batch simultaneously
   - Wait for load: Brief delay for page rendering
   - Navigate & extract: For each tab, apply filters and extract structured data
   - Save results: Output JSON files with complete post metadata
   - Cleanup: Close all tabs in the batch before starting next batch
3. **Sequential batches**: Process batches one at a time to avoid overwhelming the browser

### User Posts Processing

User posts are processed in a single batch (all users simultaneously):

1. **Open tabs**: Create browser tabs for all users simultaneously
2. **Wait for load**: Brief delay for page rendering
3. **Navigate & extract**: For each tab, navigate to user profile and extract data
4. **Save results**: Output JSON files with complete post metadata
5. **Cleanup**: Close all tabs and remove temporary files

## Performance

- **Batch processing (Topics)**: Processes 5 topics per batch to maintain stability
  - Reduces browser memory usage by limiting concurrent tabs
  - Ensures filters have enough time to apply before extraction
  - Automatically scales to any number of topics
- **Parallel processing (Users)**: All users open simultaneously for faster completion
- **Controlled delays**: Strategic `sleep` commands prevent rate limiting
  - Post-filter delays: 5-7 seconds to ensure changes take effect
  - Between batches: 2 seconds to avoid overwhelming the server
- **Tab isolation**: Each user/topic processed in separate browser context

## Output Schema

### User Posts (`{username}_最新笔记.json`)
```json
{
  "user": {"name": "用户名"},
  "latest_notes": [
    {
      "index": 1,
      "title": "笔记标题",
      "cover_url": "https://...",
      "likes": "123",
      "note_url": "https://www.xiaohongshu.com/explore/..."
    }
  ],
  "crawled_at": "2026-03-26",
  "total_count": 15
}
```

### Topic Posts (`{topic}话题_一周内最多点赞.json`)
```json
{
  "topic": "话题名",
  "filter_settings": {
    "sort_by": "最多点赞",
    "publish_time": "一周内"
  },
  "hot_content": [
    {
      "index": 1,
      "title": "笔记标题",
      "author": "作者名",
      "publish_time": "2天前",
      "cover_url": "https://...",
      "likes": "1.2万",
      "note_url": "https://www.xiaohongshu.com/explore/..."
    }
  ],
  "crawled_at": "2026-03-26",
  "total_count": 20
}
```

## Error Handling

- If a user profile link is not found, that user is skipped with a warning
- Empty results indicate login issues or missing search results
- Check browser server is running if connection errors occur
