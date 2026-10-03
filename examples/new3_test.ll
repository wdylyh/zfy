%frac.i8 = type { i8, i8 }
%frac.i16 = type { i16, i16 }
%frac.i32 = type { i32, i32 }
%frac.i64 = type { i64, i64 }
%frac.i128 = type { i128, i128 }
%frac.u8 = type { i8, i8 }
%frac.u16 = type { i16, i16 }
%frac.u32 = type { i32, i32 }
%frac.u64 = type { i64, i64 }
%frac.u128 = type { i128, i128 }
%frac.f32 = type { float, float }
%frac.f64 = type { double, double }
%zfy.seq = type { ptr, ptr, i64 }
declare i64 @strlen(ptr)
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)
declare void @zfy_print_str(ptr)
declare void @zfy_print_i64(i64)
declare void @zfy_print_u64(i64)
declare void @zfy_print_i128(i128)
declare void @zfy_print_u128(i128)
declare void @zfy_print_f64(double)
declare void @zfy_print_char(i8)
declare void @zfy_print_bool(i32)
declare void @zfy_free_str(ptr)
declare ptr @zfy_strdup(ptr)
declare ptr @zfy_tostr_char(i8)
declare ptr @zfy_tostr_bool(i32)
declare ptr @zfy_tostr_i64(i64)
declare ptr @zfy_tostr_u64(i64)
declare ptr @zfy_tostr_i128(i128)
declare ptr @zfy_tostr_u128(i128)
declare ptr @zfy_tostr_f64(double)
declare ptr @zfy_prec_str(ptr, i64)
declare i64 @zfy_char_digit(i8)
declare i64 @zfy_stoi(ptr)
declare double @zfy_stod(ptr)
declare void @zfy_input_str(ptr, ptr)
declare void @zfy_input_i64(ptr, ptr)
declare void @zfy_input_i128(ptr, ptr)
declare void @zfy_input_u128(ptr, ptr)
declare void @zfy_input_f64(ptr, ptr, i32)
declare void @zfy_input_bool(ptr, ptr)
declare void @zfy_input_char(ptr, ptr)
declare ptr @zfy_seq_new(i64, i64, i32)
declare void @zfy_seq_set_w(ptr, i64, ptr, i32, i8)
declare void @zfy_seq_set_str(ptr, i64, ptr, i8)
declare void @zfy_seq_get(ptr, i64, ptr, i32, i8)
declare void @zfy_bounds_fail()
declare void @zfy_seq_free(ptr, i8)
declare ptr @zfy_seq_clone(ptr, i8)
declare i8 @zfy_str_char(ptr, i64)
declare ptr @zfy_str_slice(ptr, i64, i64, i64)
declare i64 @zfy_str_find(ptr, i8, i64)
declare ptr @zfy_str_trim(ptr, i8)
declare ptr @zfy_str_trim_str(ptr, ptr)
declare ptr @zfy_str_replace(ptr, i64, i64, ptr)
declare ptr @zfy_str_replace_from(ptr, i64, ptr)
declare ptr @zfy_str_concat(ptr, ptr)
declare ptr @zfy_str_split(ptr, i8)
declare ptr @zfy_str_split_str(ptr, ptr)
declare ptr @zfy_seq_slice(ptr, i64, i64, i64, i8)
declare void @zfy_frac_add_i8(ptr sret(%frac.i8), ptr, ptr)
declare void @zfy_frac_sub_i8(ptr sret(%frac.i8), ptr, ptr)
declare void @zfy_frac_mul_i8(ptr sret(%frac.i8), ptr, ptr)
declare void @zfy_frac_div_i8(ptr sret(%frac.i8), ptr, ptr)
declare i1 @zfy_frac_eq_i8(ptr, ptr)
declare i1 @zfy_frac_ne_i8(ptr, ptr)
declare i1 @zfy_frac_lt_i8(ptr, ptr)
declare i1 @zfy_frac_gt_i8(ptr, ptr)
declare i1 @zfy_frac_le_i8(ptr, ptr)
declare i1 @zfy_frac_ge_i8(ptr, ptr)
declare void @zfy_frac_reduce_i8(ptr, i64, i64)
declare void @zfy_frac_norm_i8(ptr)
declare void @zfy_frac_print_i8(ptr)
declare ptr @zfy_frac_str_i8(ptr)
declare void @zfy_frac_add_i16(ptr sret(%frac.i16), ptr, ptr)
declare void @zfy_frac_sub_i16(ptr sret(%frac.i16), ptr, ptr)
declare void @zfy_frac_mul_i16(ptr sret(%frac.i16), ptr, ptr)
declare void @zfy_frac_div_i16(ptr sret(%frac.i16), ptr, ptr)
declare i1 @zfy_frac_eq_i16(ptr, ptr)
declare i1 @zfy_frac_ne_i16(ptr, ptr)
declare i1 @zfy_frac_lt_i16(ptr, ptr)
declare i1 @zfy_frac_gt_i16(ptr, ptr)
declare i1 @zfy_frac_le_i16(ptr, ptr)
declare i1 @zfy_frac_ge_i16(ptr, ptr)
declare void @zfy_frac_reduce_i16(ptr, i64, i64)
declare void @zfy_frac_norm_i16(ptr)
declare void @zfy_frac_print_i16(ptr)
declare ptr @zfy_frac_str_i16(ptr)
declare void @zfy_frac_add_i32(ptr sret(%frac.i32), ptr, ptr)
declare void @zfy_frac_sub_i32(ptr sret(%frac.i32), ptr, ptr)
declare void @zfy_frac_mul_i32(ptr sret(%frac.i32), ptr, ptr)
declare void @zfy_frac_div_i32(ptr sret(%frac.i32), ptr, ptr)
declare i1 @zfy_frac_eq_i32(ptr, ptr)
declare i1 @zfy_frac_ne_i32(ptr, ptr)
declare i1 @zfy_frac_lt_i32(ptr, ptr)
declare i1 @zfy_frac_gt_i32(ptr, ptr)
declare i1 @zfy_frac_le_i32(ptr, ptr)
declare i1 @zfy_frac_ge_i32(ptr, ptr)
declare void @zfy_frac_reduce_i32(ptr, i64, i64)
declare void @zfy_frac_norm_i32(ptr)
declare void @zfy_frac_print_i32(ptr)
declare ptr @zfy_frac_str_i32(ptr)
declare void @zfy_frac_add_i64(ptr sret(%frac.i64), ptr, ptr)
declare void @zfy_frac_sub_i64(ptr sret(%frac.i64), ptr, ptr)
declare void @zfy_frac_mul_i64(ptr sret(%frac.i64), ptr, ptr)
declare void @zfy_frac_div_i64(ptr sret(%frac.i64), ptr, ptr)
declare i1 @zfy_frac_eq_i64(ptr, ptr)
declare i1 @zfy_frac_ne_i64(ptr, ptr)
declare i1 @zfy_frac_lt_i64(ptr, ptr)
declare i1 @zfy_frac_gt_i64(ptr, ptr)
declare i1 @zfy_frac_le_i64(ptr, ptr)
declare i1 @zfy_frac_ge_i64(ptr, ptr)
declare void @zfy_frac_reduce_i64(ptr, i64, i64)
declare void @zfy_frac_norm_i64(ptr)
declare void @zfy_frac_print_i64(ptr)
declare ptr @zfy_frac_str_i64(ptr)
declare void @zfy_frac_add_i128(ptr sret(%frac.i128), ptr, ptr)
declare void @zfy_frac_sub_i128(ptr sret(%frac.i128), ptr, ptr)
declare void @zfy_frac_mul_i128(ptr sret(%frac.i128), ptr, ptr)
declare void @zfy_frac_div_i128(ptr sret(%frac.i128), ptr, ptr)
declare i1 @zfy_frac_eq_i128(ptr, ptr)
declare i1 @zfy_frac_ne_i128(ptr, ptr)
declare i1 @zfy_frac_lt_i128(ptr, ptr)
declare i1 @zfy_frac_gt_i128(ptr, ptr)
declare i1 @zfy_frac_le_i128(ptr, ptr)
declare i1 @zfy_frac_ge_i128(ptr, ptr)
declare void @zfy_frac_reduce_i128(ptr, i64, i64)
declare void @zfy_frac_norm_i128(ptr)
declare void @zfy_frac_print_i128(ptr)
declare ptr @zfy_frac_str_i128(ptr)
declare void @zfy_frac_add_u8(ptr sret(%frac.u8), ptr, ptr)
declare void @zfy_frac_sub_u8(ptr sret(%frac.u8), ptr, ptr)
declare void @zfy_frac_mul_u8(ptr sret(%frac.u8), ptr, ptr)
declare void @zfy_frac_div_u8(ptr sret(%frac.u8), ptr, ptr)
declare i1 @zfy_frac_eq_u8(ptr, ptr)
declare i1 @zfy_frac_ne_u8(ptr, ptr)
declare i1 @zfy_frac_lt_u8(ptr, ptr)
declare i1 @zfy_frac_gt_u8(ptr, ptr)
declare i1 @zfy_frac_le_u8(ptr, ptr)
declare i1 @zfy_frac_ge_u8(ptr, ptr)
declare void @zfy_frac_reduce_u8(ptr, i64, i64)
declare void @zfy_frac_norm_u8(ptr)
declare void @zfy_frac_print_u8(ptr)
declare ptr @zfy_frac_str_u8(ptr)
declare void @zfy_frac_add_u16(ptr sret(%frac.u16), ptr, ptr)
declare void @zfy_frac_sub_u16(ptr sret(%frac.u16), ptr, ptr)
declare void @zfy_frac_mul_u16(ptr sret(%frac.u16), ptr, ptr)
declare void @zfy_frac_div_u16(ptr sret(%frac.u16), ptr, ptr)
declare i1 @zfy_frac_eq_u16(ptr, ptr)
declare i1 @zfy_frac_ne_u16(ptr, ptr)
declare i1 @zfy_frac_lt_u16(ptr, ptr)
declare i1 @zfy_frac_gt_u16(ptr, ptr)
declare i1 @zfy_frac_le_u16(ptr, ptr)
declare i1 @zfy_frac_ge_u16(ptr, ptr)
declare void @zfy_frac_reduce_u16(ptr, i64, i64)
declare void @zfy_frac_norm_u16(ptr)
declare void @zfy_frac_print_u16(ptr)
declare ptr @zfy_frac_str_u16(ptr)
declare void @zfy_frac_add_u32(ptr sret(%frac.u32), ptr, ptr)
declare void @zfy_frac_sub_u32(ptr sret(%frac.u32), ptr, ptr)
declare void @zfy_frac_mul_u32(ptr sret(%frac.u32), ptr, ptr)
declare void @zfy_frac_div_u32(ptr sret(%frac.u32), ptr, ptr)
declare i1 @zfy_frac_eq_u32(ptr, ptr)
declare i1 @zfy_frac_ne_u32(ptr, ptr)
declare i1 @zfy_frac_lt_u32(ptr, ptr)
declare i1 @zfy_frac_gt_u32(ptr, ptr)
declare i1 @zfy_frac_le_u32(ptr, ptr)
declare i1 @zfy_frac_ge_u32(ptr, ptr)
declare void @zfy_frac_reduce_u32(ptr, i64, i64)
declare void @zfy_frac_norm_u32(ptr)
declare void @zfy_frac_print_u32(ptr)
declare ptr @zfy_frac_str_u32(ptr)
declare void @zfy_frac_add_u64(ptr sret(%frac.u64), ptr, ptr)
declare void @zfy_frac_sub_u64(ptr sret(%frac.u64), ptr, ptr)
declare void @zfy_frac_mul_u64(ptr sret(%frac.u64), ptr, ptr)
declare void @zfy_frac_div_u64(ptr sret(%frac.u64), ptr, ptr)
declare i1 @zfy_frac_eq_u64(ptr, ptr)
declare i1 @zfy_frac_ne_u64(ptr, ptr)
declare i1 @zfy_frac_lt_u64(ptr, ptr)
declare i1 @zfy_frac_gt_u64(ptr, ptr)
declare i1 @zfy_frac_le_u64(ptr, ptr)
declare i1 @zfy_frac_ge_u64(ptr, ptr)
declare void @zfy_frac_reduce_u64(ptr, i64, i64)
declare void @zfy_frac_norm_u64(ptr)
declare void @zfy_frac_print_u64(ptr)
declare ptr @zfy_frac_str_u64(ptr)
declare void @zfy_frac_add_u128(ptr sret(%frac.u128), ptr, ptr)
declare void @zfy_frac_sub_u128(ptr sret(%frac.u128), ptr, ptr)
declare void @zfy_frac_mul_u128(ptr sret(%frac.u128), ptr, ptr)
declare void @zfy_frac_div_u128(ptr sret(%frac.u128), ptr, ptr)
declare i1 @zfy_frac_eq_u128(ptr, ptr)
declare i1 @zfy_frac_ne_u128(ptr, ptr)
declare i1 @zfy_frac_lt_u128(ptr, ptr)
declare i1 @zfy_frac_gt_u128(ptr, ptr)
declare i1 @zfy_frac_le_u128(ptr, ptr)
declare i1 @zfy_frac_ge_u128(ptr, ptr)
declare void @zfy_frac_reduce_u128(ptr, i64, i64)
declare void @zfy_frac_norm_u128(ptr)
declare void @zfy_frac_print_u128(ptr)
declare ptr @zfy_frac_str_u128(ptr)
declare void @zfy_frac_add_f32(ptr sret(%frac.f32), ptr, ptr)
declare void @zfy_frac_sub_f32(ptr sret(%frac.f32), ptr, ptr)
declare void @zfy_frac_mul_f32(ptr sret(%frac.f32), ptr, ptr)
declare void @zfy_frac_div_f32(ptr sret(%frac.f32), ptr, ptr)
declare i1 @zfy_frac_eq_f32(ptr, ptr)
declare i1 @zfy_frac_ne_f32(ptr, ptr)
declare i1 @zfy_frac_lt_f32(ptr, ptr)
declare i1 @zfy_frac_gt_f32(ptr, ptr)
declare i1 @zfy_frac_le_f32(ptr, ptr)
declare i1 @zfy_frac_ge_f32(ptr, ptr)
declare void @zfy_frac_reduce_f32(ptr, i64, i64)
declare void @zfy_frac_norm_f32(ptr)
declare void @zfy_frac_print_f32(ptr)
declare ptr @zfy_frac_str_f32(ptr)
declare void @zfy_frac_add_f64(ptr sret(%frac.f64), ptr, ptr)
declare void @zfy_frac_sub_f64(ptr sret(%frac.f64), ptr, ptr)
declare void @zfy_frac_mul_f64(ptr sret(%frac.f64), ptr, ptr)
declare void @zfy_frac_div_f64(ptr sret(%frac.f64), ptr, ptr)
declare i1 @zfy_frac_eq_f64(ptr, ptr)
declare i1 @zfy_frac_ne_f64(ptr, ptr)
declare i1 @zfy_frac_lt_f64(ptr, ptr)
declare i1 @zfy_frac_gt_f64(ptr, ptr)
declare i1 @zfy_frac_le_f64(ptr, ptr)
declare i1 @zfy_frac_ge_f64(ptr, ptr)
declare void @zfy_frac_reduce_f64(ptr, i64, i64)
declare void @zfy_frac_norm_f64(ptr)
declare void @zfy_frac_print_f64(ptr)
declare ptr @zfy_frac_str_f64(ptr)
declare void @zfy_seq_zero(ptr, i64, i8)
declare void @zfy_seq_remove(ptr, i64, i8)
declare void @zfy_seq_aug_range(ptr, i64, i64, i64, i32, ptr, i32, i32, i32)
@.str1 = private unnamed_addr constant [1 x i8] c"\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [1 x i8] c"\00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [1 x i8] c"\00"
@.str12 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str13 = private unnamed_addr constant [1 x i8] c"\00"
@.str14 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str15 = private unnamed_addr constant [1 x i8] c"\00"
@.str16 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str17 = private unnamed_addr constant [8 x i8] c"A\09B\0BC\07D\00"
@.str18 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str19 = private unnamed_addr constant [6 x i8] c"hello\00"
@.str20 = private unnamed_addr constant [1 x i8] c"\00"
@.str21 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str22 = private unnamed_addr constant [4 x i8] c"abc\00"
@.str23 = private unnamed_addr constant [1 x i8] c"\00"
@.str24 = private unnamed_addr constant [1 x i8] c"\00"
@.str25 = private unnamed_addr constant [1 x i8] c"\00"
@.str26 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str27 = private unnamed_addr constant [1 x i8] c"\00"
@.str28 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str29 = private unnamed_addr constant [1 x i8] c"\00"
@.str30 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str31 = private unnamed_addr constant [4 x i8] c"123\00"
@.str32 = private unnamed_addr constant [4 x i8] c"xyz\00"
@.str33 = private unnamed_addr constant [1 x i8] c"\00"
@.str34 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.ib = alloca ptr
  %v.ia = alloca ptr
  %v.s2 = alloca ptr
  %v.s1 = alloca ptr
  %v.carr = alloca ptr
  %v.k = alloca i64
  %v.one = alloca ptr
  %v.s0 = alloca ptr
  %v.pos = alloca i64
  %v.pi$1 = alloca i32
  %v.pi = alloca double
  %v.sb = alloca ptr
  %v.sa = alloca ptr
  %v.m = alloca i64
  %v.lst = alloca ptr
  %v.arr = alloca ptr
  %v.c = alloca %frac.i32
  %v.ur2 = alloca %frac.i32
  %v.a = alloca %frac.i32
  %v.ur = alloca %frac.i32
  %r3 = alloca %frac.i32
  %r10 = alloca %frac.i32
  %r17 = alloca %frac.i32
  %r20 = alloca %frac.i32
  %r105 = alloca i128
  %r109 = alloca i128
  %r113 = alloca i128
  %r117 = alloca i128
  %r223 = alloca i128
  %r352 = alloca i128
  %r414 = alloca i128
  store ptr null, ptr %v.ib
  store ptr null, ptr %v.ia
  store ptr null, ptr %v.s2
  store ptr null, ptr %v.s1
  store ptr null, ptr %v.carr
  store i64 zeroinitializer, ptr %v.k
  store ptr null, ptr %v.one
  store ptr null, ptr %v.s0
  store i64 zeroinitializer, ptr %v.pos
  store i32 zeroinitializer, ptr %v.pi$1
  store double zeroinitializer, ptr %v.pi
  store ptr null, ptr %v.sb
  store ptr null, ptr %v.sa
  store i64 zeroinitializer, ptr %v.m
  store ptr null, ptr %v.lst
  store ptr null, ptr %v.arr
  store %frac.i32 zeroinitializer, ptr %v.c
  store %frac.i32 zeroinitializer, ptr %v.ur2
  store %frac.i32 zeroinitializer, ptr %v.a
  store %frac.i32 zeroinitializer, ptr %v.ur
  %r1 = trunc i64 6 to i32
  %r2 = trunc i64 48 to i32
  %r4 = getelementptr inbounds %frac.i32, ptr %r3, i32 0, i32 0
  store i32 %r1, ptr %r4
  %r5 = getelementptr inbounds %frac.i32, ptr %r3, i32 0, i32 1
  store i32 %r2, ptr %r5
  call void @llvm.memcpy.p0.p0.i64(ptr %v.ur, ptr %r3, i64 8, i1 false)
  call void @zfy_frac_print_i32(ptr %v.ur)
  %t4 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t4)
  call void @zfy_free_str(ptr %t4)
  %r6 = getelementptr inbounds [1 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r6)
  %r7 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r7)
  %r8 = trunc i64 6 to i32
  %r9 = trunc i64 48 to i32
  %r11 = getelementptr inbounds %frac.i32, ptr %r10, i32 0, i32 0
  store i32 %r8, ptr %r11
  %r12 = getelementptr inbounds %frac.i32, ptr %r10, i32 0, i32 1
  store i32 %r9, ptr %r12
  call void @llvm.memcpy.p0.p0.i64(ptr %v.a, ptr %r10, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.a)
  call void @zfy_frac_print_i32(ptr %v.a)
  %t8 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t8)
  call void @zfy_free_str(ptr %t8)
  %r13 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r13)
  %r14 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r14)
  %r15 = trunc i64 2 to i32
  %r16 = trunc i64 4 to i32
  %r18 = getelementptr inbounds %frac.i32, ptr %r17, i32 0, i32 0
  store i32 %r15, ptr %r18
  %r19 = getelementptr inbounds %frac.i32, ptr %r17, i32 0, i32 1
  store i32 %r16, ptr %r19
  call void @llvm.memcpy.p0.p0.i64(ptr %v.ur2, ptr %r17, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.ur2)
  call void @zfy_frac_mul_i32(ptr %r20, ptr %v.ur, ptr %v.ur2)
  call void @llvm.memcpy.p0.p0.i64(ptr %v.c, ptr %r20, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.c)
  call void @zfy_frac_print_i32(ptr %v.c)
  %t13 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t13)
  call void @zfy_free_str(ptr %t13)
  %r21 = getelementptr inbounds [1 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r21)
  %r22 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r22)
  %r23 = call ptr @zfy_seq_new(i64 5, i64 5, i32 8)
  store ptr %r23, ptr %v.arr
  %r24 = load ptr, ptr %v.arr
  %r25 = getelementptr inbounds %zfy.seq, ptr %r24, i32 0, i32 2
  %r26 = load i64, ptr %r25
  %r27 = icmp ult i64 0, %r26
  br i1 %r27, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r28 = load ptr, ptr %r24
  %r29 = mul i64 0, 8
  %r30 = getelementptr inbounds i8, ptr %r28, i64 %r29
  %r31 = sext i64 1 to i128
  %r32 = trunc i128 %r31 to i64
  store i64 %r32, ptr %r30, align 1
  br label %L3
