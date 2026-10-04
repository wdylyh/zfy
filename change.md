1.类型更改。
现有的long long ,short,int这些太复杂。
直接改为i32,f64,u8
以下是示例：
i32 a 这是新的变量声明，等价现在的int a
uint后缀删除。因为现在可以直接写u8,u32这种了
const不变，f64 const pi=3.1415926这是新的常量声明，等价现在的double const pi=3.1415926
保留 char 作为独立标量（字符），和 u8 区分。
string 不变，仍是语言级字符串。
array和list删除。这是现在的声明：
i32 a[128]=1,2这是新的数组声明，等价现在的int array a[128]=1,2
f64 b[]这是新的列表声明，是的，他和数组的区分就是列表的中括号内不写长度。等价现在的double list b
f64 b[]=12.1,32.33是的，这个列表声明也是对的。长度是编译器自己判断
注意，列表声明时，中括号内**必须**是空的，不能填长度。
2.异常 + 不可捕获的整数除零，模型不一致这个问题。
解决方案，全用错误值
3.值语义 + 深拷贝，性能模型不清晰这个问题。
解决方案，明确 move 语法
4.新增struct 和指针
一、struct 设计
1.1 声明
text
struct 名字
    类型 字段名 [= 默认值]
    类型 字段名 [= 默认值]
示例：

text
struct Point
    f32 x = 0.0
    f32 y = 0.0

struct Player
    Point pos
    i32 hp = 100
    string name

struct Header
    u8 tag
    i32 value
规则：

struct 关键字，后跟名字，缩进块。

字段：类型 名字，可选 = 默认值。

无默认值的字段填类型零值（整数 0、浮点 0.0、bool false、char '\0'、string ""、列表空、struct 全零）。

字段类型：标量、T[N]、T[]、其他 struct。

struct 只能顶层声明，不支持嵌套定义。

不支持方法、继承、虚函数、访问控制。

1.2 构造
text
Point p = Point(1.0, 2.0)
Point q = Point(x=1.0, y=2.0)
Point r = Point(1.0)              // y 用默认 0.0
Point s                           // 全默认
规则：

位置参数按字段顺序。

命名参数复用现有命名实参机制，位置在前、命名在后。

未给出的字段用默认值或零值。

Point s 合法，全默认。

1.3 访问与赋值
text
p.x = 3.0
f32 a = p.x
p.pos.x = 1.0
点号访问，支持链式。

字段可读可写，除非变量 const。

1.4 const struct
text
Point const origin = Point(0.0, 0.0)
origin.x = 1.0    // 编译错误
const 修饰 struct 变量，所有字段不可写。

和标量 const 规则一致。

1.5 内存布局
默认 C 布局：字段按声明顺序，按对齐填充。

可加 packed：

text
struct packed Header
    u8 tag
    i32 value
sizeof(T) 返回字节数，alignof(T) 返回对齐。

理由：C 互操作必须；用户能算大小；游戏/系统编程需要可预测布局。

1.6 传参与返回
text
void move(Point p, f32 dx, f32 dy)
    p.x += dx
    p.y += dy

Point add(Point a, Point b)
    return Point(a.x + b.x, a.y + b.y)
struct 参数和返回默认值语义（深拷贝）。

小 struct（≤16 字节）按值传寄存器；大 struct 按指针传但语义是值。

想免拷贝用 move：

text
foo(move p)       // 转移，p 不可再用
1.7 数组/列表中的 struct
text
Point arr[4] = Point(1.0,2.0), Point(3.0,4.0)
Point path[] = Point(0.0,0.0), Point(1.0,1.0)
struct 可作数组/列表元素，规则和标量一致。

列表长度由编译器推断。

1.8 与指针配合
text
Point p = Point(1.0, 2.0)
Point* r = &p
r.x = 3.0          // 自动解引用
指针访问字段用点号，自动解引用，不用 ->。

1.9 不支持
方法（用函数）

继承、虚函数、多态

访问控制

嵌套定义

泛型（初期）

匿名 struct

位域（初期）

理由：保持简单，C 互操作友好，单个人能实现。

二、指针设计
2.1 类型语法
text
i32* p
f64* q
Point* r
u8* buf
void* mem
* 紧贴类型，表示“指向该类型的指针”。

void* 通用指针，转其他指针需 cast。

2.2 可变性
text
i32* p              // 可变指针，可变值
i32* const q        // 不可变指针，可变值
const i32* r        // 可变指针，不可变值
const i32* const s  // 不可变指针，不可变值
const 在类型后、名字前，修饰指针本身。

类型前的 const 修饰指向的值。

和标量 const 规则一致。

2.3 取地址与解引用
text
i32 x = 42
i32* p = &x
output(p*)       // 42
p* = 100
output(x)        // 100
&x：取地址。

p*：解引用（后缀星号，避开类型前缀歧义）。

解引用可读可写。

struct 字段自动解引用：

text
Point* r = &p
output(r.x)      // 等价 (*r).x
2.4 空指针
text
i32* p = null
if p != null
    output(p*)
null 关键字，表示空指针。

指针可为 null。

解引用 null 是未定义行为（unsafe 内不检查）。

2.5 指针算术（仅 unsafe）
text
unsafe
    u8* p = buf
    p = p + 1
    p = p - 1
    i64 d = p2 - p1
p + n 移动 n 个元素（按元素大小）。

指针相减返回元素个数（i64）。

安全代码不允许指针算术。

2.6 函数指针
text
type Callback = i32(i32, i32)
Callback* f = &add
i32 r = f(1, 2)
推荐类型别名，可读性好。

也支持 i32(i32, i32)* f 直接写法。

2.7 unsafe 块与 extern "C"
text
unsafe
    void* mem = malloc(1024)
    free(mem)

extern "C"
    void* malloc(u64 size)
    void free(void* p)
    i32 puts(u8* s)
规则：

unsafe 块内允许指针算术、null 解引用、类型双关。

extern "C" 声明 C 函数，调用隐含 unsafe。

extern "C" 内签名用 C 类型映射（见 2.11）。

C 结构体用默认 C 布局 struct 映射，紧凑布局用 struct packed。

2.8 安全与 unsafe 的边界
安全代码：

不用裸指针

用数组/列表/struct/string 值语义

越界有检查

错误值可处理

unsafe 代码：

裸指针

手动 malloc/free

指针算术

类型双关

调用 C 函数

越界不检查

错误不可捕获（段错误）

规则：

裸指针类型只能出现在 unsafe 块或 extern "C" 声明中。

安全代码想用指针，必须显式 unsafe。

给你 C 的能力，但不污染安全代码。

2.9 指针与数组/列表
text
i32 arr[10]
i32* p = &arr[0]     // 指向首元素
i32* q = &arr[3]     // 指向第 4 个元素
数组/列表不自动退化为指针。

需要指针时显式 &arr[i]。

C 互操作时，&arr[0] 传数组首地址。

2.10 指针与 struct
text
Point p = Point(1.0, 2.0)
Point* r = &p
output(r.x)          // 自动解引用
r.x = 3.0
指针访问字段用点号，自动解引用，不用 ->。

和 Rust/Go 一致，比 C 简洁。
