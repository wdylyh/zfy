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
@g.gcount = global i32 zeroinitializer
@g.gname = global ptr zeroinitializer
@g.gnums = global ptr zeroinitializer
@g.gd = global double zeroinitializer
@.str1 = private unnamed_addr constant [4 x i8] c"zfy\00"
@.str2 = private unnamed_addr constant [1 x i8] c"\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [5 x i8] c"sep=\00"
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [1 x i8] c"\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str10 = private unnamed_addr constant [1 x i8] c"\00"
@.str11 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str12 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str13 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str14 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str15 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str16 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str17 = private unnamed_addr constant [6 x i8] c"a,b,c\00"
@.str18 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str19 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str20 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  store i32 10, ptr @g.gcount
  %r1 = load ptr, ptr @g.gname
  call void @zfy_free_str(ptr %r1)
  %r2 = getelementptr inbounds [4 x i8], ptr @.str1, i64 0, i64 0
  %r3 = call ptr @zfy_strdup(ptr %r2)
  store ptr %r3, ptr @g.gname
  %r4 = call ptr @zfy_seq_new(i64 0, i64 8, i32 4)
  store ptr %r4, ptr @g.gnums
  store double 0.0, ptr @g.gd
  ret void
}
define void @fr_sum(ptr sret(%frac.i32) %out, ptr %a, ptr %b) {
  %r3 = alloca %frac.i32
  %v.a = alloca %frac.i32
  %r1 = load %frac.i32, ptr %a
  store %frac.i32 %r1, ptr %v.a
  %v.b = alloca %frac.i32
  %r2 = load %frac.i32, ptr %b
  store %frac.i32 %r2, ptr %v.b
  call void @zfy_frac_add_i32(ptr %r3, ptr %v.a, ptr %v.b)
  call void @llvm.memcpy.p0.p0.i64(ptr %out, ptr %r3, i64 8, i1 false)
  ret void
}
define i32 @arr_sum(ptr %a) {
  %v.i = alloca i32
  %v.s = alloca i32
  %v.a = alloca ptr
  %r1 = call ptr @zfy_seq_clone(ptr %a, i8 0)
  store ptr %r1, ptr %v.a
  store i32 zeroinitializer, ptr %v.i
  store i32 zeroinitializer, ptr %v.s
  store i32 0, ptr %v.s
  store i32 0, ptr %v.i
  br label %b1
b1:
  %r3 = load i32, ptr %v.i
  %r2 = icmp slt i32 %r3, 5
  br i1 %r2, label %b2, label %b4
b2:
  %r5 = load i32, ptr %v.i
  %r4 = sext i32 %r5 to i64
  %r6 = load ptr, ptr %v.a
  %r7 = getelementptr inbounds %zfy.seq, ptr %r6, i32 0, i32 2
  %r8 = load i64, ptr %r7
  %r9 = icmp ult i64 %r4, %r8
  br i1 %r9, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r10 = load ptr, ptr %r6
  %r11 = mul i64 %r4, 4
  %r12 = getelementptr inbounds i8, ptr %r10, i64 %r11
  %r13 = load i32, ptr %r12, align 1
  %r14 = sext i32 %r13 to i128
  br label %L3
L3:
  %r15 = trunc i128 %r14 to i32
  %r17 = load i32, ptr %v.s
  %r16 = add i32 %r17, %r15
  store i32 %r16, ptr %v.s
  br label %b3
b3:
  %r19 = load i32, ptr %v.i
  %r18 = add i32 %r19, 1
  store i32 %r18, ptr %v.i
  br label %b1
b4:
  %r20 = load ptr, ptr %v.a
  call void @zfy_seq_free(ptr %r20, i8 0)
  store ptr null, ptr %v.a
  %r21 = load i32, ptr %v.s
  ret i32 %r21
}
define i32 @arr_fill(i32 %n, ptr %b) {
  %v.i = alloca i32
  %r11 = alloca i128
  %v.n = alloca i32
  store i32 %n, ptr %v.n
  %v.b = alloca ptr
  %r1 = call ptr @zfy_seq_clone(ptr %b, i8 0)
  store ptr %r1, ptr %v.b
  store i32 zeroinitializer, ptr %v.i
  store i32 0, ptr %v.i
  br label %b1
b1:
  %r3 = load i32, ptr %v.i
  %r4 = load i32, ptr %v.n
  %r2 = icmp slt i32 %r3, %r4
  br i1 %r2, label %b2, label %b4
b2:
  %r6 = load i32, ptr %v.i
  %r5 = mul i32 %r6, 2
  %r8 = load i32, ptr %v.i
  %r7 = sext i32 %r8 to i64
  %r9 = load ptr, ptr %v.b
  %r10 = sext i32 %r5 to i128
  store i128 %r10, ptr %r11
  call void @zfy_seq_set_w(ptr %r9, i64 %r7, ptr %r11, i32 4, i8 1)
  br label %b3
b3:
  %r13 = load i32, ptr %v.i
  %r12 = add i32 %r13, 1
  store i32 %r12, ptr %v.i
  br label %b1
b4:
  %r14 = add i64 2, 0
  %r15 = load ptr, ptr %v.b
  %r16 = getelementptr inbounds %zfy.seq, ptr %r15, i32 0, i32 2
  %r17 = load i64, ptr %r16
  %r18 = icmp ult i64 %r14, %r17
  br i1 %r18, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r19 = load ptr, ptr %r15
  %r20 = mul i64 %r14, 4
  %r21 = getelementptr inbounds i8, ptr %r19, i64 %r20
  %r22 = load i32, ptr %r21, align 1
  %r23 = sext i32 %r22 to i128
  br label %L3
L3:
  %r24 = trunc i128 %r23 to i32
  %r25 = load ptr, ptr %v.b
  call void @zfy_seq_free(ptr %r25, i8 0)
  store ptr null, ptr %v.b
  ret i32 %r24
}
define i32 @list_len(ptr %xs) {
  %v.xs = alloca ptr
  %r1 = call ptr @zfy_seq_clone(ptr %xs, i8 0)
  store ptr %r1, ptr %v.xs
  %r2 = load ptr, ptr %v.xs
  %r3 = getelementptr inbounds %zfy.seq, ptr %r2, i32 0, i32 2
  %r4 = load i64, ptr %r3
  %r5 = trunc i64 %r4 to i32
  %r6 = load ptr, ptr %v.xs
  call void @zfy_seq_free(ptr %r6, i8 0)
  store ptr null, ptr %v.xs
  ret i32 %r5
}
define i32 @list_len_str(ptr %xs) {
  %v.xs = alloca ptr
  %r1 = call ptr @zfy_seq_clone(ptr %xs, i8 1)
  store ptr %r1, ptr %v.xs
  %r2 = load ptr, ptr %v.xs
  %r3 = getelementptr inbounds %zfy.seq, ptr %r2, i32 0, i32 2
  %r4 = load i64, ptr %r3
  %r5 = trunc i64 %r4 to i32
  %r6 = load ptr, ptr %v.xs
  call void @zfy_seq_free(ptr %r6, i8 1)
  store ptr null, ptr %v.xs
  ret i32 %r5
}
define i64 @zfy.main() {
  %v.parts = alloca ptr
  %v.line = alloca ptr
  %v.n = alloca i32
  %v.small = alloca i32
  %v.big = alloca i64
  %v.i = alloca i32
  %v.last = alloca i32
  %v.xs = alloca ptr
  %v.d = alloca ptr
  %v.m = alloca i32
  %v.a = alloca ptr
  %v.s = alloca %frac.i32
  %v.y = alloca %frac.i32
  %v.x = alloca %frac.i32
  %r13 = alloca i128
  %r19 = alloca i128
  %r48 = alloca %frac.i32
  %r53 = alloca %frac.i32
  %r56 = alloca %frac.i32
  %r130 = alloca i128
  %r133 = alloca i128
  %r136 = alloca i128
  %r175 = alloca i128
  store ptr null, ptr %v.parts
  store ptr null, ptr %v.line
  store i32 zeroinitializer, ptr %v.n
  store i32 zeroinitializer, ptr %v.small
  store i64 zeroinitializer, ptr %v.big
  store i32 zeroinitializer, ptr %v.i
  store i32 zeroinitializer, ptr %v.last
  store ptr null, ptr %v.xs
  store ptr null, ptr %v.d
  store i32 zeroinitializer, ptr %v.m
  store ptr null, ptr %v.a
  store %frac.i32 zeroinitializer, ptr %v.s
  store %frac.i32 zeroinitializer, ptr %v.y
  store %frac.i32 zeroinitializer, ptr %v.x
  %r1 = load i32, ptr @g.gcount
  %r2 = sext i32 %r1 to i64
  call void @zfy_print_i64(i64 %r2)
  %r3 = getelementptr inbounds [1 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r3)
  %r4 = load ptr, ptr @g.gname
  call void @zfy_print_str(ptr %r4)
  %r5 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r5)
  %r6 = getelementptr inbounds [5 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r6)
  %r7 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r7)
  %r8 = load ptr, ptr @g.gnums
  %r9 = getelementptr inbounds %zfy.seq, ptr %r8, i32 0, i32 2
  %r10 = load i64, ptr %r9
  %r11 = load ptr, ptr @g.gnums
  %r12 = sext i32 3 to i128
  store i128 %r12, ptr %r13
  call void @zfy_seq_set_w(ptr %r11, i64 %r10, ptr %r13, i32 4, i8 1)
  %r14 = load ptr, ptr @g.gnums
  %r15 = getelementptr inbounds %zfy.seq, ptr %r14, i32 0, i32 2
  %r16 = load i64, ptr %r15
  %r17 = load ptr, ptr @g.gnums
  %r18 = sext i32 4 to i128
  store i128 %r18, ptr %r19
  call void @zfy_seq_set_w(ptr %r17, i64 %r16, ptr %r19, i32 4, i8 1)
  %r20 = add i64 0, 0
  %r21 = load ptr, ptr @g.gnums
  %r22 = getelementptr inbounds %zfy.seq, ptr %r21, i32 0, i32 2
  %r23 = load i64, ptr %r22
  %r24 = icmp ult i64 %r20, %r23
  br i1 %r24, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r25 = load ptr, ptr %r21
  %r26 = mul i64 %r20, 4
  %r27 = getelementptr inbounds i8, ptr %r25, i64 %r26
  %r28 = load i32, ptr %r27, align 1
  %r29 = sext i32 %r28 to i128
  br label %L3
