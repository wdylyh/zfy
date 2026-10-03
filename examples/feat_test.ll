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
@.str1 = private unnamed_addr constant [4 x i8] c"a\09b\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [17 x i8] c"\E5\BC\95:\22q\22 \E5\8F\8D\E6\96\9C:\5C\00"
@.str4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str5 = private unnamed_addr constant [8 x i8] c"\E6\8D\A2\0A\E8\A1\8C\00"
@.str6 = private unnamed_addr constant [1 x i8] c"\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [2 x i8] c"[\00"
@.str9 = private unnamed_addr constant [1 x i8] c"\00"
@.str10 = private unnamed_addr constant [1 x i8] c"\00"
@.str11 = private unnamed_addr constant [2 x i8] c"]\00"
@.str12 = private unnamed_addr constant [2 x i8] c"[\00"
@.str13 = private unnamed_addr constant [1 x i8] c"\00"
@.str14 = private unnamed_addr constant [1 x i8] c"\00"
@.str15 = private unnamed_addr constant [2 x i8] c"]\00"
@.str16 = private unnamed_addr constant [2 x i8] c"[\00"
@.str17 = private unnamed_addr constant [1 x i8] c"\00"
@.str18 = private unnamed_addr constant [1 x i8] c"\00"
@.str19 = private unnamed_addr constant [2 x i8] c"]\00"
@.str20 = private unnamed_addr constant [2 x i8] c"[\00"
@.str21 = private unnamed_addr constant [1 x i8] c"\00"
@.str22 = private unnamed_addr constant [1 x i8] c"\00"
@.str23 = private unnamed_addr constant [2 x i8] c"]\00"
@.str24 = private unnamed_addr constant [2 x i8] c"[\00"
@.str25 = private unnamed_addr constant [1 x i8] c"\00"
@.str26 = private unnamed_addr constant [1 x i8] c"\00"
@.str27 = private unnamed_addr constant [2 x i8] c"]\00"
@.str28 = private unnamed_addr constant [2 x i8] c",\00"
@.str29 = private unnamed_addr constant [9 x i8] c"from-var\00"
@.str30 = private unnamed_addr constant [4 x i8] c"lit\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.big = alloca i64
  %v.dn = alloca double
  %v.dd = alloca double
  %v.f = alloca float
  %v.d = alloca double
  %v.b = alloca i64
  %v.a = alloca i32
  %v.m3 = alloca i64
  %v.m2 = alloca i64
  %v.n = alloca ptr
  %v.m = alloca i64
  store i64 zeroinitializer, ptr %v.big
  store double zeroinitializer, ptr %v.dn
  store double zeroinitializer, ptr %v.dd
  store float zeroinitializer, ptr %v.f
  store double zeroinitializer, ptr %v.d
  store i64 zeroinitializer, ptr %v.b
  store i32 zeroinitializer, ptr %v.a
  store i64 zeroinitializer, ptr %v.m3
  store i64 zeroinitializer, ptr %v.m2
  store ptr null, ptr %v.n
  store i64 zeroinitializer, ptr %v.m
  %r1 = getelementptr inbounds [4 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r1)
  %r2 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r2)
  %r3 = getelementptr inbounds [17 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r3)
  %r4 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r4)
  call void @zfy_print_char(i8 39)
  %t1 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t1)
  call void @zfy_free_str(ptr %t1)
  %r5 = getelementptr inbounds [8 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r5)
  %t2 = call ptr @zfy_tostr_char(i8 33)
  call void @zfy_print_str(ptr %t2)
  call void @zfy_free_str(ptr %t2)
  %r6 = getelementptr inbounds [1 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r6)
  %r7 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r7)
  store i64 42, ptr %v.m
  %r8 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r8)
  %r9 = getelementptr inbounds [1 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r9)
  %r10 = load i64, ptr %v.m
  call void @zfy_print_i64(i64 %r10)
  %r11 = getelementptr inbounds [1 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r11)
  %r12 = getelementptr inbounds [2 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r12)
  %t3 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t3)
  call void @zfy_free_str(ptr %t3)
  %r13 = call ptr @zfy_seq_new(i64 4, i64 4, i32 4)
  store ptr %r13, ptr %v.n
  %r14 = load ptr, ptr %v.n
  %r15 = getelementptr inbounds %zfy.seq, ptr %r14, i32 0, i32 2
  %r16 = load i64, ptr %r15
  %r17 = icmp ult i64 0, %r16
  br i1 %r17, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r18 = load ptr, ptr %r14
  %r19 = mul i64 0, 4
  %r20 = getelementptr inbounds i8, ptr %r18, i64 %r19
  %r21 = sext i32 1 to i128
  %r22 = trunc i128 %r21 to i32
  store i32 %r22, ptr %r20, align 1
  br label %L3
