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
@.str1 = private unnamed_addr constant [12 x i8] c"Hello World\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [2 x i8] c",\00"
@.str12 = private unnamed_addr constant [2 x i8] c",\00"
@.str13 = private unnamed_addr constant [2 x i8] c",\00"
@.str14 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str15 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str16 = private unnamed_addr constant [4 x i8] c"zfy\00"
@.str17 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str18 = private unnamed_addr constant [2 x i8] c"!\00"
@.str19 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str20 = private unnamed_addr constant [4 x i8] c"zfy\00"
@.str21 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str22 = private unnamed_addr constant [2 x i8] c"x\00"
@.str23 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.g = alloca ptr
  %v.m = alloca ptr
  %v.n = alloca ptr
  %r34 = alloca i128
  %r41 = alloca i128
  %r48 = alloca i128
  %r55 = alloca i128
  store ptr null, ptr %v.g
  store ptr null, ptr %v.m
  store ptr null, ptr %v.n
  %r1 = load ptr, ptr %v.n
  call void @zfy_free_str(ptr %r1)
  %r2 = getelementptr inbounds [12 x i8], ptr @.str1, i64 0, i64 0
  %r3 = call ptr @zfy_strdup(ptr %r2)
  store ptr %r3, ptr %v.n
  %r4 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r4, ptr %v.m
  %r5 = load ptr, ptr %v.n
  %t1 = call i64 @strlen(ptr %r5)
  call void @zfy_print_i64(i64 %t1)
  %r6 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r6)
  %r7 = add i64 4, 0
  %r8 = load ptr, ptr %v.n
  %t3 = call i8 @zfy_str_char(ptr %r8, i64 %r7)
  call void @zfy_print_char(i8 %t3)
  %r9 = getelementptr inbounds [2 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r9)
  %r10 = add i64 4, 0
  %r11 = add i64 10, 0
  %r12 = load ptr, ptr %v.n
  %t6 = call ptr @zfy_str_slice(ptr %r12, i64 %r10, i64 %r11, i64 1)
  call void @zfy_print_str(ptr %t6)
  %r13 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r13)
  call void @zfy_free_str(ptr %t6)
  %r14 = add i64 4, 0
  %r15 = add i64 10, 0
  %r16 = add i64 2, 0
  %r17 = load ptr, ptr %v.n
  %t10 = call ptr @zfy_str_slice(ptr %r17, i64 %r14, i64 %r15, i64 %r16)
  call void @zfy_print_str(ptr %t10)
  %r18 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r18)
  call void @zfy_free_str(ptr %t10)
  %r19 = load ptr, ptr %v.n
  %t11 = call i64 @zfy_str_find(ptr %r19, i8 108, i64 1)
  call void @zfy_print_i64(i64 %t11)
  %r20 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r20)
  %r21 = add i64 2, 0
  %r22 = load ptr, ptr %v.n
  %t13 = call i64 @zfy_str_find(ptr %r22, i8 108, i64 %r21)
  call void @zfy_print_i64(i64 %t13)
  %r23 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r23)
  %r24 = add i64 3, 0
  %r25 = load ptr, ptr %v.n
  %t15 = call i64 @zfy_str_find(ptr %r25, i8 108, i64 %r24)
  call void @zfy_print_i64(i64 %t15)
  %r26 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r26)
  %r27 = load ptr, ptr %v.n
  %t16 = call i64 @zfy_str_find(ptr %r27, i8 122, i64 1)
  call void @zfy_print_i64(i64 %t16)
  %r28 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r28)
  %r29 = load ptr, ptr %v.n
  %t17 = call ptr @zfy_str_trim(ptr %r29, i8 108)
  call void @zfy_print_str(ptr %t17)
  %r30 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r30)
  call void @zfy_free_str(ptr %t17)
  %r31 = load ptr, ptr %v.n
  %t18 = call ptr @zfy_str_split(ptr %r31, i8 108)
  %r32 = load ptr, ptr %v.m
  call void @zfy_seq_free(ptr %r32, i8 1)
  store ptr %t18, ptr %v.m
  %r33 = add i64 0, 0
  %r35 = load ptr, ptr %v.m
  call void @zfy_seq_get(ptr %r35, i64 %r33, ptr %r34, i32 8, i8 0)
  %r36 = load i128, ptr %r34
  %r37 = trunc i128 %r36 to i64
  %r38 = inttoptr i64 %r37 to ptr
  call void @zfy_print_str(ptr %r38)
  %r39 = getelementptr inbounds [2 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r39)
  %r40 = add i64 1, 0
  %r42 = load ptr, ptr %v.m
  call void @zfy_seq_get(ptr %r42, i64 %r40, ptr %r41, i32 8, i8 0)
  %r43 = load i128, ptr %r41
  %r44 = trunc i128 %r43 to i64
  %r45 = inttoptr i64 %r44 to ptr
  call void @zfy_print_str(ptr %r45)
  %r46 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r46)
  %r47 = add i64 2, 0
  %r49 = load ptr, ptr %v.m
  call void @zfy_seq_get(ptr %r49, i64 %r47, ptr %r48, i32 8, i8 0)
  %r50 = load i128, ptr %r48
  %r51 = trunc i128 %r50 to i64
  %r52 = inttoptr i64 %r51 to ptr
  call void @zfy_print_str(ptr %r52)
  %r53 = getelementptr inbounds [2 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r53)
  %r54 = add i64 3, 0
  %r56 = load ptr, ptr %v.m
  call void @zfy_seq_get(ptr %r56, i64 %r54, ptr %r55, i32 8, i8 0)
  %r57 = load i128, ptr %r55
  %r58 = trunc i128 %r57 to i64
  %r59 = inttoptr i64 %r58 to ptr
  call void @zfy_print_str(ptr %r59)
  %r60 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r60)
  %r61 = load ptr, ptr %v.m
  %r62 = getelementptr inbounds %zfy.seq, ptr %r61, i32 0, i32 2
  %r63 = load i64, ptr %r62
  call void @zfy_print_i64(i64 %r63)
  %r64 = getelementptr inbounds [2 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r64)
  %r65 = add i64 6, 0
  %r66 = add i64 10, 0
  %r67 = load ptr, ptr %v.n
  %r68 = getelementptr inbounds [4 x i8], ptr @.str16, i64 0, i64 0
  %t30 = call ptr @zfy_str_replace(ptr %r67, i64 %r65, i64 %r66, ptr %r68)
  call void @zfy_print_str(ptr %t30)
  %r69 = getelementptr inbounds [2 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r69)
  call void @zfy_free_str(ptr %t30)
  %r70 = load ptr, ptr %v.n
  %r71 = getelementptr inbounds [2 x i8], ptr @.str18, i64 0, i64 0
  %t31 = call ptr @zfy_str_concat(ptr %r70, ptr %r71)
  %r72 = load ptr, ptr %v.g
  call void @zfy_free_str(ptr %r72)
  %r73 = call ptr @zfy_strdup(ptr %t31)
  store ptr %r73, ptr %v.g
  call void @zfy_free_str(ptr %t31)
  %r74 = load ptr, ptr %v.g
  call void @zfy_print_str(ptr %r74)
  %r75 = getelementptr inbounds [2 x i8], ptr @.str19, i64 0, i64 0
  call void @zfy_print_str(ptr %r75)
  %r76 = load ptr, ptr %v.g
  call void @zfy_free_str(ptr %r76)
  %r77 = getelementptr inbounds [4 x i8], ptr @.str20, i64 0, i64 0
  %r78 = call ptr @zfy_strdup(ptr %r77)
  store ptr %r78, ptr %v.g
  %r79 = load ptr, ptr %v.g
  call void @zfy_print_str(ptr %r79)
  %r80 = getelementptr inbounds [2 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r80)
  %r81 = getelementptr inbounds [2 x i8], ptr @.str22, i64 0, i64 0
  %r82 = load ptr, ptr %v.g
  %t32 = call ptr @zfy_str_concat(ptr %r81, ptr %r82)
  call void @zfy_print_str(ptr %t32)
  %r83 = getelementptr inbounds [2 x i8], ptr @.str23, i64 0, i64 0
  call void @zfy_print_str(ptr %r83)
  call void @zfy_free_str(ptr %t32)
  %r84 = load ptr, ptr %v.g
  call void @zfy_free_str(ptr %r84)
  store ptr null, ptr %v.g
  %r85 = load ptr, ptr %v.m
  call void @zfy_seq_free(ptr %r85, i8 1)
  store ptr null, ptr %v.m
  %r86 = load ptr, ptr %v.n
  call void @zfy_free_str(ptr %r86)
  store ptr null, ptr %v.n
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