L3:
  %r30 = trunc i128 %r29 to i32
  %r31 = sext i32 %r30 to i64
  call void @zfy_print_i64(i64 %r31)
  %r32 = getelementptr inbounds [1 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r32)
  %r33 = add i64 1, 0
  %r34 = load ptr, ptr @g.gnums
  %r35 = getelementptr inbounds %zfy.seq, ptr %r34, i32 0, i32 2
  %r36 = load i64, ptr %r35
  %r37 = icmp ult i64 %r33, %r36
  br i1 %r37, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r38 = load ptr, ptr %r34
  %r39 = mul i64 %r33, 4
  %r40 = getelementptr inbounds i8, ptr %r38, i64 %r39
  %r41 = load i32, ptr %r40, align 1
  %r42 = sext i32 %r41 to i128
  br label %L6
L6:
  %r43 = trunc i128 %r42 to i32
  %r44 = sext i32 %r43 to i64
  call void @zfy_print_i64(i64 %r44)
  %r45 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r45)
  %r46 = trunc i64 1 to i32
  %r47 = trunc i64 2 to i32
  %r49 = getelementptr inbounds %frac.i32, ptr %r48, i32 0, i32 0
  store i32 %r46, ptr %r49
  %r50 = getelementptr inbounds %frac.i32, ptr %r48, i32 0, i32 1
  store i32 %r47, ptr %r50
  call void @llvm.memcpy.p0.p0.i64(ptr %v.x, ptr %r48, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.x)
  %r51 = trunc i64 1 to i32
  %r52 = trunc i64 3 to i32
  %r54 = getelementptr inbounds %frac.i32, ptr %r53, i32 0, i32 0
  store i32 %r51, ptr %r54
  %r55 = getelementptr inbounds %frac.i32, ptr %r53, i32 0, i32 1
  store i32 %r52, ptr %r55
  call void @llvm.memcpy.p0.p0.i64(ptr %v.y, ptr %r53, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.y)
  call void @fr_sum(ptr %r56, ptr %v.x, ptr %v.y)
  call void @llvm.memcpy.p0.p0.i64(ptr %v.s, ptr %r56, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.s)
  call void @zfy_frac_print_i32(ptr %v.s)
  %r57 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r57)
  %r58 = call ptr @zfy_seq_new(i64 5, i64 5, i32 4)
  store ptr %r58, ptr %v.a
  %r59 = load ptr, ptr %v.a
  %r60 = getelementptr inbounds %zfy.seq, ptr %r59, i32 0, i32 2
  %r61 = load i64, ptr %r60
  %r62 = icmp ult i64 0, %r61
  br i1 %r62, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r63 = load ptr, ptr %r59
  %r64 = mul i64 0, 4
  %r65 = getelementptr inbounds i8, ptr %r63, i64 %r64
  %r66 = sext i32 1 to i128
  %r67 = trunc i128 %r66 to i32
  store i32 %r67, ptr %r65, align 1
  br label %L9
