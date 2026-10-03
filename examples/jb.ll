@.fmt = private unnamed_addr constant [4 x i8] c"%d\0A\00"
declare i32 @printf(ptr, ...)
declare i32 @zfy_try_setup(ptr) returns_twice

define i32 @main() {
  %h = alloca [512 x i8], align 16
  %r = call i32 @zfy_try_setup(ptr %h) returns_twice
  call i32 (ptr, ...) @printf(ptr @.fmt, i32 %r)
  ret i32 0
}
