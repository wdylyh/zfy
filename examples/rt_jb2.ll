; ModuleID = 'd:\zfy\examples\rt_jb2.c'
source_filename = "d:\\zfy\\examples\\rt_jb2.c"
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-w64-windows-gnu"

%struct.zfy_handler = type { [16 x %struct._SETJMP_FLOAT128], ptr, ptr }
%struct._SETJMP_FLOAT128 = type { [2 x i64] }

@top = internal unnamed_addr global ptr null, align 8
@.str = private unnamed_addr constant [12 x i8] c"caught: %s\0A\00", align 1
@.str.2 = private unnamed_addr constant [5 x i8] c"boom\00", align 1
@str = private unnamed_addr constant [7 x i8] c"before\00", align 1

; Function Attrs: nounwind returns_twice uwtable
define dso_local i32 @zfy_try_setup(ptr noundef %0) local_unnamed_addr #0 {
  %2 = getelementptr inbounds %struct.zfy_handler, ptr %0, i64 0, i32 1
  store ptr null, ptr %2, align 16, !tbaa !5
  %3 = load ptr, ptr @top, align 8, !tbaa !10
  %4 = getelementptr inbounds %struct.zfy_handler, ptr %0, i64 0, i32 2
  store ptr %3, ptr %4, align 8, !tbaa !11
  store ptr %0, ptr @top, align 8, !tbaa !10
  %5 = call ptr @llvm.frameaddress.p0(i32 0)
  %6 = call i32 @_setjmp(ptr noundef %0, ptr noundef %5) #10
  ret i32 %6
}

; Function Attrs: nounwind returns_twice
declare dllimport i32 @_setjmp(ptr noundef, ptr noundef) local_unnamed_addr #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(none)
declare ptr @llvm.frameaddress.p0(i32 immarg) #2

; Function Attrs: noinline noreturn nounwind uwtable
define dso_local void @do_throw(ptr noundef %0) local_unnamed_addr #3 {
  %2 = load ptr, ptr @top, align 8, !tbaa !10
  %3 = getelementptr inbounds %struct.zfy_handler, ptr %2, i64 0, i32 1
  store ptr %0, ptr %3, align 16, !tbaa !5
  tail call void @longjmp(ptr noundef %2, i32 noundef 1) #11
  unreachable
}

; Function Attrs: noreturn nounwind
declare dllimport void @longjmp(ptr noundef, i32 noundef) local_unnamed_addr #4

; Function Attrs: nounwind uwtable
define dso_local noundef i32 @main() local_unnamed_addr #5 {
  %1 = alloca %struct.zfy_handler, align 16
  call void @llvm.lifetime.start.p0(i64 272, ptr nonnull %1) #12
  %2 = getelementptr inbounds %struct.zfy_handler, ptr %1, i64 0, i32 1
  store ptr null, ptr %2, align 16, !tbaa !5
  %3 = load ptr, ptr @top, align 8, !tbaa !10
  %4 = getelementptr inbounds %struct.zfy_handler, ptr %1, i64 0, i32 2
  store ptr %3, ptr %4, align 8, !tbaa !11
  store ptr %1, ptr @top, align 8, !tbaa !10
  %5 = call ptr @llvm.frameaddress.p0(i32 0)
  %6 = call i32 @_setjmp(ptr noundef nonnull %1, ptr noundef %5) #10
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %11, label %8

8:                                                ; preds = %0
  %9 = load ptr, ptr %2, align 16, !tbaa !5
  %10 = call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str, ptr noundef %9)
  call void @llvm.lifetime.end.p0(i64 272, ptr nonnull %1) #12
  ret i32 0

11:                                               ; preds = %0
  %12 = call i32 @puts(ptr nonnull dereferenceable(1) @str)
  %13 = call ptr @__acrt_iob_func(i32 noundef 1) #12
  %14 = call i32 @fflush(ptr noundef %13)
  call void @do_throw(ptr noundef nonnull @.str.2)
  unreachable
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #6

; Function Attrs: nofree nounwind
declare dso_local noundef i32 @printf(ptr nocapture noundef readonly, ...) local_unnamed_addr #7

; Function Attrs: nofree nounwind
declare dso_local noundef i32 @fflush(ptr nocapture noundef) local_unnamed_addr #7

declare dllimport ptr @__acrt_iob_func(i32 noundef) local_unnamed_addr #8

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #6

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr nocapture noundef readonly) local_unnamed_addr #9

attributes #0 = { nounwind returns_twice uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nounwind returns_twice "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #2 = { mustprogress nocallback nofree nosync nounwind willreturn memory(none) }
attributes #3 = { noinline noreturn nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #5 = { nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #6 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #7 = { nofree nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #8 = { "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #9 = { nofree nounwind }
attributes #10 = { nounwind returns_twice }
attributes #11 = { noreturn nounwind }
attributes #12 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 2}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 2}
!3 = !{i32 1, !"MaxTLSAlign", i32 65536}
!4 = !{!"clang version 18.1.8"}
!5 = !{!6, !9, i64 256}
!6 = !{!"zfy_handler", !7, i64 0, !9, i64 256, !9, i64 264}
!7 = !{!"omnipotent char", !8, i64 0}
!8 = !{!"Simple C/C++ TBAA"}
!9 = !{!"any pointer", !7, i64 0}
!10 = !{!9, !9, i64 0}
!11 = !{!6, !9, i64 264}