L9:
  %r68 = load ptr, ptr %v.a
  %r69 = getelementptr inbounds %zfy.seq, ptr %r68, i32 0, i32 2
  %r70 = load i64, ptr %r69
  %r71 = icmp ult i64 1, %r70
  br i1 %r71, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r72 = load ptr, ptr %r68
  %r73 = mul i64 1, 4
  %r74 = getelementptr inbounds i8, ptr %r72, i64 %r73
  %r75 = sext i32 2 to i128
  %r76 = trunc i128 %r75 to i32
  store i32 %r76, ptr %r74, align 1
  br label %L12
L12:
  %r77 = load ptr, ptr %v.a
  %r78 = getelementptr inbounds %zfy.seq, ptr %r77, i32 0, i32 2
  %r79 = load i64, ptr %r78
  %r80 = icmp ult i64 2, %r79
  br i1 %r80, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r81 = load ptr, ptr %r77
  %r82 = mul i64 2, 4
  %r83 = getelementptr inbounds i8, ptr %r81, i64 %r82
  %r84 = sext i32 3 to i128
  %r85 = trunc i128 %r84 to i32
  store i32 %r85, ptr %r83, align 1
  br label %L15
L15:
  %r86 = load ptr, ptr %v.a
  %r87 = getelementptr inbounds %zfy.seq, ptr %r86, i32 0, i32 2
  %r88 = load i64, ptr %r87
  %r89 = icmp ult i64 3, %r88
  br i1 %r89, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r90 = load ptr, ptr %r86
  %r91 = mul i64 3, 4
  %r92 = getelementptr inbounds i8, ptr %r90, i64 %r91
  %r93 = sext i32 4 to i128
  %r94 = trunc i128 %r93 to i32
  store i32 %r94, ptr %r92, align 1
  br label %L18
