# Task Pilot - Agentic Skills

<p align="center">
  <a href="README.md">🇬🇧 English</a> ・ <b>🇻🇳 Tiếng Việt</b>
</p>

Quy trình từ ticket đến merge cho coding agent — **Claude Code** và **Cursor**.

Đưa cho nó một ticket Jira, hoặc chỉ cần mô tả việc cần làm bằng văn bản thường
(tiếng Việt hay tiếng Anh đều được), nó sẽ dẫn bạn qua: research → một bản kế
hoạch được duyệt → code → verify → chốt lại thành memory những gì đã ship. Mỗi
bước là một skill riêng, để bạn xem và duyệt giữa các bước thay vì để agent
chạy một mạch dài không kiểm soát.

```
/task-setup   →   /task-intake   →   /task-build   →   /task-submit
  một lần         mỗi ticket        sau khi duyệt      sau khi verify xong
```

Nó cũng wire sẵn các MCP server mà workflow này dựa vào — Jira, Outline,
SonarQube local, Hindsight memory, CodeGraph — và có thể tự kiểm tra bản cập
nhật của chính nó.

## Cài đặt

Chạy ở thư mục gốc của project bạn muốn thêm các skill vào.

**Claude Code:**

```bash
curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh -s -- --client claude
```

**Cursor:**

```bash
curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh -s -- --client cursor
```

**Không chắc, hoặc muốn cả hai?** Bỏ `--client` — installer sẽ tự nhìn vào
project để quyết định:

```bash
curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh
```

| Project đã có | Cài vào |
| --- | --- |
| chỉ `.claude/` | `.claude/` |
| chỉ `.cursor/` | `.cursor/` |
| cả hai | cả hai |
| không có gì | hỏi trên terminal, tạo cái bạn chọn |

Sau đó restart Claude Code (hoặc reload Cursor) — năm slash command bên dưới
sẽ có sẵn.

## Luồng làm việc, theo thứ tự

