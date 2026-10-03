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
declare i32 @zfy_try_setup(ptr) returns_twice
declare void @zfy_try_leave()
declare ptr @zfy_try_msg()
declare void @zfy_throw(ptr)
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
@.str1 = private unnamed_addr constant [2 x i8] c",\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [7 x i8] c"inside\00"
@.str4 = private unnamed_addr constant [7 x i8] c"boom: \00"
@.str5 = private unnamed_addr constant [12 x i8] c"not reached\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [6 x i8] c"plain\00"
@.str9 = private unnamed_addr constant [13 x i8] c"caught plain\00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str12 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str13 = private unnamed_addr constant [14 x i8] c"not reached 2\00"
@.str14 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str15 = private unnamed_addr constant [14 x i8] c"bounds caught\00"
@.str16 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str17 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str18 = private unnamed_addr constant [6 x i8] c"hello\00"
@.str19 = private unnamed_addr constant [2 x i8] c"|\00"
@.str20 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str21 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str22 = private unnamed_addr constant [9 x i8] c"temp str\00"
@.str23 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str24 = private unnamed_addr constant [5 x i8] c"deep\00"
@.str25 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str26 = private unnamed_addr constant [6 x i8] c"outer\00"
define void @zfy.globals() {
  ret void
}
define ptr @pick(ptr %s) {
  %v.s = alloca ptr
  store ptr %s, ptr %v.s
  %r1 = load ptr, ptr %v.s
  ret ptr %r1
}
define void @show(ptr %a) {
  %v.a = alloca ptr
  store ptr %a, ptr %v.a
  %r1 = add i64 0, 0
  %r2 = load ptr, ptr %v.a
  %r3 = getelementptr inbounds %zfy.seq, ptr %r2, i32 0, i32 2
  %r4 = load i64, ptr %r3
  %r5 = icmp ult i64 %r1, %r4
  br i1 %r5, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r6 = load ptr, ptr %r2
  %r7 = mul i64 %r1, 4
  %r8 = getelementptr inbounds i8, ptr %r6, i64 %r7
  %r9 = load i32, ptr %r8, align 1
  %r10 = sext i32 %r9 to i128
  br label %L3
L3:
  %r11 = trunc i128 %r10 to i32
  %r12 = sext i32 %r11 to i64
  call void @zfy_print_i64(i64 %r12)
  %r13 = getelementptr inbounds [2 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r13)
  %r14 = add i64 1, 0
  %r15 = load ptr, ptr %v.a
  %r16 = getelementptr inbounds %zfy.seq, ptr %r15, i32 0, i32 2
  %r17 = load i64, ptr %r16
  %r18 = icmp ult i64 %r14, %r17
  br i1 %r18, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r19 = load ptr, ptr %r15
  %r20 = mul i64 %r14, 4
  %r21 = getelementptr inbounds i8, ptr %r19, i64 %r20
  %r22 = load i32, ptr %r21, align 1
  %r23 = sext i32 %r22 to i128
  br label %L6
L6:
  %r24 = trunc i128 %r23 to i32
  %r25 = sext i32 %r24 to i64
  call void @zfy_print_i64(i64 %r25)
  %r26 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r26)
  %r27 = load ptr, ptr %v.a
  call void @zfy_seq_free(ptr %r27, i8 0)
  store ptr null, ptr %v.a
  ret void
}
define void @zfy.main() {
  %v.arr = alloca ptr
  %v.t = alloca ptr
  %v.r = alloca ptr
  %v.s = alloca ptr
  %v.e4 = alloca ptr
  %v.e5 = alloca ptr
  %v.a = alloca ptr
  %v.e3 = alloca ptr
  %v.e2 = alloca ptr
  %v.ok = alloca i32
  %v.inner = alloca ptr
  %v.e = alloca ptr
  %t1 = alloca [512 x i8], align 16
  %t4 = alloca [512 x i8], align 16
  %t6 = alloca [512 x i8], align 16
  %t8 = alloca [512 x i8], align 16
  %t13 = alloca [512 x i8], align 16
  %t15 = alloca [512 x i8], align 16
  store ptr null, ptr %v.arr
  store ptr null, ptr %v.t
  store ptr null, ptr %v.r
  store ptr null, ptr %v.s
  store ptr null, ptr %v.e4
  store ptr null, ptr %v.e5
  store ptr null, ptr %v.a
  store ptr null, ptr %v.e3
  store ptr null, ptr %v.e2
  store i32 zeroinitializer, ptr %v.ok
  store ptr null, ptr %v.inner
  store ptr null, ptr %v.e
  %r1 = call i32 @zfy_try_setup(ptr %t1) returns_twice
  %r2 = icmp ne i32 %r1, 0
  br i1 %r2, label %b2, label %b1
b1:
  %r3 = load ptr, ptr %v.inner
  call void @zfy_free_str(ptr %r3)
  %r4 = getelementptr inbounds [7 x i8], ptr @.str3, i64 0, i64 0
  %r5 = call ptr @zfy_strdup(ptr %r4)
  store ptr %r5, ptr %v.inner
  %r6 = getelementptr inbounds [7 x i8], ptr @.str4, i64 0, i64 0
  %r7 = call ptr @zfy_strdup(ptr %r6)
  %r8 = load ptr, ptr %v.inner
  %t3 = call ptr @zfy_str_concat(ptr %r7, ptr %r8)
  store ptr null, ptr %v.inner
  call void @zfy_throw(ptr %t3)
  call void @zfy_free_str(ptr %t3)
  %r9 = getelementptr inbounds [12 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r9)
  %r10 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r10)
  %r11 = load ptr, ptr %v.inner
  call void @zfy_free_str(ptr %r11)
  store ptr null, ptr %v.inner
  call void @zfy_try_leave()
  br label %b3