L18:
  %r95 = load ptr, ptr %v.a
  %r96 = getelementptr inbounds %zfy.seq, ptr %r95, i32 0, i32 2
  %r97 = load i64, ptr %r96
  %r98 = icmp ult i64 4, %r97
  br i1 %r98, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r99 = load ptr, ptr %r95
  %r100 = mul i64 4, 4
  %r101 = getelementptr inbounds i8, ptr %r99, i64 %r100
  %r102 = sext i32 5 to i128
  %r103 = trunc i128 %r102 to i32
  store i32 %r103, ptr %r101, align 1
  br label %L21
L21:
  %r104 = load ptr, ptr %v.a
  %t14 = call i32 @arr_sum(ptr %r104)
  %r105 = sext i32 %t14 to i64
  call void @zfy_print_i64(i64 %r105)
  %r106 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r106)
  store i32 4, ptr %v.m
  %r107 = call ptr @zfy_seq_new(i64 4, i64 4, i32 4)
  store ptr %r107, ptr %v.d
  %r108 = load i32, ptr %v.m
  %r109 = load ptr, ptr %v.d
  %t15 = call i32 @arr_fill(i32 %r108, ptr %r109)
  %r110 = load i32, ptr %v.m
  %r111 = load ptr, ptr %v.d
  %t16 = call i32 @arr_fill(i32 %r110, ptr %r111)
  %r112 = sext i32 %t16 to i64
  call void @zfy_print_i64(i64 %r112)
  %r113 = getelementptr inbounds [1 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r113)
  %r114 = add i64 2, 0
  %r115 = load ptr, ptr %v.d
  %r116 = getelementptr inbounds %zfy.seq, ptr %r115, i32 0, i32 2
  %r117 = load i64, ptr %r116
  %r118 = icmp ult i64 %r114, %r117
  br i1 %r118, label %L22, label %L23
