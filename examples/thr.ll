@.msg = private unnamed_addr constant [5 x i8] c"boom\00"
declare void @zfy_throw(ptr)
define void @thrower() {
  call void @zfy_throw(ptr @.msg)
  ret void
}