L3:
  %r23 = load ptr, ptr %v.n
  %r24 = getelementptr inbounds %zfy.seq, ptr %r23, i32 0, i32 2
  %r25 = load i64, ptr %r24
  %r26 = icmp ult i64 1, %r25
  br i1 %r26, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r27 = load ptr, ptr %r23
  %r28 = mul i64 1, 4
  %r29 = getelementptr inbounds i8, ptr %r27, i64 %r28
  %r30 = sext i32 2 to i128
  %r31 = trunc i128 %r30 to i32
  store i32 %r31, ptr %r29, align 1
  br label %L6
L6:
  %r32 = add i64 2, 0
  %r33 = load ptr, ptr %v.n
  %r34 = getelementptr inbounds %zfy.seq, ptr %r33, i32 0, i32 2
  %r35 = load i64, ptr %r34
  %r36 = icmp ult i64 %r32, %r35
  br i1 %r36, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r37 = load ptr, ptr %r33
  %r38 = mul i64 %r32, 4
  %r39 = getelementptr inbounds i8, ptr %r37, i64 %r38
  %r40 = load i32, ptr %r39, align 1
  %r41 = sext i32 %r40 to i128
  br label %L9
L9:
  %r42 = trunc i128 %r41 to i32
  %r43 = sext i32 %r42 to i64
  store i64 %r43, ptr %v.m
  %r44 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r44)
  %r45 = getelementptr inbounds [1 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r45)
  %r46 = load i64, ptr %v.m
  call void @zfy_print_i64(i64 %r46)
  %r47 = getelementptr inbounds [1 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r47)
  %r48 = getelementptr inbounds [2 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r48)
  %t7 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t7)
  call void @zfy_free_str(ptr %t7)
  %r50 = load i64, ptr %v.m
  %r49 = add i64 %r50, 1
  store i64 %r49, ptr %v.m2
  %r51 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r51)
  %r52 = getelementptr inbounds [1 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r52)
  %r53 = load i64, ptr %v.m2
  call void @zfy_print_i64(i64 %r53)
  %r54 = getelementptr inbounds [1 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_print_str(ptr %r54)
  %r55 = getelementptr inbounds [2 x i8], ptr @.str19, i64 0, i64 0
  call void @zfy_print_str(ptr %r55)
  %t9 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t9)
  call void @zfy_free_str(ptr %t9)
  %r56 = load i64, ptr %v.m
  store i64 %r56, ptr %v.m3
  %r57 = getelementptr inbounds [2 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r57)
  %r58 = getelementptr inbounds [1 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r58)
  %r59 = load i64, ptr %v.m3
  call void @zfy_print_i64(i64 %r59)
  %r60 = getelementptr inbounds [1 x i8], ptr @.str22, i64 0, i64 0
  call void @zfy_print_str(ptr %r60)
  %r61 = getelementptr inbounds [2 x i8], ptr @.str23, i64 0, i64 0
  call void @zfy_print_str(ptr %r61)
  %t10 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t10)
  call void @zfy_free_str(ptr %t10)
  %r62 = add i64 0, 0
  %r63 = load ptr, ptr %v.n
  %r64 = getelementptr inbounds %zfy.seq, ptr %r63, i32 0, i32 2
  %r65 = load i64, ptr %r64
  %r66 = icmp ult i64 %r62, %r65
  br i1 %r66, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r67 = load ptr, ptr %r63
  %r68 = mul i64 %r62, 4
  %r69 = getelementptr inbounds i8, ptr %r67, i64 %r68
  %r70 = load i32, ptr %r69, align 1
  %r71 = sext i32 %r70 to i128
  br label %L12
