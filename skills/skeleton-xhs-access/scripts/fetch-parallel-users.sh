#!/bin/bash
set -e

# 从命令行参数读取用户列表
if [ $# -eq 0 ]; then
  echo "用法: $0 用户名1 用户名2 用户名3 ..."
  exit 1
fi

USERS=("$@")

echo "======================================"
echo "🚀 开始并行获取 ${#USERS[@]} 个用户的笔记"
echo "======================================"

# 创建临时目录存储 target IDs
TEMP_DIR="/tmp/xhs_users_parallel_$$"
mkdir -p "$TEMP_DIR"

# 1. 并行打开所有用户搜索页面
for i in "${!USERS[@]}"; do
  user="${USERS[$i]}"
  encoded=$(echo -n "$user" | jq -sRr @uri)
  echo "📖 打开用户搜索：$user"
  target=$(curl -s "http://localhost:3456/new?url=https://www.xiaohongshu.com/search_result?keyword=${encoded}&type=user" | jq -r '.targetId')
  echo "$target" > "$TEMP_DIR/${i}.target"
  echo "  └─ Target ID: $target"
done

echo ""
echo "⏳ 等待页面加载..."
sleep 3

# 2. 为每个用户执行导航和提取
for i in "${!USERS[@]}"; do
  user="${USERS[$i]}"
  target=$(cat "$TEMP_DIR/${i}.target")
  
  echo ""
  echo "======================================"
  echo "🔍 处理用户：$user (Target: $target)"
  echo "======================================"
  
  # 2.1 点击"用户"标签（如果需要）
  echo "  ► 切换到用户标签..."
  curl -s -X POST "http://localhost:3456/eval?target=$target" -d '
const elements = Array.from(document.querySelectorAll("*"));
const userTab = elements.find(el => el.textContent?.trim() === "用户" && el.children.length === 0);
if (userTab && !userTab.classList.contains("active")) {
  userTab.click();
}
"OK";
' > /dev/null
  sleep 2
  
  # 2.2 直接提取用户主页链接并导航
  echo "  ► 提取用户主页链接..."
  profile_url=$(curl -s -X POST "http://localhost:3456/eval?target=$target" -d '
const allLinks = Array.from(document.querySelectorAll("a[href*=\"user/profile\"]"));
const profileLinks = allLinks.filter(link => {
  const text = link.textContent.trim();
  return text !== "我" && text.length > 5;
});
profileLinks.length > 0 ? profileLinks[0].href : "";
' | jq -r '.value')
  
  if [ -z "$profile_url" ] || [ "$profile_url" = "null" ] || [ "$profile_url" = "" ]; then
    echo "    └─ ⚠️  未找到用户主页链接，跳过"
    continue
  fi
  
  echo "    └─ 主页链接: $profile_url"
  
  # 2.3 导航到用户主页
  echo "  ► 导航到用户主页..."
  curl -s "http://localhost:3456/navigate?target=$target&url=$profile_url" > /dev/null
  sleep 3
  
  # 2.4 提取笔记数据（保留完整URL）
  echo "  ► 提取笔记数据..."
  notes=$(curl -s -X POST "http://localhost:3456/eval?target=$target" -d '
const notes = document.querySelectorAll("section.note-item");
const result = Array.from(notes).slice(0, 15).map((note, index) => {
  const title = note.querySelector(".title");
  const cover = note.querySelector("img");
  const likes = note.querySelector(".like-wrapper .count");
  const link = note.querySelector("a");

  return {
    index: index + 1,
    title: title ? title.textContent.trim() : "",
    cover_url: cover ? cover.src : "",
    likes: likes ? likes.textContent.trim() : "",
    note_url: link ? "https://www.xiaohongshu.com" + link.getAttribute("href") : ""
  };
}).filter(item => item.title && item.title.length > 0);
JSON.stringify(result, null, 2);
' | jq -r '.value')
  
  # 2.5 保存数据
  output_file="${user}_最新笔记.json"
  jq -n \
    --arg user "$user" \
    --arg date "$(date +%Y-%m-%d)" \
    --argjson notes "$notes" \
    '{
      user: {name: $user},
      latest_notes: $notes,
      crawled_at: $date,
      total_count: ($notes | length)
    }' > "$output_file"
  
  count=$(echo "$notes" | jq '. | length')
  echo "    └─ 获取 $count 条笔记，已保存到: $output_file"
  
  # 用户之间间隔
  sleep 1
done

# 3. 关闭所有 tab
echo ""
echo "🧹 清理浏览器 tab..."
for i in "${!USERS[@]}"; do
  user="${USERS[$i]}"
  target=$(cat "$TEMP_DIR/${i}.target")
  curl -s "http://localhost:3456/close?target=$target" > /dev/null
  echo "  ✓ 关闭用户：$user"
done

# 清理临时文件
rm -rf "$TEMP_DIR"

echo ""
echo "======================================"
echo "✅ 全部完成！"
echo "======================================"
for user in "${USERS[@]}"; do
  file="${user}_最新笔记.json"
  if [ -f "$file" ]; then
    count=$(jq '.total_count' "$file")
    top_title=$(jq -r '.latest_notes[0].title' "$file" 2>/dev/null || echo "无")
    top_likes=$(jq -r '.latest_notes[0].likes' "$file" 2>/dev/null || echo "0")
    echo "📊 $user: $count 条 | Top: $top_title ($top_likes 赞)"
  fi
done