L23:
  call void @zfy_bounds_fail()
  unreachable
L22:
  %r119 = load ptr, ptr %r115
  %r120 = mul i64 %r114, 4
  %r121 = getelementptr inbounds i8, ptr %r119, i64 %r120
  %r122 = load i32, ptr %r121, align 1
  %r123 = sext i32 %r122 to i128
  br label %L24
L24:
  %r124 = trunc i128 %r123 to i32
  %r125 = sext i32 %r124 to i64
  call void @zfy_print_i64(i64 %r125)
  %r126 = getelementptr inbounds [2 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r126)
  %r127 = call ptr @zfy_seq_new(i64 0, i64 8, i32 4)
  store ptr %r127, ptr %v.xs
  %r128 = load ptr, ptr %v.xs
  %r129 = sext i32 7 to i128
  store i128 %r129, ptr %r130
  call void @zfy_seq_set_w(ptr %r128, i64 0, ptr %r130, i32 4, i8 1)
  %r131 = load ptr, ptr %v.xs
  %r132 = sext i32 8 to i128
  store i128 %r132, ptr %r133
  call void @zfy_seq_set_w(ptr %r131, i64 1, ptr %r133, i32 4, i8 1)
  %r134 = load ptr, ptr %v.xs
  %r135 = sext i32 9 to i128
  store i128 %r135, ptr %r136
  call void @zfy_seq_set_w(ptr %r134, i64 2, ptr %r136, i32 4, i8 1)
  %r137 = load ptr, ptr %v.xs
  %t19 = call i32 @list_len(ptr %r137)
  %r138 = sext i32 %t19 to i64
  call void @zfy_print_i64(i64 %r138)
  %r139 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r139)
  store i32 0, ptr %v.last
  store i32 0, ptr %v.i
  br label %b1
b1:
  %r141 = load i32, ptr %v.i
  %r140 = icmp slt i32 %r141, 3
  br i1 %r140, label %b2, label %b4
b2:
  %r143 = load i32, ptr %v.i
  %r144 = load i32, ptr %v.i
  %r142 = mul i32 %r143, %r144
  store i32 %r142, ptr %v.last
  br label %b3