b2:
  %r12 = load ptr, ptr %v.inner
  call void @zfy_free_str(ptr %r12)
  store ptr null, ptr %v.inner
  %r13 = call ptr @zfy_try_msg()
  store ptr %r13, ptr %v.e
  %r14 = load ptr, ptr %v.e
  call void @zfy_print_str(ptr %r14)
  %r15 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r15)
  %r16 = load ptr, ptr %v.e
  call void @zfy_free_str(ptr %r16)
  store ptr null, ptr %v.e
  br label %b3
b3:
  %r17 = call i32 @zfy_try_setup(ptr %t4) returns_twice
  %r18 = icmp ne i32 %r17, 0
  br i1 %r18, label %b5, label %b4
b4:
  %r19 = getelementptr inbounds [6 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_throw(ptr %r19)
  call void @zfy_try_leave()
  br label %b6
b5:
  %r20 = getelementptr inbounds [13 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r20)
  %r21 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r21)
  br label %b6
b6:
  store i32 0, ptr %v.ok
  %r22 = call i32 @zfy_try_setup(ptr %t6) returns_twice
  %r23 = icmp ne i32 %r22, 0
  br i1 %r23, label %b8, label %b7
b7:
  store i32 1, ptr %v.ok
  call void @zfy_try_leave()
  br label %b9
b8:
  %r24 = call ptr @zfy_try_msg()
  store ptr %r24, ptr %v.e2
  store i32 2, ptr %v.ok
  %r25 = load ptr, ptr %v.e2
  call void @zfy_free_str(ptr %r25)
  store ptr null, ptr %v.e2
  br label %b9
b9:
  %r26 = load i32, ptr %v.ok
  %r27 = sext i32 %r26 to i64
  call void @zfy_print_i64(i64 %r27)
  %r28 = getelementptr inbounds [2 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r28)
  %r29 = call i32 @zfy_try_setup(ptr %t8) returns_twice
  %r30 = icmp ne i32 %r29, 0
  br i1 %r30, label %b11, label %b10
b10:
  %r31 = call ptr @zfy_seq_new(i64 3, i64 3, i32 4)
  store ptr %r31, ptr %v.a
  %r32 = add i64 0, 0
  %r33 = load ptr, ptr %v.a
  %r34 = getelementptr inbounds %zfy.seq, ptr %r33, i32 0, i32 2
  %r35 = load i64, ptr %r34
  %r36 = icmp ult i64 %r32, %r35
  br i1 %r36, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r37 = load ptr, ptr %r33
  %r38 = mul i64 %r32, 4
  %r39 = getelementptr inbounds i8, ptr %r37, i64 %r38
  %r40 = sext i32 7 to i128
  %r41 = trunc i128 %r40 to i32
  store i32 %r41, ptr %r39, align 1
  br label %L3
