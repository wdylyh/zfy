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
declare ptr @zfy_tostr_bool(i8)
declare ptr @zfy_tostr_i64(i64)
declare ptr @zfy_tostr_u64(i64)
declare ptr @zfy_tostr_i128(i128)
declare ptr @zfy_tostr_u128(i128)
declare ptr @zfy_tostr_f64(double)
declare void @zfy_input_str(ptr, ptr)
declare void @zfy_input_i64(ptr, ptr)
declare void @zfy_input_i128(ptr, ptr)
declare void @zfy_input_u128(ptr, ptr)
declare void @zfy_input_f64(ptr, ptr, i8)
declare void @zfy_input_bool(ptr, ptr)
declare void @zfy_input_char(ptr, ptr)
declare ptr @zfy_seq_new(i64, i64, i32)
declare void @zfy_seq_set_w(ptr, i64, ptr, i32, i8)
declare void @zfy_seq_set_str(ptr, i64, ptr, i8)
declare void @zfy_seq_get(ptr, i64, ptr, i32, i8)
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
declare void @zfy_seq_zero(ptr, i64, i8)
declare void @zfy_seq_remove(ptr, i64, i8)
declare void @zfy_seq_aug_range(ptr, i64, i64, i64, i8, ptr, i32, i8, i8)
@.str1 = private unnamed_addr constant [1 x i8] c"\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.main() {
  %v.m = alloca i64
  store i64 zeroinitializer, ptr %v.m
  %v.lst = alloca ptr
  store ptr null, ptr %v.lst
  %v.arr = alloca ptr
  store ptr null, ptr %v.arr
  %v.c = alloca %frac.i32
  store %frac.i32 zeroinitializer, ptr %v.c
  %v.ur2 = alloca %frac.i32
  store %frac.i32 zeroinitializer, ptr %v.ur2
  %v.a = alloca %frac.i32
  store %frac.i32 zeroinitializer, ptr %v.a
  %v.ur = alloca %frac.i32
  store %frac.i32 zeroinitializer, ptr %v.ur
  %r1 = trunc i64 6 to i32
  %r2 = trunc i64 48 to i32
  %r3 = alloca %frac.i32
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
  %r10 = alloca %frac.i32
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
  %r17 = alloca %frac.i32
  %r18 = getelementptr inbounds %frac.i32, ptr %r17, i32 0, i32 0
  store i32 %r15, ptr %r18
  %r19 = getelementptr inbounds %frac.i32, ptr %r17, i32 0, i32 1
  store i32 %r16, ptr %r19
  call void @llvm.memcpy.p0.p0.i64(ptr %v.ur2, ptr %r17, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.ur2)
  %r20 = alloca %frac.i32
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
  %r25 = sext i64 1 to i128
  %r26 = alloca i128
  store i128 %r25, ptr %r26
  call void @zfy_seq_set_w(ptr %r24, i64 0, ptr %r26, i32 8, i8 0)
  %r27 = load ptr, ptr %v.arr
  %r28 = sext i64 2 to i128
  %r29 = alloca i128
  store i128 %r28, ptr %r29
  call void @zfy_seq_set_w(ptr %r27, i64 1, ptr %r29, i32 8, i8 0)
  %r30 = load ptr, ptr %v.arr
  %r31 = sext i64 3 to i128
  %r32 = alloca i128
  store i128 %r31, ptr %r32
  call void @zfy_seq_set_w(ptr %r30, i64 2, ptr %r32, i32 8, i8 0)
  %r33 = add i64 1, 0
  %r34 = load ptr, ptr %v.arr
  call void @zfy_seq_zero(ptr %r34, i64 %r33, i8 0)
  %r35 = add i64 0, 0
  %r36 = alloca i128
  %r37 = load ptr, ptr %v.arr
  call void @zfy_seq_get(ptr %r37, i64 %r35, ptr %r36, i32 8, i8 1)
  %r38 = load i128, ptr %r36
  %r39 = trunc i128 %r38 to i64
  call void @zfy_print_i64(i64 %r39)
  %t17 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t17)
  %r40 = add i64 1, 0
  %r41 = alloca i128
  %r42 = load ptr, ptr %v.arr
  call void @zfy_seq_get(ptr %r42, i64 %r40, ptr %r41, i32 8, i8 1)
  %r43 = load i128, ptr %r41
  %r44 = trunc i128 %r43 to i64
  call void @zfy_print_i64(i64 %r44)
  %t20 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t20)
  %r45 = add i64 2, 0
  %r46 = alloca i128
  %r47 = load ptr, ptr %v.arr
  call void @zfy_seq_get(ptr %r47, i64 %r45, ptr %r46, i32 8, i8 1)
  %r48 = load i128, ptr %r46
  %r49 = trunc i128 %r48 to i64
  call void @zfy_print_i64(i64 %r49)
  %t23 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t23)
  %r50 = add i64 4, 0
  %r51 = alloca i128
  %r52 = load ptr, ptr %v.arr
  call void @zfy_seq_get(ptr %r52, i64 %r50, ptr %r51, i32 8, i8 1)
  %r53 = load i128, ptr %r51
  %r54 = trunc i128 %r53 to i64
  call void @zfy_print_i64(i64 %r54)
  %t26 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t26)
  call void @zfy_free_str(ptr %t17)
  call void @zfy_free_str(ptr %t20)
  call void @zfy_free_str(ptr %t23)
  call void @zfy_free_str(ptr %t26)
  %r55 = load ptr, ptr %v.arr
  %r56 = getelementptr inbounds %zfy.seq, ptr %r55, i32 0, i32 2
  %r57 = load i64, ptr %r56
  call void @zfy_print_i64(i64 %r57)
  %r58 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r58)
  %r59 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r59, ptr %v.lst
  %r60 = load ptr, ptr %v.lst
  %r61 = bitcast double 1.5 to i64
  %r62 = zext i64 %r61 to i128
  %r63 = alloca i128
  store i128 %r62, ptr %r63
  call void @zfy_seq_set_w(ptr %r60, i64 0, ptr %r63, i32 8, i8 1)
  %r64 = load ptr, ptr %v.lst
  %r65 = bitcast double 2.5 to i64
  %r66 = zext i64 %r65 to i128
  %r67 = alloca i128
  store i128 %r66, ptr %r67
  call void @zfy_seq_set_w(ptr %r64, i64 1, ptr %r67, i32 8, i8 1)
  %r68 = load ptr, ptr %v.lst
  %r69 = bitcast double 3.5 to i64
  %r70 = zext i64 %r69 to i128
  %r71 = alloca i128
  store i128 %r70, ptr %r71
  call void @zfy_seq_set_w(ptr %r68, i64 2, ptr %r71, i32 8, i8 1)
  %r72 = load ptr, ptr %v.lst
  %r73 = bitcast double 4.5 to i64
  %r74 = zext i64 %r73 to i128
  %r75 = alloca i128
  store i128 %r74, ptr %r75
  call void @zfy_seq_set_w(ptr %r72, i64 3, ptr %r75, i32 8, i8 1)
  %r76 = add i64 1, 0
  %r77 = load ptr, ptr %v.lst
  call void @zfy_seq_remove(ptr %r77, i64 %r76, i8 0)
  %r78 = add i64 0, 0
  %r79 = alloca i128
  %r80 = load ptr, ptr %v.lst
  call void @zfy_seq_get(ptr %r80, i64 %r78, ptr %r79, i32 8, i8 0)
  %r81 = load i128, ptr %r79
  %r82 = trunc i128 %r81 to i64
  %r83 = bitcast i64 %r82 to double
  call void @zfy_print_f64(double %r83)
  %t31 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t31)
  %r84 = add i64 1, 0
  %r85 = alloca i128
  %r86 = load ptr, ptr %v.lst
  call void @zfy_seq_get(ptr %r86, i64 %r84, ptr %r85, i32 8, i8 0)
  %r87 = load i128, ptr %r85
  %r88 = trunc i128 %r87 to i64
  %r89 = bitcast i64 %r88 to double
  call void @zfy_print_f64(double %r89)
  %t34 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t34)
  %r90 = add i64 2, 0
  %r91 = alloca i128
  %r92 = load ptr, ptr %v.lst
  call void @zfy_seq_get(ptr %r92, i64 %r90, ptr %r91, i32 8, i8 0)
  %r93 = load i128, ptr %r91
  %r94 = trunc i128 %r93 to i64
  %r95 = bitcast i64 %r94 to double
  call void @zfy_print_f64(double %r95)
  %t37 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t37)
  call void @zfy_free_str(ptr %t31)
  call void @zfy_free_str(ptr %t34)
  call void @zfy_free_str(ptr %t37)
  %r96 = load ptr, ptr %v.lst
  %r97 = getelementptr inbounds %zfy.seq, ptr %r96, i32 0, i32 2
  %r98 = load i64, ptr %r97
  call void @zfy_print_i64(i64 %r98)
  %r99 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r99)
  store i64 17, ptr %v.m
  %r101 = load i64, ptr %v.m
  %r100 = srem i64 %r101, 5
  store i64 %r100, ptr %v.m
  %r102 = load i64, ptr %v.m
  call void @zfy_print_i64(i64 %r102)
  %r103 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r103)
  %r104 = load ptr, ptr %v.lst
  call void @zfy_seq_free(ptr %r104, i8 0)
  store ptr null, ptr %v.lst
  %r105 = load ptr, ptr %v.arr
  call void @zfy_seq_free(ptr %r105, i8 0)
  store ptr null, ptr %v.arr
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
