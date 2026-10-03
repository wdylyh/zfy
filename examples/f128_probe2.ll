declare void @zfy_print_f64(double)
declare i32 @printf(ptr, ...)
@.f = private unnamed_addr constant [5 x i8] c"%d\0A\00"
define i32 @main() {
  %a = alloca fp128
  store fp128 0xL4000921FB54442D1800000000000000, ptr %a
  %i = bitcast fp128 %a... wait
  ret i32 0
}
