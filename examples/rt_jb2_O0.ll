; ModuleID = 'd:\zfy\examples\rt_jb2.c'
source_filename = "d:\\zfy\\examples\\rt_jb2.c"
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-w64-windows-gnu"

%struct.zfy_handler = type { [16 x %struct._SETJMP_FLOAT128], ptr, ptr }
%struct._SETJMP_FLOAT128 = type { [2 x i64] }

@top = internal global ptr null, align 8
@.str = private unnamed_addr constant [12 x i8] c"caught: %s\0A\00", align 1
@.str.1 = private unnamed_addr constant [8 x i8] c"before\0A\00", align 1
@.str.2 = private unnamed_addr constant [5 x i8] c"boom\00", align 1

; Function Attrs: noinline nounwind optnone returns_twice uwtable
define dso_local i32 @zfy_try_setup(ptr noundef %0) #0 {
  %2 = alloca ptr, align 8
  store ptr %0, ptr %2, align 8
  %3 = load ptr, ptr %2, align 8
  %4 = getelementptr inbounds %struct.zfy_handler, ptr %3, i32 0, i32 1
  store ptr null, ptr %4, align 16
  %5 = load ptr, ptr @top, align 8
  %6 = load ptr, ptr %2, align 8
  %7 = getelementptr inbounds %struct.zfy_handler, ptr %6, i32 0, i32 2
  store ptr %5, ptr %7, align 8
  %8 = load ptr, ptr %2, align 8
  store ptr %8, ptr @top, align 8
  %9 = load ptr, ptr %2, align 8
  %10 = getelementptr inbounds %struct.zfy_handler, ptr %9, i32 0, i32 0
  %11 = getelementptr inbounds [16 x %struct._SETJMP_FLOAT128], ptr %10, i64 0, i64 0
  %12 = call ptr @llvm.frameaddress.p0(i32 0)
  %13 = call i32 @_setjmp(ptr noundef %11, ptr noundef %12) #6
  ret i32 %13
}

; Function Attrs: nounwind returns_twice
declare dllimport i32 @_setjmp(ptr noundef, ptr noundef) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare ptr @llvm.frameaddress.p0(i32 immarg) #2

; Function Attrs: noinline nounwind optnone uwtable
define dso_local void @do_throw(ptr noundef %0) #3 {
  %2 = alloca ptr, align 8
  store ptr %0, ptr %2, align 8
  %3 = load ptr, ptr %2, align 8
  %4 = load ptr, ptr @top, align 8
  %5 = getelementptr inbounds %struct.zfy_handler, ptr %4, i32 0, i32 1
  store ptr %3, ptr %5, align 16
  %6 = load ptr, ptr @top, align 8
  %7 = getelementptr inbounds %struct.zfy_handler, ptr %6, i32 0, i32 0
  %8 = getelementptr inbounds [16 x %struct._SETJMP_FLOAT128], ptr %7, i64 0, i64 0
  call void @longjmp(ptr noundef %8, i32 noundef 1) #7
  unreachable
}

; Function Attrs: noreturn nounwind
declare dllimport void @longjmp(ptr noundef, i32 noundef) #4

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @main() #3 {
  %1 = alloca i32, align 4
  %2 = alloca %struct.zfy_handler, align 16
  %3 = alloca i32, align 4
  store i32 0, ptr %1, align 4
  %4 = call i32 @zfy_try_setup(ptr noundef %2) #8
  store i32 %4, ptr %3, align 4
  %5 = load i32, ptr %3, align 4
  %6 = icmp ne i32 %5, 0
  br i1 %6, label %7, label %11

7:                                                ; preds = %0
  %8 = getelementptr inbounds %struct.zfy_handler, ptr %2, i32 0, i32 1
  %9 = load ptr, ptr %8, align 16
  %10 = call i32 (ptr, ...) @printf(ptr noundef @.str, ptr noundef %9)
  store i32 0, ptr %1, align 4
  br label %15

11:                                               ; preds = %0
  %12 = call i32 (ptr, ...) @printf(ptr noundef @.str.1)
  %13 = call ptr @__acrt_iob_func(i32 noundef 1)
  %14 = call i32 @fflush(ptr noundef %13)
  call void @do_throw(ptr noundef @.str.2)
  store i32 1, ptr %1, align 4
  br label %15

15:                                               ; preds = %11, %7
  %16 = load i32, ptr %1, align 4
  ret i32 %16
}

declare dso_local i32 @printf(ptr noundef, ...) #5

declare dso_local i32 @fflush(ptr noundef) #5

declare dllimport ptr @__acrt_iob_func(i32 noundef) #5

attributes #0 = { noinline nounwind optnone returns_twice uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nounwind returns_twice "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(none) }
attributes #3 = { noinline nounwind optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #5 = { "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #6 = { nounwind returns_twice }
attributes #7 = { noreturn nounwind }
attributes #8 = { returns_twice }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 2}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 2}
!3 = !{i32 1, !"MaxTLSAlign", i32 65536}
!4 = !{!"clang version 18.1.8"}