L3:
  %r33 = load ptr, ptr %v.arr
  %r34 = getelementptr inbounds %zfy.seq, ptr %r33, i32 0, i32 2
  %r35 = load i64, ptr %r34
  %r36 = icmp ult i64 1, %r35
  br i1 %r36, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r37 = load ptr, ptr %r33
  %r38 = mul i64 1, 8
  %r39 = getelementptr inbounds i8, ptr %r37, i64 %r38
  %r40 = sext i64 2 to i128
  %r41 = trunc i128 %r40 to i64
  store i64 %r41, ptr %r39, align 1
  br label %L6
L6:
  %r42 = load ptr, ptr %v.arr
  %r43 = getelementptr inbounds %zfy.seq, ptr %r42, i32 0, i32 2
  %r44 = load i64, ptr %r43
  %r45 = icmp ult i64 2, %r44
  br i1 %r45, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r46 = load ptr, ptr %r42
  %r47 = mul i64 2, 8
  %r48 = getelementptr inbounds i8, ptr %r46, i64 %r47
  %r49 = sext i64 3 to i128
  %r50 = trunc i128 %r49 to i64
  store i64 %r50, ptr %r48, align 1
  br label %L9
L9:
  %r51 = add i64 1, 0
  %r52 = load ptr, ptr %v.arr
  call void @zfy_seq_zero(ptr %r52, i64 %r51, i8 0)
  %r53 = add i64 0, 0
  %r54 = load ptr, ptr %v.arr
  %r55 = getelementptr inbounds %zfy.seq, ptr %r54, i32 0, i32 2
  %r56 = load i64, ptr %r55
  %r57 = icmp ult i64 %r53, %r56
  br i1 %r57, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r58 = load ptr, ptr %r54
  %r59 = mul i64 %r53, 8
  %r60 = getelementptr inbounds i8, ptr %r58, i64 %r59
  %r61 = load i64, ptr %r60, align 1
  %r62 = sext i64 %r61 to i128
  br label %L12