L3:
  %r42 = add i64 9, 0
  %r43 = load ptr, ptr %v.a
  %r44 = getelementptr inbounds %zfy.seq, ptr %r43, i32 0, i32 2
  %r45 = load i64, ptr %r44
  %r46 = icmp ult i64 %r42, %r45
  br i1 %r46, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r47 = load ptr, ptr %r43
  %r48 = mul i64 %r42, 4
  %r49 = getelementptr inbounds i8, ptr %r47, i64 %r48
  %r50 = load i32, ptr %r49, align 1
  %r51 = sext i32 %r50 to i128
  br label %L6
L6:
  %r52 = trunc i128 %r51 to i32
  %r53 = sext i32 %r52 to i64
  call void @zfy_print_i64(i64 %r53)
  %r54 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r54)
  %r55 = getelementptr inbounds [14 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r55)
  %r56 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r56)
  %r57 = load ptr, ptr %v.a
  call void @zfy_seq_free(ptr %r57, i8 0)
  store ptr null, ptr %v.a
  call void @zfy_try_leave()
  br label %b12
b11:
  %r58 = load ptr, ptr %v.a
  call void @zfy_seq_free(ptr %r58, i8 0)
  store ptr null, ptr %v.a
  %r59 = call ptr @zfy_try_msg()
  store ptr %r59, ptr %v.e3
  %r60 = getelementptr inbounds [14 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r60)
  %r61 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r61)
  %r62 = load ptr, ptr %v.e3
  call void @zfy_free_str(ptr %r62)
  store ptr null, ptr %v.e3
  br label %b12
b12:
  %r63 = call i32 @zfy_try_setup(ptr %t13) returns_twice
  %r64 = icmp ne i32 %r63, 0
  br i1 %r64, label %b14, label %b13
b13:
  %r65 = call i32 @zfy_try_setup(ptr %t15) returns_twice
  %r66 = icmp ne i32 %r65, 0
  br i1 %r66, label %b17, label %b16
b14:
  %r67 = call ptr @zfy_try_msg()
  store ptr %r67, ptr %v.e5
  %r68 = load ptr, ptr %v.e5
  call void @zfy_print_str(ptr %r68)
  %r69 = getelementptr inbounds [2 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r69)
  %r70 = load ptr, ptr %v.e5
  call void @zfy_free_str(ptr %r70)
  store ptr null, ptr %v.e5
  br label %b15
b15:
  %r71 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r71)
  %r72 = getelementptr inbounds [6 x i8], ptr @.str18, i64 0, i64 0
  %r73 = call ptr @zfy_strdup(ptr %r72)
  store ptr %r73, ptr %v.s
  %r74 = load ptr, ptr %v.s
  %r75 = call ptr @zfy_strdup(ptr %r74)
  %t17 = call ptr @pick(ptr %r75)
  %r76 = load ptr, ptr %v.r
  call void @zfy_free_str(ptr %r76)
  store ptr %t17, ptr %v.r
  %r77 = load ptr, ptr %v.r
  call void @zfy_print_str(ptr %r77)
  %r78 = getelementptr inbounds [2 x i8], ptr @.str19, i64 0, i64 0
  call void @zfy_print_str(ptr %r78)
  %r79 = load ptr, ptr %v.s
  call void @zfy_print_str(ptr %r79)
  %r80 = getelementptr inbounds [2 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r80)
  %r81 = load ptr, ptr %v.r
  %r82 = call ptr @zfy_strdup(ptr %r81)
  %t18 = call ptr @pick(ptr %r82)
  %r83 = load ptr, ptr %v.r
  call void @zfy_free_str(ptr %r83)
  store ptr %t18, ptr %v.r
  %r84 = load ptr, ptr %v.r
  call void @zfy_print_str(ptr %r84)
  %r85 = getelementptr inbounds [2 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r85)
  %r86 = getelementptr inbounds [9 x i8], ptr @.str22, i64 0, i64 0
  %r87 = call ptr @zfy_strdup(ptr %r86)
  %t19 = call ptr @pick(ptr %r87)
  %r88 = load ptr, ptr %v.t
  call void @zfy_free_str(ptr %r88)
  store ptr %t19, ptr %v.t
  %r89 = load ptr, ptr %v.t
  call void @zfy_print_str(ptr %r89)
  %r90 = getelementptr inbounds [2 x i8], ptr @.str23, i64 0, i64 0
  call void @zfy_print_str(ptr %r90)
  %r91 = call ptr @zfy_seq_new(i64 2, i64 2, i32 4)
  store ptr %r91, ptr %v.arr
  %r92 = load ptr, ptr %v.arr
  %r93 = getelementptr inbounds %zfy.seq, ptr %r92, i32 0, i32 2
  %r94 = load i64, ptr %r93
  %r95 = icmp ult i64 0, %r94
  br i1 %r95, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r96 = load ptr, ptr %r92
  %r97 = mul i64 0, 4
  %r98 = getelementptr inbounds i8, ptr %r96, i64 %r97
  %r99 = sext i32 1 to i128
  %r100 = trunc i128 %r99 to i32
  store i32 %r100, ptr %r98, align 1
  br label %L9
