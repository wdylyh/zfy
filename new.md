1.变量声明更改
类型 + 后缀 + 名字 + = + 值
类型:
short,short int,int,long int,long long,half,float,double,quad,char,string,bool,ushort,ushort int,uint,ulong int,ulong long
同时！不用删除现在的i32,i64这种。i32,u8,,f64这种宽度也保留。用户自己选用哪一种来声明变量。
以下是他们的对应关系:
short:i8
short int:i16
int:i32
long int:i64
long long:i128
ushort:u8
ushort int:u16
uint:u32
ulong int:u64
ulong long:u128
half:f16
float:f32
double:f64
quad:f128
char:两种类型名字都是char
bool:两种类型名字都是bool
string:两种类型名字都是string
举个例子:
int a=1和i32 a=1等价且都合法
quad const frac unred b=1.2/4.8和f128 const frac unred b=1.2/4.8等价且都合法
后缀:
frac,const,unred
顺序优先级:const>frac>unred。如:quad const frac unred x=12/32.344343434
名字:
不可为关键字,其余没有要求
值:
可以不写，不写默认为0/0.0/‘’/“”/false/……。具体看类型决定。
const:常量
unred:禁止约分。此后缀仅能在有frac后缀下使用。带unred的分数，不可被自动约分，不带的，自动约分
下面是unred的详细示例:
i32 frac unred x=6/48//实际上存内存里就是6/48
i32 frac y=6/48//实际上存内存里是1/8
32 frac unred z//z没给初始值，编译器默认为0/1
i64 frac num
num=x*y//x为6/48,y为1/8,计算后结果为6/384。因为num没unred后缀，所以存进num里是1/64，也就是约到最简
z=x*y//x为6/48,y为1/8,计算后结果为6/384。因为z有unred后缀，所以存进num里是6/384
声明变量可用于顶层。且不限制类型和后缀
for语句中:
for int i=0,i<2,i++
函数参数中:
void f(int a)
struct中:
struct Point
    float x = 0.0
因为frac是后缀，所以frac函数这样写
int frac f(int x)
函数参数里支持const和unred和frac后缀
void f(long long const frac unred x)
数组与列表:
int a[]=1,2//这是列表
double b[]//这是列表
i32 x[23]//这是数组
f128 y[34]=12,23.3434//这是数组
区别在于，数组[]里必须有长度，列表是动态，无须也**不能填**
2.报错体系
错误信息格式:
zfy:error[错误码] in <line> of <文件名> because (原因)
<错误片段>
     ^
其中，错误片段包含错误的那一行和上下各2行，一共5行。
其中，^这个小箭头，指向错误的那个地方。比如一个数字，或者一个单词。如果错误的是单词这种多字符，那么箭头就用多个箭头，像^^^^
其中，错误码格式:EXXX
E代表error这个单词，XXX代表数字。第一个X代表这个错误属于哪个大体系，第二个X代表属于大体系中哪个小体系，第三个X代表具体哪个错误
当然。我并不知道会有哪些错误。所以无法告诉你有哪些错误码和原因。这一点很关键，当你开始制作错误信息格式这里时，请穷举出所有可能错误，并写入一个文档。然后停止任务，我来一一给出每个错误对应的原因和错误码

其中，文件名就是路径。比如../src/a.zfy或者lib/b.zfy或c.zfy这种

多错误报告:报告所有错误
编译器遇到错误后，继续编译，找到所有错误。然后退出。这样就可以配合多错误报告，一次性把所有错误报告完。