L12:
  %r63 = trunc i128 %r62 to i64
  call void @zfy_print_i64(i64 %r63)
  %t17 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t17)
  %r64 = add i64 1, 0
  %r65 = load ptr, ptr %v.arr
  %r66 = getelementptr inbounds %zfy.seq, ptr %r65, i32 0, i32 2
  %r67 = load i64, ptr %r66
  %r68 = icmp ult i64 %r64, %r67
  br i1 %r68, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r69 = load ptr, ptr %r65
  %r70 = mul i64 %r64, 8
  %r71 = getelementptr inbounds i8, ptr %r69, i64 %r70
  %r72 = load i64, ptr %r71, align 1
  %r73 = sext i64 %r72 to i128
  br label %L15
L15:
  %r74 = trunc i128 %r73 to i64
  call void @zfy_print_i64(i64 %r74)
  %t20 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t20)
  %r75 = add i64 2, 0
  %r76 = load ptr, ptr %v.arr
  %r77 = getelementptr inbounds %zfy.seq, ptr %r76, i32 0, i32 2
  %r78 = load i64, ptr %r77
  %r79 = icmp ult i64 %r75, %r78
  br i1 %r79, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r80 = load ptr, ptr %r76
  %r81 = mul i64 %r75, 8
  %r82 = getelementptr inbounds i8, ptr %r80, i64 %r81
  %r83 = load i64, ptr %r82, align 1
  %r84 = sext i64 %r83 to i128
  br label %L18