L12:
  %r72 = trunc i128 %r71 to i32
  %r73 = sext i32 %r72 to i64
  store i64 %r73, ptr %v.m
  %r74 = getelementptr inbounds [2 x i8], ptr @.str24, i64 0, i64 0
  call void @zfy_print_str(ptr %r74)
  %r75 = getelementptr inbounds [1 x i8], ptr @.str25, i64 0, i64 0
  call void @zfy_print_str(ptr %r75)
  %r76 = load i64, ptr %v.m
  call void @zfy_print_i64(i64 %r76)
  %r77 = getelementptr inbounds [1 x i8], ptr @.str26, i64 0, i64 0
  call void @zfy_print_str(ptr %r77)
  %r78 = getelementptr inbounds [2 x i8], ptr @.str27, i64 0, i64 0
  call void @zfy_print_str(ptr %r78)
  %t14 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t14)
  call void @zfy_free_str(ptr %t14)
  store i32 100, ptr %v.a
  %r80 = load i32, ptr %v.a
  %r79 = sext i32 %r80 to i64
  store i64 %r79, ptr %v.b
  %r82 = load i32, ptr %v.a
  %r81 = sitofp i32 %r82 to double
  store double %r81, ptr %v.d
  %r83 = load i64, ptr %v.b
  call void @zfy_print_i64(i64 %r83)
  %r84 = getelementptr inbounds [2 x i8], ptr @.str28, i64 0, i64 0
  call void @zfy_print_str(ptr %r84)
  %r85 = load double, ptr %v.d
  call void @zfy_print_f64(double %r85)
  %t17 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t17)
  call void @zfy_free_str(ptr %t17)
  %r87 = load double, ptr %v.d
  %r86 = fptrunc double %r87 to float
  store float %r86, ptr %v.f
  %r89 = load float, ptr %v.f
  %r88 = fpext float %r89 to double
  call void @zfy_print_f64(double %r88)
  %t20 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t20)
  call void @zfy_free_str(ptr %t20)
  store double 3.9900000000000002, ptr %v.dd
  %r91 = load double, ptr %v.dd
  %r90 = fptosi double %r91 to i32
  %r92 = sext i32 %r90 to i64
  call void @zfy_print_i64(i64 %r92)
  %t22 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t22)
  call void @zfy_free_str(ptr %t22)
  store double -3.9900000000000002, ptr %v.dn
  %r94 = load double, ptr %v.dn
  %r93 = fptosi double %r94 to i32
  %r95 = sext i32 %r93 to i64
  call void @zfy_print_i64(i64 %r95)
  %t25 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t25)
  call void @zfy_free_str(ptr %t25)
  store i64 300, ptr %v.big
  %r97 = load i64, ptr %v.big
  %r96 = trunc i64 %r97 to i32
  %r98 = sext i32 %r96 to i64
  call void @zfy_print_i64(i64 %r98)
  %t27 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t27)
  call void @zfy_free_str(ptr %t27)
  %t28 = call ptr @pick(i1 1)
  call void @zfy_print_str(ptr %t28)
  %t29 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t29)
  call void @zfy_free_str(ptr %t28)
  call void @zfy_free_str(ptr %t29)
  %t30 = call ptr @pick(i1 0)
  call void @zfy_print_str(ptr %t30)
  %t31 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t31)
  call void @zfy_free_str(ptr %t30)
  call void @zfy_free_str(ptr %t31)
  %r99 = load ptr, ptr %v.n
  call void @zfy_seq_free(ptr %r99, i8 0)
  store ptr null, ptr %v.n
  ret void
}
define ptr @pick(i1 %c) {
  %v.s = alloca ptr
  %v.c = alloca i1
  store i1 %c, ptr %v.c
  store ptr null, ptr %v.s
  %r1 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r1)
  %r2 = getelementptr inbounds [9 x i8], ptr @.str29, i64 0, i64 0
  %r3 = call ptr @zfy_strdup(ptr %r2)
  store ptr %r3, ptr %v.s
  %r4 = load i1, ptr %v.c
  br i1 %r4, label %b1, label %b2
b1:
  %r5 = load ptr, ptr %v.s
  ret ptr %r5
b2:
  br label %b3
b3:
  %r6 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r6)
  store ptr null, ptr %v.s
  %r7 = getelementptr inbounds [4 x i8], ptr @.str30, i64 0, i64 0
  %r8 = call ptr @zfy_strdup(ptr %r7)
  ret ptr %r8
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
