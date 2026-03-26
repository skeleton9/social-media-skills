#!/bin/bash
set -e

# 从命令行参数读取话题列表
if [ $# -eq 0 ]; then
  echo "用法: $0 话题1 话题2 话题3 ..."
  echo "示例: $0 agent openclaw 人工智能 大模型"
  exit 1
fi

TOPICS=("$@")

# 每批处理的话题数量
BATCH_SIZE=5

echo "======================================"
echo "🚀 开始并行获取 ${#TOPICS[@]} 个话题"
echo "📦 批次大小: $BATCH_SIZE 个话题/批"
echo "======================================"

# 创建临时目录存储 target IDs
TEMP_DIR="/tmp/xhs_parallel_$$"
mkdir -p "$TEMP_DIR"

# 计算总批次数
TOTAL_BATCHES=$(( (${#TOPICS[@]} + BATCH_SIZE - 1) / BATCH_SIZE ))

# 分批处理
for batch in $(seq 0 $((TOTAL_BATCHES - 1))); do
  start_idx=$((batch * BATCH_SIZE))
  end_idx=$((start_idx + BATCH_SIZE))
  if [ $end_idx -gt ${#TOPICS[@]} ]; then
    end_idx=${#TOPICS[@]}
  fi

  batch_topics=("${TOPICS[@]:$start_idx:$((end_idx - start_idx))}")

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 批次 $((batch + 1))/$TOTAL_BATCHES (话题 $((start_idx + 1))-$end_idx)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 1. 并行打开当前批次的所有话题页面
  for i in $(seq 0 $((${#batch_topics[@]} - 1))); do
    global_idx=$((start_idx + i))
    topic="${batch_topics[$i]}"
    encoded=$(echo -n "$topic" | jq -sRr @uri)
    echo "📖 打开话题：$topic"
    target=$(curl -s "http://localhost:3456/new?url=https://www.xiaohongshu.com/search_result?keyword=${encoded}&type=54" | jq -r '.targetId')
    echo "$target" > "$TEMP_DIR/${global_idx}.target"
    echo "  └─ Target ID: $target"
  done

  echo ""
  echo "⏳ 等待页面加载..."
  sleep 3

  # 2. 为当前批次的每个话题执行筛选和提取
  for i in $(seq 0 $((${#batch_topics[@]} - 1))); do
    global_idx=$((start_idx + i))
    global_idx=$((start_idx + i))
    topic="${batch_topics[$i]}"
    target=$(cat "$TEMP_DIR/${global_idx}.target")

    echo ""
    echo "======================================"
    echo "🔍 处理话题：$topic (Target: $target)"
    echo "======================================"
  
  # 2.1 打开筛选面板
  echo "  ► 打开筛选面板..."
  curl -s -X POST "http://localhost:3456/click?target=$target" -d '.filter' > /dev/null
  sleep 1
  
  # 2.2 设置排序：最多点赞
  echo "  ► 设置排序：最多点赞..."
  result=$(curl -s -X POST "http://localhost:3456/eval?target=$target" -d '
const allDivs = Array.from(document.querySelectorAll("div.tags"));
const likeBtn = allDivs.find(div => div.textContent.trim() === "最多点赞");
if (likeBtn) { likeBtn.click(); "已点击最多点赞"; } else { "未找到最多点赞按钮"; }
' | jq -r '.value')
  echo "    └─ $result"
  sleep 5
  
  # 2.3 设置时间范围：一周内
  echo "  ► 设置时间：一周内..."
  result=$(curl -s -X POST "http://localhost:3456/eval?target=$target" -d '
const filterPanel = document.querySelector(".filter-panel") || document.querySelector("[class*=\"panel\"]");
if (filterPanel) {
  const allTexts = Array.from(filterPanel.querySelectorAll("*"));
  const weekElement = allTexts.find(el => el.textContent.trim() === "一周内" && el.tagName === "DIV");
  if (weekElement) { weekElement.click(); "找到并点击了一周内"; } else { "未找到一周内元素"; }
} else { "未找到筛选面板"; }
' | jq -r '.value')
  echo "    └─ $result"
  sleep 7
  
  # 2.4 提取热门内容
  echo "  ► 提取热门内容..."
  notes=$(curl -s -X POST "http://localhost:3456/eval?target=$target" -d '
const notes = document.querySelectorAll("section.note-item");
const result = Array.from(notes).slice(0, 20).map((note, index) => {
  const cover = note.querySelector("img");
  const title = note.querySelector(".title");
  const authorEl = note.querySelector(".author");
  const likes = note.querySelector(".like-wrapper");
  const link = note.querySelector("a");

  let author = "";
  let publishTime = "";
  if (authorEl) {
    const fullText = authorEl.textContent.trim();
    const match = fullText.match(/^(.+?)([\d]+.+)$/);
    if (match) {
      author = match[1];
      publishTime = match[2];
    } else {
      author = fullText;
    }
  }

  return {
    index: index + 1,
    title: title ? title.textContent.trim() : "",
    author: author,
    publish_time: publishTime,
    cover_url: cover ? cover.src : "",
    likes: likes ? likes.textContent.trim() : "",
    note_url: link ? "https://www.xiaohongshu.com" + link.getAttribute("href").split("?")[0] : ""
  };
}).filter(item => item.title && item.title.length > 0);
JSON.stringify(result, null, 2);
' | jq -r '.value')
  
  # 2.5 保存数据
  output_file="${topic}话题_一周内最多点赞.json"
  jq -n \
    --arg topic "$topic" \
    --arg date "$(date +%Y-%m-%d)" \
    --argjson content "$notes" \
    '{
      topic: $topic,
      filter_settings: {sort_by: "最多点赞", publish_time: "一周内"},
      hot_content: $content,
      crawled_at: $date,
      total_count: ($content | length)
    }' > "$output_file"

  count=$(echo "$notes" | jq '. | length')
  echo "    └─ 获取 $count 条内容，已保存到: $output_file"

  # 话题之间间隔
  sleep 2
  done

  # 3. 关闭当前批次的所有 tab
  echo ""
  echo "🧹 清理当前批次浏览器 tab..."
  for i in $(seq 0 $((${#batch_topics[@]} - 1))); do
    global_idx=$((start_idx + i))
    topic="${batch_topics[$i]}"
    target=$(cat "$TEMP_DIR/${global_idx}.target")
    curl -s "http://localhost:3456/close?target=$target" > /dev/null
    echo "  ✓ 关闭话题：$topic"
  done

  # 批次之间短暂间隔
  if [ $((batch + 1)) -lt $TOTAL_BATCHES ]; then
    echo ""
    echo "⏸️  批次间隔 2 秒..."
    sleep 2
  fi
done

# 清理临时文件
rm -rf "$TEMP_DIR"

echo ""
echo "======================================"
echo "✅ 全部完成！"
echo "======================================"
for topic in "${TOPICS[@]}"; do
  file="${topic}话题_一周内最多点赞.json"
  if [ -f "$file" ]; then
    count=$(jq '.total_count' "$file")
    top_title=$(jq -r '.hot_content[0].title' "$file")
    top_likes=$(jq -r '.hot_content[0].likes' "$file")
    echo "📊 $topic: $count 条 | Top: $top_title ($top_likes 赞)"
  fi
done