L18:
  %r85 = trunc i128 %r84 to i64
  call void @zfy_print_i64(i64 %r85)
  %t23 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t23)
  %r86 = add i64 4, 0
  %r87 = load ptr, ptr %v.arr
  %r88 = getelementptr inbounds %zfy.seq, ptr %r87, i32 0, i32 2
  %r89 = load i64, ptr %r88
  %r90 = icmp ult i64 %r86, %r89
  br i1 %r90, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r91 = load ptr, ptr %r87
  %r92 = mul i64 %r86, 8
  %r93 = getelementptr inbounds i8, ptr %r91, i64 %r92
  %r94 = load i64, ptr %r93, align 1
  %r95 = sext i64 %r94 to i128
  br label %L21
L21:
  %r96 = trunc i128 %r95 to i64
  call void @zfy_print_i64(i64 %r96)
  %t26 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t26)
  call void @zfy_free_str(ptr %t17)
  call void @zfy_free_str(ptr %t20)
  call void @zfy_free_str(ptr %t23)
  call void @zfy_free_str(ptr %t26)
  %r97 = load ptr, ptr %v.arr
  %r98 = getelementptr inbounds %zfy.seq, ptr %r97, i32 0, i32 2
  %r99 = load i64, ptr %r98
  call void @zfy_print_i64(i64 %r99)
  %r100 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r100)
  %r101 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r101, ptr %v.lst
  %r102 = load ptr, ptr %v.lst
  %r103 = bitcast double 1.5 to i64
  %r104 = zext i64 %r103 to i128
  store i128 %r104, ptr %r105
  call void @zfy_seq_set_w(ptr %r102, i64 0, ptr %r105, i32 8, i8 1)
  %r106 = load ptr, ptr %v.lst
  %r107 = bitcast double 2.5 to i64
  %r108 = zext i64 %r107 to i128
  store i128 %r108, ptr %r109
  call void @zfy_seq_set_w(ptr %r106, i64 1, ptr %r109, i32 8, i8 1)
  %r110 = load ptr, ptr %v.lst
  %r111 = bitcast double 3.5 to i64
  %r112 = zext i64 %r111 to i128
  store i128 %r112, ptr %r113
  call void @zfy_seq_set_w(ptr %r110, i64 2, ptr %r113, i32 8, i8 1)
  %r114 = load ptr, ptr %v.lst
  %r115 = bitcast double 4.5 to i64
  %r116 = zext i64 %r115 to i128
  store i128 %r116, ptr %r117
  call void @zfy_seq_set_w(ptr %r114, i64 3, ptr %r117, i32 8, i8 1)
  %r118 = add i64 1, 0
  %r119 = load ptr, ptr %v.lst
  call void @zfy_seq_remove(ptr %r119, i64 %r118, i8 0)
  %r120 = add i64 0, 0
  %r121 = load ptr, ptr %v.lst
  %r122 = getelementptr inbounds %zfy.seq, ptr %r121, i32 0, i32 2
  %r123 = load i64, ptr %r122
  %r124 = icmp ult i64 %r120, %r123
  br i1 %r124, label %L22, label %L23
L23:
  call void @zfy_bounds_fail()
  unreachable
L22:
  %r125 = load ptr, ptr %r121
  %r126 = mul i64 %r120, 8
  %r127 = getelementptr inbounds i8, ptr %r125, i64 %r126
  %r128 = load i64, ptr %r127, align 1
  %r129 = zext i64 %r128 to i128
  br label %L24
L24:
  %r130 = trunc i128 %r129 to i64
  %r131 = bitcast i64 %r130 to double
  call void @zfy_print_f64(double %r131)
  %t31 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t31)
  %r132 = add i64 1, 0
  %r133 = load ptr, ptr %v.lst
  %r134 = getelementptr inbounds %zfy.seq, ptr %r133, i32 0, i32 2
  %r135 = load i64, ptr %r134
  %r136 = icmp ult i64 %r132, %r135
  br i1 %r136, label %L25, label %L26
L26:
  call void @zfy_bounds_fail()
  unreachable
L25:
  %r137 = load ptr, ptr %r133
  %r138 = mul i64 %r132, 8
  %r139 = getelementptr inbounds i8, ptr %r137, i64 %r138
  %r140 = load i64, ptr %r139, align 1
  %r141 = zext i64 %r140 to i128
  br label %L27
L27:
  %r142 = trunc i128 %r141 to i64
  %r143 = bitcast i64 %r142 to double
  call void @zfy_print_f64(double %r143)
  %t34 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t34)
  %r144 = add i64 2, 0
  %r145 = load ptr, ptr %v.lst
  %r146 = getelementptr inbounds %zfy.seq, ptr %r145, i32 0, i32 2
  %r147 = load i64, ptr %r146
  %r148 = icmp ult i64 %r144, %r147
  br i1 %r148, label %L28, label %L29
L29:
  call void @zfy_bounds_fail()
  unreachable
L28:
  %r149 = load ptr, ptr %r145
  %r150 = mul i64 %r144, 8
  %r151 = getelementptr inbounds i8, ptr %r149, i64 %r150
  %r152 = load i64, ptr %r151, align 1
  %r153 = zext i64 %r152 to i128
  br label %L30
L30:
  %r154 = trunc i128 %r153 to i64
  %r155 = bitcast i64 %r154 to double
  call void @zfy_print_f64(double %r155)
  %t37 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t37)
  call void @zfy_free_str(ptr %t31)
  call void @zfy_free_str(ptr %t34)
  call void @zfy_free_str(ptr %t37)
  %r156 = load ptr, ptr %v.lst
  %r157 = getelementptr inbounds %zfy.seq, ptr %r156, i32 0, i32 2
  %r158 = load i64, ptr %r157
  call void @zfy_print_i64(i64 %r158)
  %r159 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r159)
  store i64 17, ptr %v.m
  %r161 = load i64, ptr %v.m
  %r160 = srem i64 %r161, 5
  store i64 %r160, ptr %v.m
  %r162 = load i64, ptr %v.m
  call void @zfy_print_i64(i64 %r162)
  %t40 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t40)
  call void @zfy_free_str(ptr %t40)
  %r163 = getelementptr inbounds [1 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r163)
  %r164 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r164)
  %r165 = call ptr @zfy_seq_new(i64 6, i64 6, i32 8)
  store ptr %r165, ptr %v.sa
  %r166 = load ptr, ptr %v.sa
  %r167 = getelementptr inbounds %zfy.seq, ptr %r166, i32 0, i32 2
  %r168 = load i64, ptr %r167
  %r169 = icmp ult i64 0, %r168
  br i1 %r169, label %L31, label %L32
L32:
  call void @zfy_bounds_fail()
  unreachable
L31:
  %r170 = load ptr, ptr %r166
  %r171 = mul i64 0, 8
  %r172 = getelementptr inbounds i8, ptr %r170, i64 %r171
  %r173 = sext i64 1 to i128
  %r174 = trunc i128 %r173 to i64
  store i64 %r174, ptr %r172, align 1
  br label %L33
