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
declare void @zfy_seq_remove(ptr, i64)
declare void @zfy_seq_aug_range(ptr, i64, i64, i64, i8, ptr, i32, i8, i8)
@.str1 = private unnamed_addr constant [4 x i8] c"abc\00"
@.str2 = private unnamed_addr constant [1 x i8] c"\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [1 x i8] c"\00"
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [1 x i8] c"\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [4 x i8] c"123\00"
@.str10 = private unnamed_addr constant [4 x i8] c"xyz\00"
@.str11 = private unnamed_addr constant [1 x i8] c"\00"
@.str12 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str13 = private unnamed_addr constant [1 x i8] c"\00"
@.str14 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.main() {
  %v.ib = alloca ptr
  store ptr null, ptr %v.ib
  %v.ia = alloca ptr
  store ptr null, ptr %v.ia
  %v.s2 = alloca ptr
  store ptr null, ptr %v.s2
  %v.s1 = alloca ptr
  store ptr null, ptr %v.s1
  %v.carr = alloca ptr
  store ptr null, ptr %v.carr
  %v.k = alloca i64
  store i64 zeroinitializer, ptr %v.k
  %v.one = alloca ptr
  store ptr null, ptr %v.one
  %v.s0 = alloca ptr
  store ptr null, ptr %v.s0
  %r1 = load ptr, ptr %v.s0
  call void @zfy_free_str(ptr %r1)
  %r2 = getelementptr inbounds [4 x i8], ptr @.str1, i64 0, i64 0
  %r3 = call ptr @zfy_strdup(ptr %r2)
  store ptr %r3, ptr %v.s0
  %r4 = load ptr, ptr %v.s0
  %r5 = getelementptr inbounds [1 x i8], ptr @.str2, i64 0, i64 0
  %t1 = call ptr @zfy_str_trim_str(ptr %r4, ptr %r5)
  call void @zfy_print_str(ptr %t1)
  %t2 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t2)
  call void @zfy_free_str(ptr %t1)
  call void @zfy_free_str(ptr %t2)
  %r6 = load ptr, ptr %v.one
  call void @zfy_seq_free(ptr %r6, i8 1)
  %r7 = load ptr, ptr %v.s0
  %r9 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  %r8 = call ptr @zfy_str_split_str(ptr %r7, ptr %r9)
  store ptr %r8, ptr %v.one
  %r10 = load ptr, ptr %v.one
  %r11 = getelementptr inbounds %zfy.seq, ptr %r10, i32 0, i32 2
  %r12 = load i64, ptr %r11
  call void @zfy_print_i64(i64 %r12)
  %t4 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t4)
  call void @zfy_free_str(ptr %t4)
  %r13 = add i64 0, 0
  %r14 = alloca i128
  %r15 = load ptr, ptr %v.one
  call void @zfy_seq_get(ptr %r15, i64 %r13, ptr %r14, i32 8, i8 0)
  %r16 = load i128, ptr %r14
  %r17 = trunc i128 %r16 to i64
  %r18 = inttoptr i64 %r17 to ptr
  call void @zfy_print_str(ptr %r18)
  %t7 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t7)
  call void @zfy_free_str(ptr %t7)
  %r19 = getelementptr inbounds [1 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r19)
  %r20 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r20)
  store i64 3, ptr %v.k
  br label %b1
b1:
  %r22 = load i64, ptr %v.k
  %r21 = icmp sgt i64 %r22, 0
  br i1 %r21, label %b2, label %b4
b2:
  %r23 = load i64, ptr %v.k
  call void @zfy_print_i64(i64 %r23)
  %t9 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t9)
  call void @zfy_free_str(ptr %t9)
  br label %b3
b3:
  %r25 = load i64, ptr %v.k
  %r24 = sub i64 %r25, 1
  store i64 %r24, ptr %v.k
  br label %b1
