#!/bin/bash
# Claude Code status line
#
# 1 行目: [作業ディレクトリ] モデル名
# 2 行目: コンテキスト使用量 / 上限 | セッションの使用率 | 今週の使用率
#
# ctx の文字色は回答の精度の目安です(緑: 十分 / 黄: 落ち始める / 赤: 下がっている)。
# 黄になる境目は公式の値ではなく、コンテキスト上限に対する割合で決めた目安です。
# 割合は下の SMART_RATIO の既定値(0.4 = 40%)を書き換えて変えます。

SMART_RATIO="${CLAUDE_STATUSLINE_SMART_RATIO:-0.4}"
SEP=$'\x1f'

input=$(cat)

IFS="$SEP" read -r dir model used size pct five five_reset week week_reset over_smart over_80 < <(
  jq -r --argjson r "$SMART_RATIO" '
    def fmt: if . >= 1000000 then ((. / 100000 | floor) / 10 | tostring) + "M"
             elif . >= 1000 then ((. / 1000 | floor) | tostring) + "k"
             else (. | floor | tostring) end;
    def wday: ["日","月","火","水","木","金","土"][strflocaltime("%w") | tonumber];
    (.context_window.total_input_tokens // 0) as $used
    | (.context_window.context_window_size // 0) as $size
    | [
        (.workspace.current_dir // .cwd // ""),
        (.model.display_name // ""),
        ($used | fmt),
        ($size | fmt),
        (.context_window.used_percentage
           // (if $size > 0 then ($used * 100 / $size) else 0 end) | floor),
        (.rate_limits.five_hour.used_percentage // "" | if . == "" then "" else floor end),
        (.rate_limits.five_hour.resets_at // "" | if . == "" then "" else strflocaltime("%H:%M") end),
        (.rate_limits.seven_day.used_percentage // "" | if . == "" then "" else floor end),
        (.rate_limits.seven_day.resets_at // "" | if . == "" then ""
           else strflocaltime("%m/%d ") + wday + strflocaltime(" %H:%M") end),
        ($used >= ($size * $r)),
        ($used >= ($size * 0.8))
      ]
    | map(tostring) | join("\u001f")
  ' <<<"$input" 2>/dev/null
)

# ホームディレクトリ配下は ~ に置き換えて短く表示する
dir="${dir:-$PWD}"
if [ -n "$HOME" ] && { [ "$dir" = "$HOME" ] || [[ "$dir" == "$HOME"/* ]]; }; then
  dir="~${dir#"$HOME"}"
fi

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'; DIM=$'\033[2m'; RESET=$'\033[0m'

# 1 行目
printf '%s[%s]%s %s\n' "$CYAN" "$dir" "$RESET" "$model"

# コンテキスト: 文字色で精度の目安を表す
# SMART_RATIO 未満は緑(十分)、上限 80% 未満は黄(落ち始める)、それ以上は赤(下がっている)
if [ "$over_80" = "true" ]; then ctx_color=$RED
elif [ "$over_smart" = "true" ]; then ctx_color=$YELLOW
else ctx_color=$GREEN; fi

line=$(printf '%sctx %s/%s (%s%%)%s' "$ctx_color" "${used:-0}" "${size:-?}" "${pct:-0}" "$RESET")
# 利用上限の使用率(claude.ai の Pro/Max などのサブスクリプションのときだけ表示される)
# 50% 未満は緑、80% 未満は黄、それ以上は赤
limit_segment() { # $1=ラベル $2=使用率 $3=リセット日時
  [ -n "$2" ] || return 0
  local color=$GREEN
  if [ "$2" -ge 80 ]; then color=$RED
  elif [ "$2" -ge 50 ]; then color=$YELLOW; fi
  printf ' %s|%s %s %s%s%%%s' "$DIM" "$RESET" "$1" "$color" "$2" "$RESET"
  [ -n "$3" ] && printf ' %s(%s)%s' "$DIM" "$3" "$RESET"
  return 0
}

line+=$(limit_segment "セッション" "$five" "$five_reset")
line+=$(limit_segment "今週" "$week" "$week_reset")

printf '%s\n' "$line"