L33:
  %r175 = load ptr, ptr %v.sa
  %r176 = getelementptr inbounds %zfy.seq, ptr %r175, i32 0, i32 2
  %r177 = load i64, ptr %r176
  %r178 = icmp ult i64 1, %r177
  br i1 %r178, label %L34, label %L35
L35:
  call void @zfy_bounds_fail()
  unreachable
L34:
  %r179 = load ptr, ptr %r175
  %r180 = mul i64 1, 8
  %r181 = getelementptr inbounds i8, ptr %r179, i64 %r180
  %r182 = sext i64 2 to i128
  %r183 = trunc i128 %r182 to i64
  store i64 %r183, ptr %r181, align 1
  br label %L36
L36:
  %r184 = load ptr, ptr %v.sa
  %r185 = getelementptr inbounds %zfy.seq, ptr %r184, i32 0, i32 2
  %r186 = load i64, ptr %r185
  %r187 = icmp ult i64 2, %r186
  br i1 %r187, label %L37, label %L38
L38:
  call void @zfy_bounds_fail()
  unreachable
L37:
  %r188 = load ptr, ptr %r184
  %r189 = mul i64 2, 8
  %r190 = getelementptr inbounds i8, ptr %r188, i64 %r189
  %r191 = sext i64 3 to i128
  %r192 = trunc i128 %r191 to i64
  store i64 %r192, ptr %r190, align 1
  br label %L39
L39:
  %r193 = load ptr, ptr %v.sa
  %r194 = getelementptr inbounds %zfy.seq, ptr %r193, i32 0, i32 2
  %r195 = load i64, ptr %r194
  %r196 = icmp ult i64 3, %r195
  br i1 %r196, label %L40, label %L41
L41:
  call void @zfy_bounds_fail()
  unreachable
L40:
  %r197 = load ptr, ptr %r193
  %r198 = mul i64 3, 8
  %r199 = getelementptr inbounds i8, ptr %r197, i64 %r198
  %r200 = sext i64 4 to i128
  %r201 = trunc i128 %r200 to i64
  store i64 %r201, ptr %r199, align 1
  br label %L42
L42:
  %r202 = load ptr, ptr %v.sa
  %r203 = getelementptr inbounds %zfy.seq, ptr %r202, i32 0, i32 2
  %r204 = load i64, ptr %r203
  %r205 = icmp ult i64 4, %r204
  br i1 %r205, label %L43, label %L44
L44:
  call void @zfy_bounds_fail()
  unreachable
L43:
  %r206 = load ptr, ptr %r202
  %r207 = mul i64 4, 8
  %r208 = getelementptr inbounds i8, ptr %r206, i64 %r207
  %r209 = sext i64 5 to i128
  %r210 = trunc i128 %r209 to i64
  store i64 %r210, ptr %r208, align 1
  br label %L45
L45:
  %r211 = load ptr, ptr %v.sa
  %r212 = getelementptr inbounds %zfy.seq, ptr %r211, i32 0, i32 2
  %r213 = load i64, ptr %r212
  %r214 = icmp ult i64 5, %r213
  br i1 %r214, label %L46, label %L47
L47:
  call void @zfy_bounds_fail()
  unreachable
L46:
  %r215 = load ptr, ptr %r211
  %r216 = mul i64 5, 8
  %r217 = getelementptr inbounds i8, ptr %r215, i64 %r216
  %r218 = sext i64 6 to i128
  %r219 = trunc i128 %r218 to i64
  store i64 %r219, ptr %r217, align 1
  br label %L48
L48:
  %r220 = add i64 3, 0
  %r221 = add i64 1, 0
  %r222 = load ptr, ptr %v.sa
  %r224 = zext i64 10 to i128
  store i128 %r224, ptr %r223
  call void @zfy_seq_aug_range(ptr %r222, i64 %r221, i64 %r220, i64 1, i32 0, ptr %r223, i32 8, i32 1, i32 0)
  %r225 = add i64 0, 0
  %r226 = load ptr, ptr %v.sa
  %r227 = getelementptr inbounds %zfy.seq, ptr %r226, i32 0, i32 2
  %r228 = load i64, ptr %r227
  %r229 = icmp ult i64 %r225, %r228
  br i1 %r229, label %L49, label %L50
L50:
  call void @zfy_bounds_fail()
  unreachable
L49:
  %r230 = load ptr, ptr %r226
  %r231 = mul i64 %r225, 8
  %r232 = getelementptr inbounds i8, ptr %r230, i64 %r231
  %r233 = load i64, ptr %r232, align 1
  %r234 = sext i64 %r233 to i128
  br label %L51
L51:
  %r235 = trunc i128 %r234 to i64
  call void @zfy_print_i64(i64 %r235)
  %t45 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t45)
  %r236 = add i64 1, 0
  %r237 = load ptr, ptr %v.sa
  %r238 = getelementptr inbounds %zfy.seq, ptr %r237, i32 0, i32 2
  %r239 = load i64, ptr %r238
  %r240 = icmp ult i64 %r236, %r239
  br i1 %r240, label %L52, label %L53
L53:
  call void @zfy_bounds_fail()
  unreachable
L52:
  %r241 = load ptr, ptr %r237
  %r242 = mul i64 %r236, 8
  %r243 = getelementptr inbounds i8, ptr %r241, i64 %r242
  %r244 = load i64, ptr %r243, align 1
  %r245 = sext i64 %r244 to i128
  br label %L54
L54:
  %r246 = trunc i128 %r245 to i64
  call void @zfy_print_i64(i64 %r246)
  %t48 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t48)
  %r247 = add i64 2, 0
  %r248 = load ptr, ptr %v.sa
  %r249 = getelementptr inbounds %zfy.seq, ptr %r248, i32 0, i32 2
  %r250 = load i64, ptr %r249
  %r251 = icmp ult i64 %r247, %r250
  br i1 %r251, label %L55, label %L56
L56:
  call void @zfy_bounds_fail()
  unreachable
L55:
  %r252 = load ptr, ptr %r248
  %r253 = mul i64 %r247, 8
  %r254 = getelementptr inbounds i8, ptr %r252, i64 %r253
  %r255 = load i64, ptr %r254, align 1
  %r256 = sext i64 %r255 to i128
  br label %L57
L57:
  %r257 = trunc i128 %r256 to i64
  call void @zfy_print_i64(i64 %r257)
  %t51 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t51)
  %r258 = add i64 3, 0
  %r259 = load ptr, ptr %v.sa
  %r260 = getelementptr inbounds %zfy.seq, ptr %r259, i32 0, i32 2
  %r261 = load i64, ptr %r260
  %r262 = icmp ult i64 %r258, %r261
  br i1 %r262, label %L58, label %L59
L59:
  call void @zfy_bounds_fail()
  unreachable
L58:
  %r263 = load ptr, ptr %r259
  %r264 = mul i64 %r258, 8
  %r265 = getelementptr inbounds i8, ptr %r263, i64 %r264
  %r266 = load i64, ptr %r265, align 1
  %r267 = sext i64 %r266 to i128
  br label %L60
L60:
  %r268 = trunc i128 %r267 to i64
  call void @zfy_print_i64(i64 %r268)
  %t54 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t54)
  %r269 = add i64 4, 0
  %r270 = load ptr, ptr %v.sa
  %r271 = getelementptr inbounds %zfy.seq, ptr %r270, i32 0, i32 2
  %r272 = load i64, ptr %r271
  %r273 = icmp ult i64 %r269, %r272
  br i1 %r273, label %L61, label %L62
L62:
  call void @zfy_bounds_fail()
  unreachable
L61:
  %r274 = load ptr, ptr %r270
  %r275 = mul i64 %r269, 8
  %r276 = getelementptr inbounds i8, ptr %r274, i64 %r275
  %r277 = load i64, ptr %r276, align 1
  %r278 = sext i64 %r277 to i128
  br label %L63
L63:
  %r279 = trunc i128 %r278 to i64
  call void @zfy_print_i64(i64 %r279)
  %t57 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t57)
  %r280 = add i64 5, 0
  %r281 = load ptr, ptr %v.sa
  %r282 = getelementptr inbounds %zfy.seq, ptr %r281, i32 0, i32 2
  %r283 = load i64, ptr %r282
  %r284 = icmp ult i64 %r280, %r283
  br i1 %r284, label %L64, label %L65