b3:
  %r146 = load i32, ptr %v.i
  %r145 = add i32 %r146, 1
  store i32 %r145, ptr %v.i
  br label %b1
b4:
  %r147 = load i32, ptr %v.i
  %r148 = sext i32 %r147 to i64
  call void @zfy_print_i64(i64 %r148)
  %r149 = getelementptr inbounds [2 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r149)
  %r150 = load i32, ptr %v.last
  %r151 = sext i32 %r150 to i64
  call void @zfy_print_i64(i64 %r151)
  %r152 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r152)
  store i64 100, ptr %v.big
  %r154 = load i64, ptr %v.big
  %r153 = trunc i64 %r154 to i32
  store i32 %r153, ptr %v.small
  %r155 = load i32, ptr %v.small
  %r156 = sext i32 %r155 to i64
  call void @zfy_print_i64(i64 %r156)
  %r157 = getelementptr inbounds [2 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r157)
  %r158 = load ptr, ptr %v.xs
  %r159 = getelementptr inbounds %zfy.seq, ptr %r158, i32 0, i32 2
  %r160 = load i64, ptr %r159
  %r161 = trunc i64 %r160 to i32
  store i32 %r161, ptr %v.n
  %r162 = load i32, ptr %v.n
  %r163 = sext i32 %r162 to i64
  call void @zfy_print_i64(i64 %r163)
  %r164 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r164)
  %r165 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r165)
  %r166 = getelementptr inbounds [6 x i8], ptr @.str17, i64 0, i64 0
  %r167 = call ptr @zfy_strdup(ptr %r166)
  store ptr %r167, ptr %v.line
  %r168 = load ptr, ptr %v.line
  %t26 = call ptr @zfy_str_split(ptr %r168, i8 44)
  %r169 = load ptr, ptr %v.parts
  call void @zfy_seq_free(ptr %r169, i8 1)
  store ptr %t26, ptr %v.parts
  %r170 = load ptr, ptr %v.parts
  %r171 = getelementptr inbounds %zfy.seq, ptr %r170, i32 0, i32 2
  %r172 = load i64, ptr %r171
  call void @zfy_print_i64(i64 %r172)
  %r173 = getelementptr inbounds [2 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_print_str(ptr %r173)
  %r174 = add i64 1, 0
  %r176 = load ptr, ptr %v.parts
  call void @zfy_seq_get(ptr %r176, i64 %r174, ptr %r175, i32 8, i8 0)
  %r177 = load i128, ptr %r175
  %r178 = trunc i128 %r177 to i64
  %r179 = inttoptr i64 %r178 to ptr
  call void @zfy_print_str(ptr %r179)
  %r180 = getelementptr inbounds [2 x i8], ptr @.str19, i64 0, i64 0
  call void @zfy_print_str(ptr %r180)
  %r181 = load ptr, ptr %v.parts
  %t30 = call i32 @list_len_str(ptr %r181)
  %r182 = sext i32 %t30 to i64
  call void @zfy_print_i64(i64 %r182)
  %r183 = getelementptr inbounds [2 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r183)
  %r184 = load ptr, ptr %v.parts
  call void @zfy_seq_free(ptr %r184, i8 1)
  store ptr null, ptr %v.parts
  %r185 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r185)
  store ptr null, ptr %v.line
  %r186 = load ptr, ptr %v.xs
  call void @zfy_seq_free(ptr %r186, i8 0)
  store ptr null, ptr %v.xs
  %r187 = load ptr, ptr %v.d
  call void @zfy_seq_free(ptr %r187, i8 0)
  store ptr null, ptr %v.d
  %r188 = load ptr, ptr %v.a
  call void @zfy_seq_free(ptr %r188, i8 0)
  store ptr null, ptr %v.a
  ret i64 0
}
define i32 @main() {
  call void @zfy.globals()
  %r = call i64 @zfy.main()
  %t = trunc i64 %r to i32
  ret i32 %t
}
