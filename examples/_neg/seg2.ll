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
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [8 x i8] c"A\09B\0BC\07D\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [6 x i8] c"hello\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.main() {
  %v.pos = alloca i64
  store i64 zeroinitializer, ptr %v.pos
  %v.pi$1 = alloca i32
  store i32 zeroinitializer, ptr %v.pi$1
  %v.pi = alloca double
  store double zeroinitializer, ptr %v.pi
  %v.sb = alloca ptr
  store ptr null, ptr %v.sb
  %v.sa = alloca ptr
  store ptr null, ptr %v.sa
  %r1 = call ptr @zfy_seq_new(i64 6, i64 6, i32 8)
  store ptr %r1, ptr %v.sa
  %r2 = load ptr, ptr %v.sa
  %r3 = sext i64 1 to i128
  %r4 = alloca i128
  store i128 %r3, ptr %r4
  call void @zfy_seq_set_w(ptr %r2, i64 0, ptr %r4, i32 8, i8 0)
  %r5 = load ptr, ptr %v.sa
  %r6 = sext i64 2 to i128
  %r7 = alloca i128
  store i128 %r6, ptr %r7
  call void @zfy_seq_set_w(ptr %r5, i64 1, ptr %r7, i32 8, i8 0)
  %r8 = load ptr, ptr %v.sa
  %r9 = sext i64 3 to i128
  %r10 = alloca i128
  store i128 %r9, ptr %r10
  call void @zfy_seq_set_w(ptr %r8, i64 2, ptr %r10, i32 8, i8 0)
  %r11 = load ptr, ptr %v.sa
  %r12 = sext i64 4 to i128
  %r13 = alloca i128
  store i128 %r12, ptr %r13
  call void @zfy_seq_set_w(ptr %r11, i64 3, ptr %r13, i32 8, i8 0)
  %r14 = load ptr, ptr %v.sa
  %r15 = sext i64 5 to i128
  %r16 = alloca i128
  store i128 %r15, ptr %r16
  call void @zfy_seq_set_w(ptr %r14, i64 4, ptr %r16, i32 8, i8 0)
  %r17 = load ptr, ptr %v.sa
  %r18 = sext i64 6 to i128
  %r19 = alloca i128
  store i128 %r18, ptr %r19
  call void @zfy_seq_set_w(ptr %r17, i64 5, ptr %r19, i32 8, i8 0)
  %r20 = add i64 3, 0
  %r21 = add i64 1, 0
  %r22 = load ptr, ptr %v.sa
  %r23 = alloca i128
  %r24 = zext i64 10 to i128
  store i128 %r24, ptr %r23
  call void @zfy_seq_aug_range(ptr %r22, i64 %r21, i64 %r20, i64 1, i8 0, ptr %r23, i32 64, i8 1, i8 0)
  %r25 = add i64 0, 0
  %r26 = alloca i128
  %r27 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r27, i64 %r25, ptr %r26, i32 8, i8 1)
  %r28 = load i128, ptr %r26
  %r29 = trunc i128 %r28 to i64
  call void @zfy_print_i64(i64 %r29)
  %t5 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t5)
  %r30 = add i64 1, 0
  %r31 = alloca i128
  %r32 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r32, i64 %r30, ptr %r31, i32 8, i8 1)
  %r33 = load i128, ptr %r31
  %r34 = trunc i128 %r33 to i64
  call void @zfy_print_i64(i64 %r34)
  %t8 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t8)
  %r35 = add i64 2, 0
  %r36 = alloca i128
  %r37 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r37, i64 %r35, ptr %r36, i32 8, i8 1)
  %r38 = load i128, ptr %r36
  %r39 = trunc i128 %r38 to i64
  call void @zfy_print_i64(i64 %r39)
  %t11 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t11)
  %r40 = add i64 3, 0
  %r41 = alloca i128
  %r42 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r42, i64 %r40, ptr %r41, i32 8, i8 1)
  %r43 = load i128, ptr %r41
  %r44 = trunc i128 %r43 to i64
  call void @zfy_print_i64(i64 %r44)
  %t14 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t14)
  %r45 = add i64 4, 0
  %r46 = alloca i128
  %r47 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r47, i64 %r45, ptr %r46, i32 8, i8 1)
  %r48 = load i128, ptr %r46
  %r49 = trunc i128 %r48 to i64
  call void @zfy_print_i64(i64 %r49)
  %t17 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t17)
  %r50 = add i64 5, 0
  %r51 = alloca i128
  %r52 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r52, i64 %r50, ptr %r51, i32 8, i8 1)
  %r53 = load i128, ptr %r51
  %r54 = trunc i128 %r53 to i64
  call void @zfy_print_i64(i64 %r54)
  %t20 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t20)
  call void @zfy_free_str(ptr %t5)
  call void @zfy_free_str(ptr %t8)
  call void @zfy_free_str(ptr %t11)
  call void @zfy_free_str(ptr %t14)
  call void @zfy_free_str(ptr %t17)
  call void @zfy_free_str(ptr %t20)
  %r55 = getelementptr inbounds [1 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r55)
  %r56 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r56)
  %r57 = call ptr @zfy_seq_new(i64 6, i64 6, i32 8)
  store ptr %r57, ptr %v.sb
  %r58 = load ptr, ptr %v.sb
  %r59 = sext i64 1 to i128
  %r60 = alloca i128
  store i128 %r59, ptr %r60
  call void @zfy_seq_set_w(ptr %r58, i64 0, ptr %r60, i32 8, i8 0)
  %r61 = load ptr, ptr %v.sb
  %r62 = sext i64 2 to i128
  %r63 = alloca i128
  store i128 %r62, ptr %r63
  call void @zfy_seq_set_w(ptr %r61, i64 1, ptr %r63, i32 8, i8 0)
  %r64 = load ptr, ptr %v.sb
  %r65 = sext i64 3 to i128
  %r66 = alloca i128
  store i128 %r65, ptr %r66
  call void @zfy_seq_set_w(ptr %r64, i64 2, ptr %r66, i32 8, i8 0)
  %r67 = load ptr, ptr %v.sb
  %r68 = sext i64 4 to i128
  %r69 = alloca i128
  store i128 %r68, ptr %r69
  call void @zfy_seq_set_w(ptr %r67, i64 3, ptr %r69, i32 8, i8 0)
  %r70 = load ptr, ptr %v.sb
  %r71 = sext i64 5 to i128
  %r72 = alloca i128
  store i128 %r71, ptr %r72
  call void @zfy_seq_set_w(ptr %r70, i64 4, ptr %r72, i32 8, i8 0)
  %r73 = load ptr, ptr %v.sb
  %r74 = sext i64 6 to i128
  %r75 = alloca i128
  store i128 %r74, ptr %r75
  call void @zfy_seq_set_w(ptr %r73, i64 5, ptr %r75, i32 8, i8 0)
  %r76 = add i64 2, 0
  %r77 = add i64 5, 0
  %r78 = add i64 0, 0
  %r79 = load ptr, ptr %v.sb
  %r80 = alloca i128
  %r81 = zext i64 3 to i128
  store i128 %r81, ptr %r80
  call void @zfy_seq_aug_range(ptr %r79, i64 %r78, i64 %r77, i64 %r76, i8 2, ptr %r80, i32 64, i8 1, i8 0)
  %r82 = add i64 0, 0
  %r83 = alloca i128
  %r84 = load ptr, ptr %v.sb
  call void @zfy_seq_get(ptr %r84, i64 %r82, ptr %r83, i32 8, i8 1)
  %r85 = load i128, ptr %r83
  %r86 = trunc i128 %r85 to i64
  call void @zfy_print_i64(i64 %r86)
  %t26 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t26)
  %r87 = add i64 2, 0
  %r88 = alloca i128
  %r89 = load ptr, ptr %v.sb
  call void @zfy_seq_get(ptr %r89, i64 %r87, ptr %r88, i32 8, i8 1)
  %r90 = load i128, ptr %r88
  %r91 = trunc i128 %r90 to i64
  call void @zfy_print_i64(i64 %r91)
  %t29 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t29)
  %r92 = add i64 4, 0
  %r93 = alloca i128
  %r94 = load ptr, ptr %v.sb
  call void @zfy_seq_get(ptr %r94, i64 %r92, ptr %r93, i32 8, i8 1)
  %r95 = load i128, ptr %r93
  %r96 = trunc i128 %r95 to i64
  call void @zfy_print_i64(i64 %r96)
  %t32 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t32)
  call void @zfy_free_str(ptr %t26)
  call void @zfy_free_str(ptr %t29)
  call void @zfy_free_str(ptr %t32)
  %r97 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r97)
  %r98 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r98)
  store double 3.75, ptr %v.pi
  %r100 = load double, ptr %v.pi
  %r99 = fptosi double %r100 to i32
  store i32 %r99, ptr %v.pi$1
  %r101 = load i32, ptr %v.pi$1
  %r102 = sext i32 %r101 to i64
  call void @zfy_print_i64(i64 %r102)
  %r103 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r103)
  %r104 = getelementptr inbounds [8 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r104)
  %r105 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r105)
  %r106 = add i64 2, 0
  %r107 = getelementptr inbounds [6 x i8], ptr @.str8, i64 0, i64 0
  %t35 = call i64 @zfy_str_find(ptr %r107, i8 108, i64 %r106)
  store i64 %t35, ptr %v.pos
  %r108 = load i64, ptr %v.pos
  call void @zfy_print_i64(i64 %r108)
  %r109 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r109)
  %r110 = load ptr, ptr %v.sb
  call void @zfy_seq_free(ptr %r110, i8 0)
  store ptr null, ptr %v.sb
  %r111 = load ptr, ptr %v.sa
  call void @zfy_seq_free(ptr %r111, i8 0)
  store ptr null, ptr %v.sa
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