L65:
  call void @zfy_bounds_fail()
  unreachable
L64:
  %r285 = load ptr, ptr %r281
  %r286 = mul i64 %r280, 8
  %r287 = getelementptr inbounds i8, ptr %r285, i64 %r286
  %r288 = load i64, ptr %r287, align 1
  %r289 = sext i64 %r288 to i128
  br label %L66
L66:
  %r290 = trunc i128 %r289 to i64
  call void @zfy_print_i64(i64 %r290)
  %t60 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t60)
  call void @zfy_free_str(ptr %t45)
  call void @zfy_free_str(ptr %t48)
  call void @zfy_free_str(ptr %t51)
  call void @zfy_free_str(ptr %t54)
  call void @zfy_free_str(ptr %t57)
  call void @zfy_free_str(ptr %t60)
  %r291 = getelementptr inbounds [1 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r291)
  %r292 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r292)
  %r293 = call ptr @zfy_seq_new(i64 6, i64 6, i32 8)
  store ptr %r293, ptr %v.sb
  %r294 = load ptr, ptr %v.sb
  %r295 = getelementptr inbounds %zfy.seq, ptr %r294, i32 0, i32 2
  %r296 = load i64, ptr %r295
  %r297 = icmp ult i64 0, %r296
  br i1 %r297, label %L67, label %L68
L68:
  call void @zfy_bounds_fail()
  unreachable
L67:
  %r298 = load ptr, ptr %r294
  %r299 = mul i64 0, 8
  %r300 = getelementptr inbounds i8, ptr %r298, i64 %r299
  %r301 = sext i64 1 to i128
  %r302 = trunc i128 %r301 to i64
  store i64 %r302, ptr %r300, align 1
  br label %L69
L69:
  %r303 = load ptr, ptr %v.sb
  %r304 = getelementptr inbounds %zfy.seq, ptr %r303, i32 0, i32 2
  %r305 = load i64, ptr %r304
  %r306 = icmp ult i64 1, %r305
  br i1 %r306, label %L70, label %L71
L71:
  call void @zfy_bounds_fail()
  unreachable
L70:
  %r307 = load ptr, ptr %r303
  %r308 = mul i64 1, 8
  %r309 = getelementptr inbounds i8, ptr %r307, i64 %r308
  %r310 = sext i64 2 to i128
  %r311 = trunc i128 %r310 to i64
  store i64 %r311, ptr %r309, align 1
  br label %L72
L72:
  %r312 = load ptr, ptr %v.sb
  %r313 = getelementptr inbounds %zfy.seq, ptr %r312, i32 0, i32 2
  %r314 = load i64, ptr %r313
  %r315 = icmp ult i64 2, %r314
  br i1 %r315, label %L73, label %L74
L74:
  call void @zfy_bounds_fail()
  unreachable
L73:
  %r316 = load ptr, ptr %r312
  %r317 = mul i64 2, 8
  %r318 = getelementptr inbounds i8, ptr %r316, i64 %r317
  %r319 = sext i64 3 to i128
  %r320 = trunc i128 %r319 to i64
  store i64 %r320, ptr %r318, align 1
  br label %L75
L75:
  %r321 = load ptr, ptr %v.sb
  %r322 = getelementptr inbounds %zfy.seq, ptr %r321, i32 0, i32 2
  %r323 = load i64, ptr %r322
  %r324 = icmp ult i64 3, %r323
  br i1 %r324, label %L76, label %L77
L77:
  call void @zfy_bounds_fail()
  unreachable
L76:
  %r325 = load ptr, ptr %r321
  %r326 = mul i64 3, 8
  %r327 = getelementptr inbounds i8, ptr %r325, i64 %r326
  %r328 = sext i64 4 to i128
  %r329 = trunc i128 %r328 to i64
  store i64 %r329, ptr %r327, align 1
  br label %L78
L78:
  %r330 = load ptr, ptr %v.sb
  %r331 = getelementptr inbounds %zfy.seq, ptr %r330, i32 0, i32 2
  %r332 = load i64, ptr %r331
  %r333 = icmp ult i64 4, %r332
  br i1 %r333, label %L79, label %L80
L80:
  call void @zfy_bounds_fail()
  unreachable
L79:
  %r334 = load ptr, ptr %r330
  %r335 = mul i64 4, 8
  %r336 = getelementptr inbounds i8, ptr %r334, i64 %r335
  %r337 = sext i64 5 to i128
  %r338 = trunc i128 %r337 to i64
  store i64 %r338, ptr %r336, align 1
  br label %L81
L81:
  %r339 = load ptr, ptr %v.sb
  %r340 = getelementptr inbounds %zfy.seq, ptr %r339, i32 0, i32 2
  %r341 = load i64, ptr %r340
  %r342 = icmp ult i64 5, %r341
  br i1 %r342, label %L82, label %L83
L83:
  call void @zfy_bounds_fail()
  unreachable
L82:
  %r343 = load ptr, ptr %r339
  %r344 = mul i64 5, 8
  %r345 = getelementptr inbounds i8, ptr %r343, i64 %r344
  %r346 = sext i64 6 to i128
  %r347 = trunc i128 %r346 to i64
  store i64 %r347, ptr %r345, align 1
  br label %L84
L84:
  %r348 = add i64 2, 0
  %r349 = add i64 5, 0
  %r350 = add i64 0, 0
  %r351 = load ptr, ptr %v.sb
  %r353 = zext i64 3 to i128
  store i128 %r353, ptr %r352
  call void @zfy_seq_aug_range(ptr %r351, i64 %r350, i64 %r349, i64 %r348, i32 2, ptr %r352, i32 8, i32 1, i32 0)
  %r354 = add i64 0, 0
  %r355 = load ptr, ptr %v.sb
  %r356 = getelementptr inbounds %zfy.seq, ptr %r355, i32 0, i32 2
  %r357 = load i64, ptr %r356
  %r358 = icmp ult i64 %r354, %r357
  br i1 %r358, label %L85, label %L86
L86:
  call void @zfy_bounds_fail()
  unreachable
L85:
  %r359 = load ptr, ptr %r355
  %r360 = mul i64 %r354, 8
  %r361 = getelementptr inbounds i8, ptr %r359, i64 %r360
  %r362 = load i64, ptr %r361, align 1
  %r363 = sext i64 %r362 to i128
  br label %L87
L87:
  %r364 = trunc i128 %r363 to i64
  call void @zfy_print_i64(i64 %r364)
  %t66 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t66)
  %r365 = add i64 2, 0
  %r366 = load ptr, ptr %v.sb
  %r367 = getelementptr inbounds %zfy.seq, ptr %r366, i32 0, i32 2
  %r368 = load i64, ptr %r367
  %r369 = icmp ult i64 %r365, %r368
  br i1 %r369, label %L88, label %L89
L89:
  call void @zfy_bounds_fail()
  unreachable
L88:
  %r370 = load ptr, ptr %r366
  %r371 = mul i64 %r365, 8
  %r372 = getelementptr inbounds i8, ptr %r370, i64 %r371
  %r373 = load i64, ptr %r372, align 1
  %r374 = sext i64 %r373 to i128
  br label %L90
L90:
  %r375 = trunc i128 %r374 to i64
  call void @zfy_print_i64(i64 %r375)
  %t69 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t69)
  %r376 = add i64 4, 0
  %r377 = load ptr, ptr %v.sb
  %r378 = getelementptr inbounds %zfy.seq, ptr %r377, i32 0, i32 2
  %r379 = load i64, ptr %r378
  %r380 = icmp ult i64 %r376, %r379
  br i1 %r380, label %L91, label %L92
L92:
  call void @zfy_bounds_fail()
  unreachable
L91:
  %r381 = load ptr, ptr %r377
  %r382 = mul i64 %r376, 8
  %r383 = getelementptr inbounds i8, ptr %r381, i64 %r382
  %r384 = load i64, ptr %r383, align 1
  %r385 = sext i64 %r384 to i128
  br label %L93