b4:
  %r26 = getelementptr inbounds [1 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r26)
  %r27 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r27)
  %r28 = call ptr @zfy_seq_new(i64 3, i64 3, i32 8)
  store ptr %r28, ptr %v.carr
  %r29 = load ptr, ptr %v.carr
  %r30 = sext i64 7 to i128
  %r31 = alloca i128
  store i128 %r30, ptr %r31
  call void @zfy_seq_set_w(ptr %r29, i64 0, ptr %r31, i32 8, i8 0)
  %r32 = load ptr, ptr %v.carr
  %r33 = sext i64 8 to i128
  %r34 = alloca i128
  store i128 %r33, ptr %r34
  call void @zfy_seq_set_w(ptr %r32, i64 1, ptr %r34, i32 8, i8 0)
  %r35 = load ptr, ptr %v.carr
  %r36 = sext i64 9 to i128
  %r37 = alloca i128
  store i128 %r36, ptr %r37
  call void @zfy_seq_set_w(ptr %r35, i64 2, ptr %r37, i32 8, i8 0)
  %r38 = add i64 2, 0
  %r39 = alloca i128
  %r40 = load ptr, ptr %v.carr
  call void @zfy_seq_get(ptr %r40, i64 %r38, ptr %r39, i32 8, i8 1)
  %r41 = load i128, ptr %r39
  %r42 = trunc i128 %r41 to i64
  call void @zfy_print_i64(i64 %r42)
  %r43 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r43)
  %r44 = load ptr, ptr %v.s1
  call void @zfy_free_str(ptr %r44)
  %r45 = getelementptr inbounds [4 x i8], ptr @.str9, i64 0, i64 0
  %r46 = call ptr @zfy_strdup(ptr %r45)
  store ptr %r46, ptr %v.s1
  %r47 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r47)
  %r48 = load ptr, ptr %v.s1
  %r49 = call ptr @zfy_strdup(ptr %r48)
  store ptr %r49, ptr %v.s2
  %r50 = load ptr, ptr %v.s2
  %r51 = getelementptr inbounds [4 x i8], ptr @.str10, i64 0, i64 0
  %t13 = call ptr @zfy_str_concat(ptr %r50, ptr %r51)
  %r52 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r52)
  %r53 = call ptr @zfy_strdup(ptr %t13)
  store ptr %r53, ptr %v.s2
  call void @zfy_free_str(ptr %t13)
  %r54 = load ptr, ptr %v.s1
  call void @zfy_print_str(ptr %r54)
  %t14 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t14)
  %r55 = load ptr, ptr %v.s2
  call void @zfy_print_str(ptr %r55)
  %t15 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t15)
  call void @zfy_free_str(ptr %t14)
  call void @zfy_free_str(ptr %t15)
  %r56 = getelementptr inbounds [1 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r56)
  %r57 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r57)
  %r58 = call ptr @zfy_seq_new(i64 3, i64 3, i32 4)
  store ptr %r58, ptr %v.ia
  %r59 = load ptr, ptr %v.ia
  %r60 = sext i32 1 to i128
  %r61 = alloca i128
  store i128 %r60, ptr %r61
  call void @zfy_seq_set_w(ptr %r59, i64 0, ptr %r61, i32 4, i8 0)
  %r62 = load ptr, ptr %v.ia
  %r63 = sext i32 2 to i128
  %r64 = alloca i128
  store i128 %r63, ptr %r64
  call void @zfy_seq_set_w(ptr %r62, i64 1, ptr %r64, i32 4, i8 0)
  %r65 = load ptr, ptr %v.ia
  %r66 = sext i32 3 to i128
  %r67 = alloca i128
  store i128 %r66, ptr %r67
  call void @zfy_seq_set_w(ptr %r65, i64 2, ptr %r67, i32 4, i8 0)
  %r68 = call ptr @zfy_seq_new(i64 3, i64 3, i32 4)
  store ptr %r68, ptr %v.ib
  %r69 = load ptr, ptr %v.ib
  call void @zfy_seq_free(ptr %r69, i8 0)
  %r70 = load ptr, ptr %v.ia
  %r71 = call ptr @zfy_seq_clone(ptr %r70, i8 0)
  store ptr %r71, ptr %v.ib
  %r72 = add i64 0, 0
  %r73 = load ptr, ptr %v.ib
  %r74 = sext i32 99 to i128
  %r75 = alloca i128
  store i128 %r74, ptr %r75
  call void @zfy_seq_set_w(ptr %r73, i64 %r72, ptr %r75, i32 4, i8 0)
  %r76 = add i64 0, 0
  %r77 = alloca i128
  %r78 = load ptr, ptr %v.ia
  call void @zfy_seq_get(ptr %r78, i64 %r76, ptr %r77, i32 4, i8 1)
  %r79 = load i128, ptr %r77
  %r80 = trunc i128 %r79 to i32
  %r81 = sext i32 %r80 to i64
  call void @zfy_print_i64(i64 %r81)
  %t19 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t19)
  %r82 = add i64 0, 0
  %r83 = alloca i128
  %r84 = load ptr, ptr %v.ib
  call void @zfy_seq_get(ptr %r84, i64 %r82, ptr %r83, i32 4, i8 1)
  %r85 = load i128, ptr %r83
  %r86 = trunc i128 %r85 to i32
  %r87 = sext i32 %r86 to i64
  call void @zfy_print_i64(i64 %r87)
  %t22 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t22)
  call void @zfy_free_str(ptr %t19)
  call void @zfy_free_str(ptr %t22)
  %r88 = getelementptr inbounds [1 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r88)
  %r89 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r89)
  %r90 = load ptr, ptr %v.ib
  call void @zfy_seq_free(ptr %r90, i8 0)
  store ptr null, ptr %v.ib
  %r91 = load ptr, ptr %v.ia
  call void @zfy_seq_free(ptr %r91, i8 0)
  store ptr null, ptr %v.ia
  %r92 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r92)
  store ptr null, ptr %v.s2
  %r93 = load ptr, ptr %v.s1
  call void @zfy_free_str(ptr %r93)
  store ptr null, ptr %v.s1
  %r94 = load ptr, ptr %v.carr
  call void @zfy_seq_free(ptr %r94, i8 0)
  store ptr null, ptr %v.carr
  %r95 = load ptr, ptr %v.s0
  call void @zfy_free_str(ptr %r95)
  store ptr null, ptr %v.s0
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
