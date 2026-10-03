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
@.str1 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str4 = private unnamed_addr constant [10 x i8] c"hello_zfy\00"
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [3 x i8] c"|\0A\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [8 x i8] c"nothing\00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [3 x i8] c"|\0A\00"
@.str12 = private unnamed_addr constant [4 x i8] c"123\00"
@.str13 = private unnamed_addr constant [8 x i8] c"3.14abc\00"
@.str14 = private unnamed_addr constant [1 x i8] c"\00"
@.str15 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str16 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str17 = private unnamed_addr constant [3 x i8] c"|\0A\00"
@.str18 = private unnamed_addr constant [3 x i8] c"|\0A\00"
@.str19 = private unnamed_addr constant [1 x i8] c"\00"
@.str20 = private unnamed_addr constant [1 x i8] c"\00"
@.str21 = private unnamed_addr constant [1 x i8] c"\00"
@.str22 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str23 = private unnamed_addr constant [3 x i8] c"|\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.f = alloca %frac.i32
  %v.b3 = alloca i1
  %v.es = alloca ptr
  %v.b2 = alloca i1
  %v.zero = alloca i32
  %v.b1 = alloca i1
  %v.nz = alloca i32
  %v.dq = alloca double
  %v.sq = alloca ptr
  %v.q = alloca i32
  %v.big = alloca i128
  %v.d1 = alloca double
  %v.i1 = alloca i32
  %v.n2 = alloca ptr
  %v.n1 = alloca ptr
  %v.s = alloca ptr
  %v.cy = alloca i8
  %v.y = alloca i32
  %v.x = alloca x86_fp80
  %r58 = alloca i128
  %r95 = alloca %frac.i32
  store %frac.i32 zeroinitializer, ptr %v.f
  store i1 zeroinitializer, ptr %v.b3
  store ptr null, ptr %v.es
  store i1 zeroinitializer, ptr %v.b2
  store i32 zeroinitializer, ptr %v.zero
  store i1 zeroinitializer, ptr %v.b1
  store i32 zeroinitializer, ptr %v.nz
  store double zeroinitializer, ptr %v.dq
  store ptr null, ptr %v.sq
  store i32 zeroinitializer, ptr %v.q
  store i128 zeroinitializer, ptr %v.big
  store double zeroinitializer, ptr %v.d1
  store i32 zeroinitializer, ptr %v.i1
  store ptr null, ptr %v.n2
  store ptr null, ptr %v.n1
  store ptr null, ptr %v.s
  store i8 zeroinitializer, ptr %v.cy
  store i32 zeroinitializer, ptr %v.y
  store x86_fp80 zeroinitializer, ptr %v.x
  store x86_fp80 0xK4000C90FDAA21EB7A000, ptr %v.x
  %r1 = load x86_fp80, ptr %v.x
  %r2 = fptrunc x86_fp80 %r1 to double
  %r3 = call ptr @zfy_tostr_f64(double %r2)
  %t1 = call ptr @zfy_prec_str(ptr %r3, i64 5)
  call void @zfy_print_str(ptr %t1)
  %r4 = getelementptr inbounds [2 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r4)
  call void @zfy_free_str(ptr %t1)
  store i32 6, ptr %v.y
  %r5 = load i32, ptr %v.y
  %r6 = sext i32 %r5 to i64
  %r7 = load x86_fp80, ptr %v.x
  %r8 = fptrunc x86_fp80 %r7 to double
  %r9 = call ptr @zfy_tostr_f64(double %r8)
  %t2 = call ptr @zfy_prec_str(ptr %r9, i64 %r6)
  call void @zfy_print_str(ptr %t2)
  %r10 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r10)
  call void @zfy_free_str(ptr %t2)
  store i8 54, ptr %v.cy
  %r11 = load i8, ptr %v.cy
  %r12 = call i64 @zfy_char_digit(i8 %r11)
  %r13 = load x86_fp80, ptr %v.x
  %r14 = fptrunc x86_fp80 %r13 to double
  %r15 = call ptr @zfy_tostr_f64(double %r14)
  %t3 = call ptr @zfy_prec_str(ptr %r15, i64 %r12)
  call void @zfy_print_str(ptr %t3)
  %r16 = getelementptr inbounds [2 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r16)
  call void @zfy_free_str(ptr %t3)
  %r17 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r17)
  %r18 = getelementptr inbounds [10 x i8], ptr @.str4, i64 0, i64 0
  %r19 = call ptr @zfy_strdup(ptr %r18)
  store ptr %r19, ptr %v.s
  %r20 = load ptr, ptr %v.s
  %t4 = call ptr @zfy_prec_str(ptr %r20, i64 2)
  call void @zfy_print_str(ptr %t4)
  %r21 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r21)
  call void @zfy_free_str(ptr %t4)
  %r22 = load ptr, ptr %v.s
  %t5 = call ptr @zfy_prec_str(ptr %r22, i64 20)
  call void @zfy_print_str(ptr %t5)
  %r23 = getelementptr inbounds [3 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r23)
  call void @zfy_free_str(ptr %t5)
  %r24 = load x86_fp80, ptr %v.x
  %r25 = fptrunc x86_fp80 %r24 to double
  %r26 = call ptr @zfy_tostr_f64(double %r25)
  %t6 = call ptr @zfy_prec_str(ptr %r26, i64 1)
  call void @zfy_print_str(ptr %t6)
  %r27 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r27)
  call void @zfy_free_str(ptr %t6)
  %r28 = load x86_fp80, ptr %v.x
  %r29 = fptrunc x86_fp80 %r28 to double
  %r30 = call ptr @zfy_tostr_f64(double %r29)
  %t7 = call ptr @zfy_prec_str(ptr %r30, i64 2)
  call void @zfy_print_str(ptr %t7)
  %r31 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r31)
  call void @zfy_free_str(ptr %t7)
  %r32 = getelementptr inbounds [8 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r32)
  %r33 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r33)
  %r34 = load x86_fp80, ptr %v.x
  %r35 = fptrunc x86_fp80 %r34 to double
  call void @zfy_print_f64(double %r35)
  %r36 = getelementptr inbounds [3 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r36)
  %r37 = load ptr, ptr %v.n1
  call void @zfy_free_str(ptr %r37)
  %r38 = getelementptr inbounds [4 x i8], ptr @.str12, i64 0, i64 0
  %r39 = call ptr @zfy_strdup(ptr %r38)
  store ptr %r39, ptr %v.n1
  %r40 = load ptr, ptr %v.n2
  call void @zfy_free_str(ptr %r40)
  %r41 = getelementptr inbounds [8 x i8], ptr @.str13, i64 0, i64 0
  %r42 = call ptr @zfy_strdup(ptr %r41)
  store ptr %r42, ptr %v.n2
  %r44 = load ptr, ptr %v.n1
  %r45 = call i64 @zfy_stoi(ptr %r44)
  %r43 = trunc i64 %r45 to i32
  store i32 %r43, ptr %v.i1
  %r47 = load ptr, ptr %v.n2
  %r48 = call double @zfy_stod(ptr %r47)
  %r46 = fadd double %r48, 0.0
  store double %r46, ptr %v.d1
  %r49 = load i32, ptr %v.i1
  %r50 = sext i32 %r49 to i64
  call void @zfy_print_i64(i64 %r50)
  %r51 = getelementptr inbounds [1 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r51)
  %r52 = load double, ptr %v.d1
  call void @zfy_print_f64(double %r52)
  %r53 = getelementptr inbounds [2 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r53)
  %r55 = load ptr, ptr %v.n1
  %r56 = call i64 @zfy_stoi(ptr %r55)
  %r54 = sext i64 %r56 to i128
  store i128 %r54, ptr %v.big
  %r57 = load i128, ptr %v.big
  store i128 %r57, ptr %r58
  call void @zfy_print_i128(ptr %r58)
  %r59 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r59)
  store i32 42, ptr %v.q
  %r61 = load i32, ptr %v.q
  %r62 = load i32, ptr %v.q
  %r63 = sext i32 %r62 to i64
  %r64 = call ptr @zfy_tostr_i64(i64 %r63)
  %r60 = call ptr @zfy_strdup(ptr %r64)
  %r65 = load ptr, ptr %v.sq
  call void @zfy_free_str(ptr %r65)
  %r66 = call ptr @zfy_strdup(ptr %r60)
  store ptr %r66, ptr %v.sq
  %r67 = load ptr, ptr %v.sq
  call void @zfy_print_str(ptr %r67)
  %r68 = getelementptr inbounds [3 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r68)
  store double 2.5, ptr %v.dq
  %r70 = load double, ptr %v.dq
  %r71 = load double, ptr %v.dq
  %r72 = call ptr @zfy_tostr_f64(double %r71)
  %r69 = call ptr @zfy_strdup(ptr %r72)
  call void @zfy_print_str(ptr %r69)
  %r73 = getelementptr inbounds [3 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_print_str(ptr %r73)
  store i32 7, ptr %v.nz
  %r75 = load i32, ptr %v.nz
  %r74 = icmp ne i32 %r75, 0
  store i1 %r74, ptr %v.b1
  store i32 0, ptr %v.zero
  %r77 = load i32, ptr %v.zero
  %r76 = icmp ne i32 %r77, 0
  store i1 %r76, ptr %v.b2
  %r78 = load ptr, ptr %v.es
  call void @zfy_free_str(ptr %r78)
  %r79 = getelementptr inbounds [1 x i8], ptr @.str19, i64 0, i64 0
  %r80 = call ptr @zfy_strdup(ptr %r79)
  store ptr %r80, ptr %v.es
  %r82 = load ptr, ptr %v.es
  %r83 = call i64 @strlen(ptr %r82)
  %r81 = icmp ne i64 %r83, 0
  store i1 %r81, ptr %v.b3
  %r84 = load i1, ptr %v.b1
  %r85 = zext i1 %r84 to i32
  call void @zfy_print_bool(i32 %r85)
  %r86 = getelementptr inbounds [1 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r86)
  %r87 = load i1, ptr %v.b2
  %r88 = zext i1 %r87 to i32
  call void @zfy_print_bool(i32 %r88)
  %r89 = getelementptr inbounds [1 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r89)
  %r90 = load i1, ptr %v.b3
  %r91 = zext i1 %r90 to i32
  call void @zfy_print_bool(i32 %r91)
  %r92 = getelementptr inbounds [2 x i8], ptr @.str22, i64 0, i64 0
  call void @zfy_print_str(ptr %r92)
  %r93 = trunc i64 6 to i32
  %r94 = trunc i64 48 to i32
  %r96 = getelementptr inbounds %frac.i32, ptr %r95, i32 0, i32 0
  store i32 %r93, ptr %r96
  %r97 = getelementptr inbounds %frac.i32, ptr %r95, i32 0, i32 1
  store i32 %r94, ptr %r97
  call void @llvm.memcpy.p0.p0.i64(ptr %v.f, ptr %r95, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.f)
  %r98 = call ptr @zfy_frac_str_i32(ptr %v.f)
  %t19 = call ptr @zfy_prec_str(ptr %r98, i64 3)
  call void @zfy_print_str(ptr %t19)
  %r99 = getelementptr inbounds [3 x i8], ptr @.str23, i64 0, i64 0
  call void @zfy_print_str(ptr %r99)
  call void @zfy_free_str(ptr %t19)
  %r100 = load ptr, ptr %v.es
  call void @zfy_free_str(ptr %r100)
  store ptr null, ptr %v.es
  %r101 = load ptr, ptr %v.sq
  call void @zfy_free_str(ptr %r101)
  store ptr null, ptr %v.sq
  %r102 = load ptr, ptr %v.n2
  call void @zfy_free_str(ptr %r102)
  store ptr null, ptr %v.n2
  %r103 = load ptr, ptr %v.n1
  call void @zfy_free_str(ptr %r103)
  store ptr null, ptr %v.n1
  %r104 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r104)
  store ptr null, ptr %v.s
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