L93:
  %r386 = trunc i128 %r385 to i64
  call void @zfy_print_i64(i64 %r386)
  %t72 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t72)
  call void @zfy_free_str(ptr %t66)
  call void @zfy_free_str(ptr %t69)
  call void @zfy_free_str(ptr %t72)
  %r387 = getelementptr inbounds [1 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r387)
  %r388 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r388)
  store double 3.75, ptr %v.pi
  %r390 = load double, ptr %v.pi
  %r389 = fptosi double %r390 to i32
  store i32 %r389, ptr %v.pi$1
  %r391 = load i32, ptr %v.pi$1
  %r392 = sext i32 %r391 to i64
  call void @zfy_print_i64(i64 %r392)
  %t74 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t74)
  call void @zfy_free_str(ptr %t74)
  %r393 = getelementptr inbounds [1 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r393)
  %r394 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r394)
  %r395 = getelementptr inbounds [8 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r395)
  %r396 = getelementptr inbounds [2 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_print_str(ptr %r396)
  %r397 = add i64 2, 0
  %r398 = getelementptr inbounds [6 x i8], ptr @.str19, i64 0, i64 0
  %t76 = call i64 @zfy_str_find(ptr %r398, i8 108, i64 %r397)
  store i64 %t76, ptr %v.pos
  %r399 = load i64, ptr %v.pos
  call void @zfy_print_i64(i64 %r399)
  %t77 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t77)
  call void @zfy_free_str(ptr %t77)
  %r400 = getelementptr inbounds [1 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r400)
  %r401 = getelementptr inbounds [2 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r401)
  %r402 = load ptr, ptr %v.s0
  call void @zfy_free_str(ptr %r402)
  %r403 = getelementptr inbounds [4 x i8], ptr @.str22, i64 0, i64 0
  %r404 = call ptr @zfy_strdup(ptr %r403)
  store ptr %r404, ptr %v.s0
  %r405 = load ptr, ptr %v.s0
  %r406 = getelementptr inbounds [1 x i8], ptr @.str23, i64 0, i64 0
  %t78 = call ptr @zfy_str_trim_str(ptr %r405, ptr %r406)
  call void @zfy_print_str(ptr %t78)
  %t79 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t79)
  call void @zfy_free_str(ptr %t78)
  call void @zfy_free_str(ptr %t79)
  %r407 = load ptr, ptr %v.s0
  %r408 = getelementptr inbounds [1 x i8], ptr @.str24, i64 0, i64 0
  %t80 = call ptr @zfy_str_split_str(ptr %r407, ptr %r408)
  %r409 = load ptr, ptr %v.one
  call void @zfy_seq_free(ptr %r409, i8 1)
  store ptr %t80, ptr %v.one
  %r410 = load ptr, ptr %v.one
  %r411 = getelementptr inbounds %zfy.seq, ptr %r410, i32 0, i32 2
  %r412 = load i64, ptr %r411
  call void @zfy_print_i64(i64 %r412)
  %t82 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t82)
  call void @zfy_free_str(ptr %t82)
  %r413 = add i64 0, 0
  %r415 = load ptr, ptr %v.one
  call void @zfy_seq_get(ptr %r415, i64 %r413, ptr %r414, i32 8, i8 0)
  %r416 = load i128, ptr %r414
  %r417 = trunc i128 %r416 to i64
  %r418 = inttoptr i64 %r417 to ptr
  call void @zfy_print_str(ptr %r418)
  %t85 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t85)
  call void @zfy_free_str(ptr %t85)
  %r419 = getelementptr inbounds [1 x i8], ptr @.str25, i64 0, i64 0
  call void @zfy_print_str(ptr %r419)
  %r420 = getelementptr inbounds [2 x i8], ptr @.str26, i64 0, i64 0
  call void @zfy_print_str(ptr %r420)
  store i64 3, ptr %v.k
  br label %b1
b1:
  %r422 = load i64, ptr %v.k
  %r421 = icmp sgt i64 %r422, 0
  br i1 %r421, label %b2, label %b4
b2:
  %r423 = load i64, ptr %v.k
  call void @zfy_print_i64(i64 %r423)
  %t87 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t87)
  call void @zfy_free_str(ptr %t87)
  br label %b3
b3:
  %r425 = load i64, ptr %v.k
  %r424 = sub i64 %r425, 1
  store i64 %r424, ptr %v.k
  br label %b1
b4:
  %r426 = getelementptr inbounds [1 x i8], ptr @.str27, i64 0, i64 0
  call void @zfy_print_str(ptr %r426)
  %r427 = getelementptr inbounds [2 x i8], ptr @.str28, i64 0, i64 0
  call void @zfy_print_str(ptr %r427)
  %r428 = call ptr @zfy_seq_new(i64 3, i64 3, i32 8)
  store ptr %r428, ptr %v.carr
  %r429 = load ptr, ptr %v.carr
  %r430 = getelementptr inbounds %zfy.seq, ptr %r429, i32 0, i32 2
  %r431 = load i64, ptr %r430
  %r432 = icmp ult i64 0, %r431
  br i1 %r432, label %L94, label %L95
L95:
  call void @zfy_bounds_fail()
  unreachable
L94:
  %r433 = load ptr, ptr %r429
  %r434 = mul i64 0, 8
  %r435 = getelementptr inbounds i8, ptr %r433, i64 %r434
  %r436 = sext i64 7 to i128
  %r437 = trunc i128 %r436 to i64
  store i64 %r437, ptr %r435, align 1
  br label %L96
L96:
  %r438 = load ptr, ptr %v.carr
  %r439 = getelementptr inbounds %zfy.seq, ptr %r438, i32 0, i32 2
  %r440 = load i64, ptr %r439
  %r441 = icmp ult i64 1, %r440
  br i1 %r441, label %L97, label %L98
L98:
  call void @zfy_bounds_fail()
  unreachable
L97:
  %r442 = load ptr, ptr %r438
  %r443 = mul i64 1, 8
  %r444 = getelementptr inbounds i8, ptr %r442, i64 %r443
  %r445 = sext i64 8 to i128
  %r446 = trunc i128 %r445 to i64
  store i64 %r446, ptr %r444, align 1
  br label %L99
L99:
  %r447 = load ptr, ptr %v.carr
  %r448 = getelementptr inbounds %zfy.seq, ptr %r447, i32 0, i32 2
  %r449 = load i64, ptr %r448
  %r450 = icmp ult i64 2, %r449
  br i1 %r450, label %L100, label %L101
L101:
  call void @zfy_bounds_fail()
  unreachable
L100:
  %r451 = load ptr, ptr %r447
  %r452 = mul i64 2, 8
  %r453 = getelementptr inbounds i8, ptr %r451, i64 %r452
  %r454 = sext i64 9 to i128
  %r455 = trunc i128 %r454 to i64
  store i64 %r455, ptr %r453, align 1
  br label %L102
L102:
  %r456 = add i64 2, 0
  %r457 = load ptr, ptr %v.carr
  %r458 = getelementptr inbounds %zfy.seq, ptr %r457, i32 0, i32 2
  %r459 = load i64, ptr %r458
  %r460 = icmp ult i64 %r456, %r459
  br i1 %r460, label %L103, label %L104
L104:
  call void @zfy_bounds_fail()
  unreachable
L103:
  %r461 = load ptr, ptr %r457
  %r462 = mul i64 %r456, 8
  %r463 = getelementptr inbounds i8, ptr %r461, i64 %r462
  %r464 = load i64, ptr %r463, align 1
  %r465 = sext i64 %r464 to i128
  br label %L105