L9:
  %r101 = load ptr, ptr %v.arr
  %r102 = getelementptr inbounds %zfy.seq, ptr %r101, i32 0, i32 2
  %r103 = load i64, ptr %r102
  %r104 = icmp ult i64 1, %r103
  br i1 %r104, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r105 = load ptr, ptr %r101
  %r106 = mul i64 1, 4
  %r107 = getelementptr inbounds i8, ptr %r105, i64 %r106
  %r108 = sext i32 2 to i128
  %r109 = trunc i128 %r108 to i32
  store i32 %r109, ptr %r107, align 1
  br label %L12
L12:
  %r110 = load ptr, ptr %v.arr
  %r111 = call ptr @zfy_seq_clone(ptr %r110, i8 0)
  call void @show(ptr %r111)
  %r112 = add i64 0, 0
  %r113 = load ptr, ptr %v.arr
  %r114 = getelementptr inbounds %zfy.seq, ptr %r113, i32 0, i32 2
  %r115 = load i64, ptr %r114
  %r116 = icmp ult i64 %r112, %r115
  br i1 %r116, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r117 = load ptr, ptr %r113
  %r118 = mul i64 %r112, 4
  %r119 = getelementptr inbounds i8, ptr %r117, i64 %r118
  %r120 = sext i32 9 to i128
  %r121 = trunc i128 %r120 to i32
  store i32 %r121, ptr %r119, align 1
  br label %L15
L15:
  %r122 = load ptr, ptr %v.arr
  %r123 = call ptr @zfy_seq_clone(ptr %r122, i8 0)
  call void @show(ptr %r123)
  %r124 = load ptr, ptr %v.arr
  call void @zfy_seq_free(ptr %r124, i8 0)
  store ptr null, ptr %v.arr
  %r125 = load ptr, ptr %v.t
  call void @zfy_free_str(ptr %r125)
  store ptr null, ptr %v.t
  %r126 = load ptr, ptr %v.r
  call void @zfy_free_str(ptr %r126)
  store ptr null, ptr %v.r
  %r127 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r127)
  store ptr null, ptr %v.s
  ret void
b16:
  %r128 = getelementptr inbounds [5 x i8], ptr @.str24, i64 0, i64 0
  call void @zfy_throw(ptr %r128)
  call void @zfy_try_leave()
  br label %b18
b17:
  %r129 = call ptr @zfy_try_msg()
  store ptr %r129, ptr %v.e4
  %r130 = load ptr, ptr %v.e4
  call void @zfy_print_str(ptr %r130)
  %r131 = getelementptr inbounds [2 x i8], ptr @.str25, i64 0, i64 0
  call void @zfy_print_str(ptr %r131)
  %r132 = load ptr, ptr %v.e4
  call void @zfy_free_str(ptr %r132)
  store ptr null, ptr %v.e4
  br label %b18
b18:
  %r133 = getelementptr inbounds [6 x i8], ptr @.str26, i64 0, i64 0
  call void @zfy_throw(ptr %r133)
  call void @zfy_try_leave()
  br label %b15
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