| Bước | Skill | Khi nào dùng |
| --- | --- | --- |
| 0 | [`/task-setup`](#task-setup) | Một lần cho mỗi máy/repo, trước ticket đầu tiên. Chạy lại chỉ khi cần thêm tool đã bỏ qua. |
| 1 | [`/task-intake`](#task-intake) | Bắt đầu mỗi ticket. Đưa key/link Jira, hoặc mô tả trực tiếp việc cần làm. |
| 2 | [`/task-build`](#task-build) | Sau khi bạn duyệt bản kế hoạch mà `/task-intake` tạo ra. |
| 3 | [`/task-submit`](#task-submit) | Sau khi `/task-build` verify sạch và bạn hài lòng với kết quả. |
| — | [`/task-pilot`](#task-pilot) | Bất cứ lúc nào, không liên quan ticket nào — kiểm tra xem các skill này có bản mới hơn không. |

`/task-setup` và `/task-pilot` nằm ngoài vòng lặp theo ticket. Ba skill còn
lại phải chạy đúng thứ tự đó, mỗi lần một ticket — `/task-build` sẽ từ chối
chạy nếu chưa có plan từ `/task-intake`, và `/task-submit` cần output của
`/task-build`.

### `/task-setup`

Cài và wire: Jira MCP, Outline MCP, SonarQube local (Docker), Hindsight
memory, CodeGraph. Chạy một lần; hỏi bạn muốn setup tool nào nếu không chỉ
định. **Bạn** là người tạo API key / hoàn tất OAuth — nó không bao giờ tự
bịa credential hay commit token.

```
/task-setup                 → hỏi cần cấu hình tool nào
/task-setup jira outline     → chỉ hai cái đó
/task-setup all               → tất cả
```

### `/task-intake`

Giai đoạn research — **không viết code**. Đưa cho nó một ticket key
(`ABC-123`), một link Jira, hoặc một yêu cầu bằng văn bản thường (ngôn ngữ
nào cũng được). Nó đọc ticket (comment, attachment, issue liên kết) hoặc lấy
văn bản của bạn làm spec, kiểm tra git history và các nguồn context đã cấu
hình (Sonar/CodeGraph/Hindsight), rồi kết thúc bằng một bản kế hoạch mà bạn
phải duyệt trước khi bất cứ thứ gì khác xảy ra.

Trước tất cả những việc đó, nó chạy version check của
[`/task-pilot`](#task-pilot) — im lặng nếu bạn đã là bản mới nhất, ngược lại
hỏi trước khi pull update về, rồi vẫn tiếp tục vào phần research ở trên dù
bạn chọn gì.

```
/task-intake ABC-123
/task-intake thêm session invalidation khi đổi role
```

### `/task-build`

Thực thi bản kế hoạch bạn vừa duyệt: viết code, chạy build/lint/unit test và
integration test, chạy Sonar chỉ trên các file mà branch này đã đổi, và báo
cáo đối chiếu với acceptance criteria của ticket. Không bao giờ commit, push,
mở PR, hay ghi vào Jira — những việc đó vẫn là thao tác thủ công, có chủ đích.

```
/task-build
```

### `/task-submit`

Chốt lại ticket đã hoàn thành thành Hindsight memory — **chỉ lưu kết quả**:
function/file nào đã đổi, hiện tại đúng là gì, ai làm. Không bao giờ lưu code
gốc, diff, hay các phương án đã bị loại trong lúc lập kế hoạch. Recall trước,
bỏ qua nếu đã có ghi nhận trùng.

```
/task-submit
```

### `/task-pilot`

Không thuộc vòng lặp ticket — chạy bất cứ lúc nào để kiểm tra xem repo này đã
publish bản skill mới hơn bản đang cài chưa. Im lặng bỏ qua nếu đã là bản mới
nhất; ngược lại báo phiên bản cũ → mới và hỏi trước khi pull về.

```
/task-pilot
```

## Cập nhật

Giống hệt việc kiểm tra: chạy `/task-pilot`. Nó so sánh version đã ghi lúc
cài với file [`VERSION`](VERSION) của repo này, và chỉ cập nhật sau khi bạn
đồng ý.

Muốn bỏ qua bước hỏi và ép cài lại luôn? Chạy lại đúng lệnh cài ban đầu — nó
không hỏi gì, và luôn ghi đè bằng bản mới nhất.

## Tham số của install script

| Tham số | Tác dụng |
| --- | --- |
| `--client claude\|cursor\|both` | Bỏ qua auto-detect, chỉ định luôn. |
| `--dir <path>` | Project cần cài vào. Mặc định: thư mục hiện tại. |
| `--ref <ref>` | Branch, tag, hoặc commit cần cài. Mặc định: `main`. |
| `--dry-run` | In ra những gì sẽ thay đổi, không ghi gì cả. |
| `--uninstall` | Xoá đúng những gì installer đã tạo, không hơn không kém. |
| `--from <path>` | Cài từ một bản checkout local thay vì tải về. |
| `GITHUB_TOKEN` | Gửi kèm làm Bearer token, nếu repo này là private. |

### Nó động vào những gì

Đúng sáu đường dẫn cho mỗi client, và không gì khác:

```
<client>/skills/task-intake
<client>/skills/task-build
<client>/skills/task-submit
<client>/skills/task-setup
<client>/skills/task-pilot
<client>/task-workflow
```

`settings.json`, `mcp.json`, và **bất kỳ skill nào khác của bạn trong cùng
thư mục `skills/` không bao giờ bị đọc, di chuyển, hay xoá** — một guard
trong installer từ chối đụng vào bất kỳ path nào ngoài danh sách trên, và
`--uninstall` cũng đi qua đúng guard đó.

Sáu thư mục này bị *ghi đè* mỗi lần cài, không phải merge, nên một file bị bỏ
ở bản mới sẽ không còn sót lại sau khi cập nhật — nhưng đồng nghĩa là sửa tay
bên trong chúng sẽ bị mất. Chạy `--dry-run` trước nếu bạn đã tự sửa gì ở đây.

`<client>/task-workflow/.source` ghi lại `repo`, `ref`, và `version` đã cài;
`/task-pilot` đọc file này. Một bản cài từ trước khi có version tracking
(không có dòng `version=`) luôn được coi là bản cũ.

## Phát triển

`.claude/` là nguồn duy nhất; chỉ sửa skill ở đó. Bản Cursor được sinh ra lúc
cài bằng cách rewrite tiền tố đường dẫn `.claude/task-workflow/` thành
`.cursor/`.

Test một thay đổi mà không cần push:

```bash
./install.sh --from . --dir /tmp/scratch-repo --client both --dry-run
```

Bump [`VERSION`](VERSION) mỗi khi nội dung một skill thay đổi — đây là phép
so sánh chuỗi thuần với bản đã cài, không phải so sánh semver theo thứ tự,
nên bất kỳ thay đổi nào của file (không cần phải là tăng version) cũng đủ để
`/task-pilot` báo có bản cập nhật.