L105:
  %r466 = trunc i128 %r465 to i64
  call void @zfy_print_i64(i64 %r466)
  %t91 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t91)
  call void @zfy_free_str(ptr %t91)
  %r467 = getelementptr inbounds [1 x i8], ptr @.str29, i64 0, i64 0
  call void @zfy_print_str(ptr %r467)
  %r468 = getelementptr inbounds [2 x i8], ptr @.str30, i64 0, i64 0
  call void @zfy_print_str(ptr %r468)
  %r469 = load ptr, ptr %v.s1
  call void @zfy_free_str(ptr %r469)
  %r470 = getelementptr inbounds [4 x i8], ptr @.str31, i64 0, i64 0
  %r471 = call ptr @zfy_strdup(ptr %r470)
  store ptr %r471, ptr %v.s1
  %r472 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r472)
  %r473 = load ptr, ptr %v.s1
  %r474 = call ptr @zfy_strdup(ptr %r473)
  store ptr %r474, ptr %v.s2
  %r475 = load ptr, ptr %v.s2
  %r476 = getelementptr inbounds [4 x i8], ptr @.str32, i64 0, i64 0
  %t92 = call ptr @zfy_str_concat(ptr %r475, ptr %r476)
  %r477 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r477)
  %r478 = call ptr @zfy_strdup(ptr %t92)
  store ptr %r478, ptr %v.s2
  call void @zfy_free_str(ptr %t92)
  %r479 = load ptr, ptr %v.s1
  call void @zfy_print_str(ptr %r479)
  %t93 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t93)
  %r480 = load ptr, ptr %v.s2
  call void @zfy_print_str(ptr %r480)
  %t94 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t94)
  call void @zfy_free_str(ptr %t93)
  call void @zfy_free_str(ptr %t94)
  %r481 = call ptr @zfy_seq_new(i64 3, i64 3, i32 4)
  store ptr %r481, ptr %v.ia
  %r482 = load ptr, ptr %v.ia
  %r483 = getelementptr inbounds %zfy.seq, ptr %r482, i32 0, i32 2
  %r484 = load i64, ptr %r483
  %r485 = icmp ult i64 0, %r484
  br i1 %r485, label %L106, label %L107
L107:
  call void @zfy_bounds_fail()
  unreachable
L106:
  %r486 = load ptr, ptr %r482
  %r487 = mul i64 0, 4
  %r488 = getelementptr inbounds i8, ptr %r486, i64 %r487
  %r489 = sext i32 1 to i128
  %r490 = trunc i128 %r489 to i32
  store i32 %r490, ptr %r488, align 1
  br label %L108
L108:
  %r491 = load ptr, ptr %v.ia
  %r492 = getelementptr inbounds %zfy.seq, ptr %r491, i32 0, i32 2
  %r493 = load i64, ptr %r492
  %r494 = icmp ult i64 1, %r493
  br i1 %r494, label %L109, label %L110
L110:
  call void @zfy_bounds_fail()
  unreachable
L109:
  %r495 = load ptr, ptr %r491
  %r496 = mul i64 1, 4
  %r497 = getelementptr inbounds i8, ptr %r495, i64 %r496
  %r498 = sext i32 2 to i128
  %r499 = trunc i128 %r498 to i32
  store i32 %r499, ptr %r497, align 1
  br label %L111
L111:
  %r500 = load ptr, ptr %v.ia
  %r501 = getelementptr inbounds %zfy.seq, ptr %r500, i32 0, i32 2
  %r502 = load i64, ptr %r501
  %r503 = icmp ult i64 2, %r502
  br i1 %r503, label %L112, label %L113
L113:
  call void @zfy_bounds_fail()
  unreachable
L112:
  %r504 = load ptr, ptr %r500
  %r505 = mul i64 2, 4
  %r506 = getelementptr inbounds i8, ptr %r504, i64 %r505
  %r507 = sext i32 3 to i128
  %r508 = trunc i128 %r507 to i32
  store i32 %r508, ptr %r506, align 1
  br label %L114
L114:
  %r509 = load ptr, ptr %v.ib
  call void @zfy_seq_free(ptr %r509, i8 0)
  %r510 = load ptr, ptr %v.ia
  %r511 = call ptr @zfy_seq_clone(ptr %r510, i8 0)
  store ptr %r511, ptr %v.ib
  %r512 = add i64 0, 0
  %r513 = load ptr, ptr %v.ib
  %r514 = getelementptr inbounds %zfy.seq, ptr %r513, i32 0, i32 2
  %r515 = load i64, ptr %r514
  %r516 = icmp ult i64 %r512, %r515
  br i1 %r516, label %L115, label %L116
L116:
  call void @zfy_bounds_fail()
  unreachable
L115:
  %r517 = load ptr, ptr %r513
  %r518 = mul i64 %r512, 4
  %r519 = getelementptr inbounds i8, ptr %r517, i64 %r518
  %r520 = sext i32 99 to i128
  %r521 = trunc i128 %r520 to i32
  store i32 %r521, ptr %r519, align 1
  br label %L117
L117:
  %r522 = add i64 0, 0
  %r523 = load ptr, ptr %v.ia
  %r524 = getelementptr inbounds %zfy.seq, ptr %r523, i32 0, i32 2
  %r525 = load i64, ptr %r524
  %r526 = icmp ult i64 %r522, %r525
  br i1 %r526, label %L118, label %L119
L119:
  call void @zfy_bounds_fail()
  unreachable
L118:
  %r527 = load ptr, ptr %r523
  %r528 = mul i64 %r522, 4
  %r529 = getelementptr inbounds i8, ptr %r527, i64 %r528
  %r530 = load i32, ptr %r529, align 1
  %r531 = sext i32 %r530 to i128
  br label %L120
L120:
  %r532 = trunc i128 %r531 to i32
  %r533 = sext i32 %r532 to i64
  call void @zfy_print_i64(i64 %r533)
  %t98 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t98)
  %r534 = add i64 0, 0
  %r535 = load ptr, ptr %v.ib
  %r536 = getelementptr inbounds %zfy.seq, ptr %r535, i32 0, i32 2
  %r537 = load i64, ptr %r536
  %r538 = icmp ult i64 %r534, %r537
  br i1 %r538, label %L121, label %L122
L122:
  call void @zfy_bounds_fail()
  unreachable
L121:
  %r539 = load ptr, ptr %r535
  %r540 = mul i64 %r534, 4
  %r541 = getelementptr inbounds i8, ptr %r539, i64 %r540
  %r542 = load i32, ptr %r541, align 1
  %r543 = sext i32 %r542 to i128
  br label %L123
L123:
  %r544 = trunc i128 %r543 to i32
  %r545 = sext i32 %r544 to i64
  call void @zfy_print_i64(i64 %r545)
  %t101 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t101)
  call void @zfy_free_str(ptr %t98)
  call void @zfy_free_str(ptr %t101)
  %r546 = getelementptr inbounds [1 x i8], ptr @.str33, i64 0, i64 0
  call void @zfy_print_str(ptr %r546)
  %r547 = getelementptr inbounds [2 x i8], ptr @.str34, i64 0, i64 0
  call void @zfy_print_str(ptr %r547)
  %r548 = load ptr, ptr %v.ib
  call void @zfy_seq_free(ptr %r548, i8 0)
  store ptr null, ptr %v.ib
  %r549 = load ptr, ptr %v.ia
  call void @zfy_seq_free(ptr %r549, i8 0)
  store ptr null, ptr %v.ia
  %r550 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r550)
  store ptr null, ptr %v.s2
  %r551 = load ptr, ptr %v.s1
  call void @zfy_free_str(ptr %r551)
  store ptr null, ptr %v.s1
  %r552 = load ptr, ptr %v.carr
  call void @zfy_seq_free(ptr %r552, i8 0)
  store ptr null, ptr %v.carr
  %r553 = load ptr, ptr %v.one
  call void @zfy_seq_free(ptr %r553, i8 1)
  store ptr null, ptr %v.one
  %r554 = load ptr, ptr %v.s0
  call void @zfy_free_str(ptr %r554)
  store ptr null, ptr %v.s0
  %r555 = load ptr, ptr %v.sb
  call void @zfy_seq_free(ptr %r555, i8 0)
  store ptr null, ptr %v.sb
  %r556 = load ptr, ptr %v.sa
  call void @zfy_seq_free(ptr %r556, i8 0)
  store ptr null, ptr %v.sa
  %r557 = load ptr, ptr %v.lst
  call void @zfy_seq_free(ptr %r557, i8 0)
  store ptr null, ptr %v.lst
  %r558 = load ptr, ptr %v.arr
  call void @zfy_seq_free(ptr %r558, i8 0)
  store ptr null, ptr %v.arr
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
