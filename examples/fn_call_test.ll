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
@.str2 = private unnamed_addr constant [2 x i8] c",\00"
@.str3 = private unnamed_addr constant [2 x i8] c",\00"
@.str4 = private unnamed_addr constant [2 x i8] c",\00"
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [2 x i8] c",\00"
@.str8 = private unnamed_addr constant [2 x i8] c",\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [3 x i8] c": \00"
@.str12 = private unnamed_addr constant [2 x i8] c",\00"
@.str13 = private unnamed_addr constant [2 x i8] c",\00"
@.str14 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str15 = private unnamed_addr constant [2 x i8] c",\00"
@.str16 = private unnamed_addr constant [2 x i8] c",\00"
@.str17 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str18 = private unnamed_addr constant [3 x i8] c"aa\00"
@.str19 = private unnamed_addr constant [3 x i8] c"bb\00"
@.str20 = private unnamed_addr constant [3 x i8] c"cc\00"
@.str21 = private unnamed_addr constant [3 x i8] c"dd\00"
@.str22 = private unnamed_addr constant [3 x i8] c"XX\00"
@.str23 = private unnamed_addr constant [2 x i8] c",\00"
@.str24 = private unnamed_addr constant [2 x i8] c",\00"
@.str25 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str26 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str27 = private unnamed_addr constant [7 x i8] c"banana\00"
@.str28 = private unnamed_addr constant [2 x i8] c",\00"
@.str29 = private unnamed_addr constant [2 x i8] c",\00"
@.str30 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str31 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str32 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str33 = private unnamed_addr constant [3 x i8] c": \00"
@.str34 = private unnamed_addr constant [2 x i8] c"|\00"
@.str35 = private unnamed_addr constant [2 x i8] c"|\00"
@.str36 = private unnamed_addr constant [2 x i8] c"|\00"
@.str37 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str38 = private unnamed_addr constant [3 x i8] c"ma\00"
@.str39 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.parts = alloca ptr
  %v.s = alloca ptr
  %v.picked = alloca ptr
  %v.names = alloca ptr
  %v.stepped2 = alloca ptr
  %v.hf = alloca ptr
  %v.big = alloca ptr
  %v.stepped = alloca ptr
  %v.sub = alloca ptr
  %v.n = alloca ptr
  %r198 = alloca i128
  %r202 = alloca i128
  %r206 = alloca i128
  %r210 = alloca i128
  %r214 = alloca i128
  %r329 = alloca i128
  %r336 = alloca i128
  %r343 = alloca i128
  %r350 = alloca i128
  %r379 = alloca i128
  %r386 = alloca i128
  %r393 = alloca i128
  %r400 = alloca i128
  store ptr null, ptr %v.parts
  store ptr null, ptr %v.s
  store ptr null, ptr %v.picked
  store ptr null, ptr %v.names
  store ptr null, ptr %v.stepped2
  store ptr null, ptr %v.hf
  store ptr null, ptr %v.big
  store ptr null, ptr %v.stepped
  store ptr null, ptr %v.sub
  store ptr null, ptr %v.n
  %r1 = call ptr @zfy_seq_new(i64 8, i64 8, i32 4)
  store ptr %r1, ptr %v.n
  %r2 = load ptr, ptr %v.n
  %r3 = getelementptr inbounds %zfy.seq, ptr %r2, i32 0, i32 2
  %r4 = load i64, ptr %r3
  %r5 = icmp ult i64 0, %r4
  br i1 %r5, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r6 = load ptr, ptr %r2
  %r7 = mul i64 0, 4
  %r8 = getelementptr inbounds i8, ptr %r6, i64 %r7
  %r9 = sext i32 1 to i128
  %r10 = trunc i128 %r9 to i32
  store i32 %r10, ptr %r8, align 1
  br label %L3
L3:
  %r11 = load ptr, ptr %v.n
  %r12 = getelementptr inbounds %zfy.seq, ptr %r11, i32 0, i32 2
  %r13 = load i64, ptr %r12
  %r14 = icmp ult i64 1, %r13
  br i1 %r14, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r15 = load ptr, ptr %r11
  %r16 = mul i64 1, 4
  %r17 = getelementptr inbounds i8, ptr %r15, i64 %r16
  %r18 = sext i32 2 to i128
  %r19 = trunc i128 %r18 to i32
  store i32 %r19, ptr %r17, align 1
  br label %L6
L6:
  %r20 = load ptr, ptr %v.n
  %r21 = getelementptr inbounds %zfy.seq, ptr %r20, i32 0, i32 2
  %r22 = load i64, ptr %r21
  %r23 = icmp ult i64 2, %r22
  br i1 %r23, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r24 = load ptr, ptr %r20
  %r25 = mul i64 2, 4
  %r26 = getelementptr inbounds i8, ptr %r24, i64 %r25
  %r27 = sext i32 3 to i128
  %r28 = trunc i128 %r27 to i32
  store i32 %r28, ptr %r26, align 1
  br label %L9
L9:
  %r29 = load ptr, ptr %v.n
  %r30 = getelementptr inbounds %zfy.seq, ptr %r29, i32 0, i32 2
  %r31 = load i64, ptr %r30
  %r32 = icmp ult i64 3, %r31
  br i1 %r32, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r33 = load ptr, ptr %r29
  %r34 = mul i64 3, 4
  %r35 = getelementptr inbounds i8, ptr %r33, i64 %r34
  %r36 = sext i32 4 to i128
  %r37 = trunc i128 %r36 to i32
  store i32 %r37, ptr %r35, align 1
  br label %L12
L12:
  %r38 = load ptr, ptr %v.n
  %r39 = getelementptr inbounds %zfy.seq, ptr %r38, i32 0, i32 2
  %r40 = load i64, ptr %r39
  %r41 = icmp ult i64 4, %r40
  br i1 %r41, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r42 = load ptr, ptr %r38
  %r43 = mul i64 4, 4
  %r44 = getelementptr inbounds i8, ptr %r42, i64 %r43
  %r45 = sext i32 5 to i128
  %r46 = trunc i128 %r45 to i32
  store i32 %r46, ptr %r44, align 1
  br label %L15
L15:
  %r47 = load ptr, ptr %v.n
  %r48 = getelementptr inbounds %zfy.seq, ptr %r47, i32 0, i32 2
  %r49 = load i64, ptr %r48
  %r50 = icmp ult i64 5, %r49
  br i1 %r50, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r51 = load ptr, ptr %r47
  %r52 = mul i64 5, 4
  %r53 = getelementptr inbounds i8, ptr %r51, i64 %r52
  %r54 = sext i32 6 to i128
  %r55 = trunc i128 %r54 to i32
  store i32 %r55, ptr %r53, align 1
  br label %L18
L18:
  %r56 = call ptr @zfy_seq_new(i64 8, i64 8, i32 4)
  store ptr %r56, ptr %v.sub
  %r57 = add i64 1, 0
  %r58 = add i64 4, 0
  %r59 = load ptr, ptr %v.n
  %r60 = call ptr @zfy_seq_slice(ptr %r59, i64 %r57, i64 %r58, i64 1, i8 0)
  %r61 = load ptr, ptr %v.sub
  call void @zfy_seq_free(ptr %r61, i8 0)
  store ptr %r60, ptr %v.sub
  %r62 = load ptr, ptr %v.sub
  %r63 = getelementptr inbounds %zfy.seq, ptr %r62, i32 0, i32 2
  %r64 = load i64, ptr %r63
  call void @zfy_print_i64(i64 %r64)
  %r65 = getelementptr inbounds [2 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r65)
  %r66 = add i64 0, 0
  %r67 = load ptr, ptr %v.sub
  %r68 = getelementptr inbounds %zfy.seq, ptr %r67, i32 0, i32 2
  %r69 = load i64, ptr %r68
  %r70 = icmp ult i64 %r66, %r69
  br i1 %r70, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r71 = load ptr, ptr %r67
  %r72 = mul i64 %r66, 4
  %r73 = getelementptr inbounds i8, ptr %r71, i64 %r72
  %r74 = load i32, ptr %r73, align 1
  %r75 = sext i32 %r74 to i128
  br label %L21
L21:
  %r76 = trunc i128 %r75 to i32
  %r77 = sext i32 %r76 to i64
  call void @zfy_print_i64(i64 %r77)
  %r78 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r78)
  %r79 = add i64 1, 0
  %r80 = load ptr, ptr %v.sub
  %r81 = getelementptr inbounds %zfy.seq, ptr %r80, i32 0, i32 2
  %r82 = load i64, ptr %r81
  %r83 = icmp ult i64 %r79, %r82
  br i1 %r83, label %L22, label %L23
L23:
  call void @zfy_bounds_fail()
  unreachable
L22:
  %r84 = load ptr, ptr %r80
  %r85 = mul i64 %r79, 4
  %r86 = getelementptr inbounds i8, ptr %r84, i64 %r85
  %r87 = load i32, ptr %r86, align 1
  %r88 = sext i32 %r87 to i128
  br label %L24
L24:
  %r89 = trunc i128 %r88 to i32
  %r90 = sext i32 %r89 to i64
  call void @zfy_print_i64(i64 %r90)
  %r91 = getelementptr inbounds [2 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r91)
  %r92 = add i64 2, 0
  %r93 = load ptr, ptr %v.sub
  %r94 = getelementptr inbounds %zfy.seq, ptr %r93, i32 0, i32 2
  %r95 = load i64, ptr %r94
  %r96 = icmp ult i64 %r92, %r95
  br i1 %r96, label %L25, label %L26
L26:
  call void @zfy_bounds_fail()
  unreachable
L25:
  %r97 = load ptr, ptr %r93
  %r98 = mul i64 %r92, 4
  %r99 = getelementptr inbounds i8, ptr %r97, i64 %r98
  %r100 = load i32, ptr %r99, align 1
  %r101 = sext i32 %r100 to i128
  br label %L27
L27:
  %r102 = trunc i128 %r101 to i32
  %r103 = sext i32 %r102 to i64
  call void @zfy_print_i64(i64 %r103)
  %r104 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r104)
  %r105 = add i64 3, 0
  %r106 = load ptr, ptr %v.sub
  %r107 = getelementptr inbounds %zfy.seq, ptr %r106, i32 0, i32 2
  %r108 = load i64, ptr %r107
  %r109 = icmp ult i64 %r105, %r108
  br i1 %r109, label %L28, label %L29
L29:
  call void @zfy_bounds_fail()
  unreachable
L28:
  %r110 = load ptr, ptr %r106
  %r111 = mul i64 %r105, 4
  %r112 = getelementptr inbounds i8, ptr %r110, i64 %r111
  %r113 = load i32, ptr %r112, align 1
  %r114 = sext i32 %r113 to i128
  br label %L30
L30:
  %r115 = trunc i128 %r114 to i32
  %r116 = sext i32 %r115 to i64
  call void @zfy_print_i64(i64 %r116)
  %r117 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r117)
  %r118 = add i64 0, 0
  %r119 = load ptr, ptr %v.sub
  %r120 = getelementptr inbounds %zfy.seq, ptr %r119, i32 0, i32 2
  %r121 = load i64, ptr %r120
  %r122 = icmp ult i64 %r118, %r121
  br i1 %r122, label %L31, label %L32
L32:
  call void @zfy_bounds_fail()
  unreachable
L31:
  %r123 = load ptr, ptr %r119
  %r124 = mul i64 %r118, 4
  %r125 = getelementptr inbounds i8, ptr %r123, i64 %r124
  %r126 = sext i32 99 to i128
  %r127 = trunc i128 %r126 to i32
  store i32 %r127, ptr %r125, align 1
  br label %L33
L33:
  %r128 = add i64 1, 0
  %r129 = load ptr, ptr %v.n
  %r130 = getelementptr inbounds %zfy.seq, ptr %r129, i32 0, i32 2
  %r131 = load i64, ptr %r130
  %r132 = icmp ult i64 %r128, %r131
  br i1 %r132, label %L34, label %L35
L35:
  call void @zfy_bounds_fail()
  unreachable
L34:
  %r133 = load ptr, ptr %r129
  %r134 = mul i64 %r128, 4
  %r135 = getelementptr inbounds i8, ptr %r133, i64 %r134
  %r136 = load i32, ptr %r135, align 1
  %r137 = sext i32 %r136 to i128
  br label %L36
L36:
  %r138 = trunc i128 %r137 to i32
  %r139 = sext i32 %r138 to i64
  call void @zfy_print_i64(i64 %r139)
  %r140 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r140)
  %r141 = call ptr @zfy_seq_new(i64 8, i64 8, i32 4)
  store ptr %r141, ptr %v.stepped
  %r142 = add i64 0, 0
  %r143 = add i64 5, 0
  %r144 = add i64 2, 0
  %r145 = load ptr, ptr %v.n
  %r146 = call ptr @zfy_seq_slice(ptr %r145, i64 %r142, i64 %r143, i64 %r144, i8 0)
  %r147 = load ptr, ptr %v.stepped
  call void @zfy_seq_free(ptr %r147, i8 0)
  store ptr %r146, ptr %v.stepped
  %r148 = add i64 0, 0
  %r149 = load ptr, ptr %v.stepped
  %r150 = getelementptr inbounds %zfy.seq, ptr %r149, i32 0, i32 2
  %r151 = load i64, ptr %r150
  %r152 = icmp ult i64 %r148, %r151
  br i1 %r152, label %L37, label %L38
L38:
  call void @zfy_bounds_fail()
  unreachable
L37:
  %r153 = load ptr, ptr %r149
  %r154 = mul i64 %r148, 4
  %r155 = getelementptr inbounds i8, ptr %r153, i64 %r154
  %r156 = load i32, ptr %r155, align 1
  %r157 = sext i32 %r156 to i128
  br label %L39
L39:
  %r158 = trunc i128 %r157 to i32
  %r159 = sext i32 %r158 to i64
  call void @zfy_print_i64(i64 %r159)
  %r160 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r160)
  %r161 = add i64 1, 0
  %r162 = load ptr, ptr %v.stepped
  %r163 = getelementptr inbounds %zfy.seq, ptr %r162, i32 0, i32 2
  %r164 = load i64, ptr %r163
  %r165 = icmp ult i64 %r161, %r164
  br i1 %r165, label %L40, label %L41
L41:
  call void @zfy_bounds_fail()
  unreachable
L40:
  %r166 = load ptr, ptr %r162
  %r167 = mul i64 %r161, 4
  %r168 = getelementptr inbounds i8, ptr %r166, i64 %r167
  %r169 = load i32, ptr %r168, align 1
  %r170 = sext i32 %r169 to i128
  br label %L42
L42:
  %r171 = trunc i128 %r170 to i32
  %r172 = sext i32 %r171 to i64
  call void @zfy_print_i64(i64 %r172)
  %r173 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r173)
  %r174 = add i64 2, 0
  %r175 = load ptr, ptr %v.stepped
  %r176 = getelementptr inbounds %zfy.seq, ptr %r175, i32 0, i32 2
  %r177 = load i64, ptr %r176
  %r178 = icmp ult i64 %r174, %r177
  br i1 %r178, label %L43, label %L44
L44:
  call void @zfy_bounds_fail()
  unreachable
L43:
  %r179 = load ptr, ptr %r175
  %r180 = mul i64 %r174, 4
  %r181 = getelementptr inbounds i8, ptr %r179, i64 %r180
  %r182 = load i32, ptr %r181, align 1
  %r183 = sext i32 %r182 to i128
  br label %L45
L45:
  %r184 = trunc i128 %r183 to i32
  %r185 = sext i32 %r184 to i64
  call void @zfy_print_i64(i64 %r185)
  %r186 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r186)
  %r187 = add i64 2, 0
  %r188 = add i64 6, 0
  %r189 = load ptr, ptr %v.n
  %r190 = call ptr @zfy_seq_slice(ptr %r189, i64 %r187, i64 %r188, i64 1, i8 0)
  %r191 = getelementptr inbounds %zfy.seq, ptr %r190, i32 0, i32 2
  %r192 = load i64, ptr %r191
  call void @zfy_print_i64(i64 %r192)
  %r193 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r193)
  call void @zfy_seq_free(ptr %r190, i8 0)
  %r194 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r194, ptr %v.big
  %r195 = load ptr, ptr %v.big
  %r196 = bitcast double 10.5 to i64
  %r197 = zext i64 %r196 to i128
  store i128 %r197, ptr %r198
  call void @zfy_seq_set_w(ptr %r195, i64 0, ptr %r198, i32 8, i8 1)
  %r199 = load ptr, ptr %v.big
  %r200 = bitcast double 20.5 to i64
  %r201 = zext i64 %r200 to i128
  store i128 %r201, ptr %r202
  call void @zfy_seq_set_w(ptr %r199, i64 1, ptr %r202, i32 8, i8 1)
  %r203 = load ptr, ptr %v.big
  %r204 = bitcast double 30.5 to i64
  %r205 = zext i64 %r204 to i128
  store i128 %r205, ptr %r206
  call void @zfy_seq_set_w(ptr %r203, i64 2, ptr %r206, i32 8, i8 1)
  %r207 = load ptr, ptr %v.big
  %r208 = bitcast double 40.5 to i64
  %r209 = zext i64 %r208 to i128
  store i128 %r209, ptr %r210
  call void @zfy_seq_set_w(ptr %r207, i64 3, ptr %r210, i32 8, i8 1)
  %r211 = load ptr, ptr %v.big
  %r212 = bitcast double 50.5 to i64
  %r213 = zext i64 %r212 to i128
  store i128 %r213, ptr %r214
  call void @zfy_seq_set_w(ptr %r211, i64 4, ptr %r214, i32 8, i8 1)
  %r215 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r215, ptr %v.hf
  %r216 = add i64 1, 0
  %r217 = add i64 3, 0
  %r218 = load ptr, ptr %v.big
  %r219 = call ptr @zfy_seq_slice(ptr %r218, i64 %r216, i64 %r217, i64 1, i8 0)
  %r220 = load ptr, ptr %v.hf
  call void @zfy_seq_free(ptr %r220, i8 0)
  store ptr %r219, ptr %v.hf
  %r221 = load ptr, ptr %v.hf
  %r222 = getelementptr inbounds %zfy.seq, ptr %r221, i32 0, i32 2
  %r223 = load i64, ptr %r222
  call void @zfy_print_i64(i64 %r223)
  %r224 = getelementptr inbounds [3 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r224)
  %r225 = add i64 0, 0
  %r226 = load ptr, ptr %v.hf
  %r227 = getelementptr inbounds %zfy.seq, ptr %r226, i32 0, i32 2
  %r228 = load i64, ptr %r227
  %r229 = icmp ult i64 %r225, %r228
  br i1 %r229, label %L46, label %L47
L47:
  call void @zfy_bounds_fail()
  unreachable
L46:
  %r230 = load ptr, ptr %r226
  %r231 = mul i64 %r225, 8
  %r232 = getelementptr inbounds i8, ptr %r230, i64 %r231
  %r233 = load i64, ptr %r232, align 1
  %r234 = zext i64 %r233 to i128
  br label %L48
L48:
  %r235 = trunc i128 %r234 to i64
  %r236 = bitcast i64 %r235 to double
  call void @zfy_print_f64(double %r236)
  %r237 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r237)
  %r238 = add i64 1, 0
  %r239 = load ptr, ptr %v.hf
  %r240 = getelementptr inbounds %zfy.seq, ptr %r239, i32 0, i32 2
  %r241 = load i64, ptr %r240
  %r242 = icmp ult i64 %r238, %r241
  br i1 %r242, label %L49, label %L50
L50:
  call void @zfy_bounds_fail()
  unreachable
L49:
  %r243 = load ptr, ptr %r239
  %r244 = mul i64 %r238, 8
  %r245 = getelementptr inbounds i8, ptr %r243, i64 %r244
  %r246 = load i64, ptr %r245, align 1
  %r247 = zext i64 %r246 to i128
  br label %L51
L51:
  %r248 = trunc i128 %r247 to i64
  %r249 = bitcast i64 %r248 to double
  call void @zfy_print_f64(double %r249)
  %r250 = getelementptr inbounds [2 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r250)
  %r251 = add i64 2, 0
  %r252 = load ptr, ptr %v.hf
  %r253 = getelementptr inbounds %zfy.seq, ptr %r252, i32 0, i32 2
  %r254 = load i64, ptr %r253
  %r255 = icmp ult i64 %r251, %r254
  br i1 %r255, label %L52, label %L53
L53:
  call void @zfy_bounds_fail()
  unreachable
L52:
  %r256 = load ptr, ptr %r252
  %r257 = mul i64 %r251, 8
  %r258 = getelementptr inbounds i8, ptr %r256, i64 %r257
  %r259 = load i64, ptr %r258, align 1
  %r260 = zext i64 %r259 to i128
  br label %L54
L54:
  %r261 = trunc i128 %r260 to i64
  %r262 = bitcast i64 %r261 to double
  call void @zfy_print_f64(double %r262)
  %r263 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r263)
  %r264 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r264, ptr %v.stepped2
  %r265 = add i64 0, 0
  %r266 = add i64 4, 0
  %r267 = add i64 2, 0
  %r268 = load ptr, ptr %v.big
  %r269 = call ptr @zfy_seq_slice(ptr %r268, i64 %r265, i64 %r266, i64 %r267, i8 0)
  %r270 = load ptr, ptr %v.stepped2
  call void @zfy_seq_free(ptr %r270, i8 0)
  store ptr %r269, ptr %v.stepped2
  %r271 = add i64 0, 0
  %r272 = load ptr, ptr %v.stepped2
  %r273 = getelementptr inbounds %zfy.seq, ptr %r272, i32 0, i32 2
  %r274 = load i64, ptr %r273
  %r275 = icmp ult i64 %r271, %r274
  br i1 %r275, label %L55, label %L56
L56:
  call void @zfy_bounds_fail()
  unreachable
L55:
  %r276 = load ptr, ptr %r272
  %r277 = mul i64 %r271, 8
  %r278 = getelementptr inbounds i8, ptr %r276, i64 %r277
  %r279 = load i64, ptr %r278, align 1
  %r280 = zext i64 %r279 to i128
  br label %L57
L57:
  %r281 = trunc i128 %r280 to i64
  %r282 = bitcast i64 %r281 to double
  call void @zfy_print_f64(double %r282)
  %r283 = getelementptr inbounds [2 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r283)
  %r284 = add i64 1, 0
  %r285 = load ptr, ptr %v.stepped2
  %r286 = getelementptr inbounds %zfy.seq, ptr %r285, i32 0, i32 2
  %r287 = load i64, ptr %r286
  %r288 = icmp ult i64 %r284, %r287
  br i1 %r288, label %L58, label %L59
L59:
  call void @zfy_bounds_fail()
  unreachable
L58:
  %r289 = load ptr, ptr %r285
  %r290 = mul i64 %r284, 8
  %r291 = getelementptr inbounds i8, ptr %r289, i64 %r290
  %r292 = load i64, ptr %r291, align 1
  %r293 = zext i64 %r292 to i128
  br label %L60
L60:
  %r294 = trunc i128 %r293 to i64
  %r295 = bitcast i64 %r294 to double
  call void @zfy_print_f64(double %r295)
  %r296 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r296)
  %r297 = add i64 2, 0
  %r298 = load ptr, ptr %v.stepped2
  %r299 = getelementptr inbounds %zfy.seq, ptr %r298, i32 0, i32 2
  %r300 = load i64, ptr %r299
  %r301 = icmp ult i64 %r297, %r300
  br i1 %r301, label %L61, label %L62
L62:
  call void @zfy_bounds_fail()
  unreachable
L61:
  %r302 = load ptr, ptr %r298
  %r303 = mul i64 %r297, 8
  %r304 = getelementptr inbounds i8, ptr %r302, i64 %r303
  %r305 = load i64, ptr %r304, align 1
  %r306 = zext i64 %r305 to i128
  br label %L63
L63:
  %r307 = trunc i128 %r306 to i64
  %r308 = bitcast i64 %r307 to double
  call void @zfy_print_f64(double %r308)
  %r309 = getelementptr inbounds [2 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r309)
  %r310 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r310, ptr %v.names
  %r311 = load ptr, ptr %v.names
  %r312 = getelementptr inbounds [3 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r311, i64 0, ptr %r312, i8 1)
  %r313 = load ptr, ptr %v.names
  %r314 = getelementptr inbounds [3 x i8], ptr @.str19, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r313, i64 1, ptr %r314, i8 1)
  %r315 = load ptr, ptr %v.names
  %r316 = getelementptr inbounds [3 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r315, i64 2, ptr %r316, i8 1)
  %r317 = load ptr, ptr %v.names
  %r318 = getelementptr inbounds [3 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r317, i64 3, ptr %r318, i8 1)
  %r319 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r319, ptr %v.picked
  %r320 = add i64 1, 0
  %r321 = add i64 3, 0
  %r322 = load ptr, ptr %v.names
  %r323 = call ptr @zfy_seq_slice(ptr %r322, i64 %r320, i64 %r321, i64 1, i8 1)
  %r324 = load ptr, ptr %v.picked
  call void @zfy_seq_free(ptr %r324, i8 1)
  store ptr %r323, ptr %v.picked
  %r325 = add i64 0, 0
  %r326 = load ptr, ptr %v.picked
  %r327 = getelementptr inbounds [3 x i8], ptr @.str22, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r326, i64 %r325, ptr %r327, i8 1)
  %r328 = add i64 0, 0
  %r330 = load ptr, ptr %v.picked
  call void @zfy_seq_get(ptr %r330, i64 %r328, ptr %r329, i32 8, i8 0)
  %r331 = load i128, ptr %r329
  %r332 = trunc i128 %r331 to i64
  %r333 = inttoptr i64 %r332 to ptr
  call void @zfy_print_str(ptr %r333)
  %r334 = getelementptr inbounds [2 x i8], ptr @.str23, i64 0, i64 0
  call void @zfy_print_str(ptr %r334)
  %r335 = add i64 1, 0
  %r337 = load ptr, ptr %v.picked
  call void @zfy_seq_get(ptr %r337, i64 %r335, ptr %r336, i32 8, i8 0)
  %r338 = load i128, ptr %r336
  %r339 = trunc i128 %r338 to i64
  %r340 = inttoptr i64 %r339 to ptr
  call void @zfy_print_str(ptr %r340)
  %r341 = getelementptr inbounds [2 x i8], ptr @.str24, i64 0, i64 0
  call void @zfy_print_str(ptr %r341)
  %r342 = add i64 2, 0
  %r344 = load ptr, ptr %v.picked
  call void @zfy_seq_get(ptr %r344, i64 %r342, ptr %r343, i32 8, i8 0)
  %r345 = load i128, ptr %r343
  %r346 = trunc i128 %r345 to i64
  %r347 = inttoptr i64 %r346 to ptr
  call void @zfy_print_str(ptr %r347)
  %r348 = getelementptr inbounds [2 x i8], ptr @.str25, i64 0, i64 0
  call void @zfy_print_str(ptr %r348)
  %r349 = add i64 1, 0
  %r351 = load ptr, ptr %v.names
  call void @zfy_seq_get(ptr %r351, i64 %r349, ptr %r350, i32 8, i8 0)
  %r352 = load i128, ptr %r350
  %r353 = trunc i128 %r352 to i64
  %r354 = inttoptr i64 %r353 to ptr
  call void @zfy_print_str(ptr %r354)
  %r355 = getelementptr inbounds [2 x i8], ptr @.str26, i64 0, i64 0
  call void @zfy_print_str(ptr %r355)
  %r356 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r356)
  %r357 = getelementptr inbounds [7 x i8], ptr @.str27, i64 0, i64 0
  %r358 = call ptr @zfy_strdup(ptr %r357)
  store ptr %r358, ptr %v.s
  %r359 = load ptr, ptr %v.s
  %t62 = call i64 @zfy_str_find(ptr %r359, i8 97, i64 1)
  call void @zfy_print_i64(i64 %t62)
  %r360 = getelementptr inbounds [2 x i8], ptr @.str28, i64 0, i64 0
  call void @zfy_print_str(ptr %r360)
  %r361 = add i64 2, 0
  %r362 = load ptr, ptr %v.s
  %t64 = call i64 @zfy_str_find(ptr %r362, i8 97, i64 %r361)
  call void @zfy_print_i64(i64 %t64)
  %r363 = getelementptr inbounds [2 x i8], ptr @.str29, i64 0, i64 0
  call void @zfy_print_str(ptr %r363)
  %r364 = add i64 3, 0
  %r365 = load ptr, ptr %v.s
  %t66 = call i64 @zfy_str_find(ptr %r365, i8 97, i64 %r364)
  call void @zfy_print_i64(i64 %t66)
  %r366 = getelementptr inbounds [2 x i8], ptr @.str30, i64 0, i64 0
  call void @zfy_print_str(ptr %r366)
  %r367 = load ptr, ptr %v.s
  %t67 = call i64 @zfy_str_find(ptr %r367, i8 122, i64 1)
  call void @zfy_print_i64(i64 %t67)
  %r368 = getelementptr inbounds [2 x i8], ptr @.str31, i64 0, i64 0
  call void @zfy_print_str(ptr %r368)
  %r369 = load ptr, ptr %v.s
  %t68 = call ptr @zfy_str_trim(ptr %r369, i8 97)
  call void @zfy_print_str(ptr %t68)
  %r370 = getelementptr inbounds [2 x i8], ptr @.str32, i64 0, i64 0
  call void @zfy_print_str(ptr %r370)
  call void @zfy_free_str(ptr %t68)
  %r371 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r371, ptr %v.parts
  %r372 = load ptr, ptr %v.s
  %t69 = call ptr @zfy_str_split(ptr %r372, i8 97)
  %r373 = load ptr, ptr %v.parts
  call void @zfy_seq_free(ptr %r373, i8 1)
  store ptr %t69, ptr %v.parts
  %r374 = load ptr, ptr %v.parts
  %r375 = getelementptr inbounds %zfy.seq, ptr %r374, i32 0, i32 2
  %r376 = load i64, ptr %r375
  call void @zfy_print_i64(i64 %r376)
  %r377 = getelementptr inbounds [3 x i8], ptr @.str33, i64 0, i64 0
  call void @zfy_print_str(ptr %r377)
  %r378 = add i64 0, 0
  %r380 = load ptr, ptr %v.parts
  call void @zfy_seq_get(ptr %r380, i64 %r378, ptr %r379, i32 8, i8 0)
  %r381 = load i128, ptr %r379
  %r382 = trunc i128 %r381 to i64
  %r383 = inttoptr i64 %r382 to ptr
  call void @zfy_print_str(ptr %r383)
  %r384 = getelementptr inbounds [2 x i8], ptr @.str34, i64 0, i64 0
  call void @zfy_print_str(ptr %r384)
  %r385 = add i64 1, 0
  %r387 = load ptr, ptr %v.parts
  call void @zfy_seq_get(ptr %r387, i64 %r385, ptr %r386, i32 8, i8 0)
  %r388 = load i128, ptr %r386
  %r389 = trunc i128 %r388 to i64
  %r390 = inttoptr i64 %r389 to ptr
  call void @zfy_print_str(ptr %r390)
  %r391 = getelementptr inbounds [2 x i8], ptr @.str35, i64 0, i64 0
  call void @zfy_print_str(ptr %r391)
  %r392 = add i64 2, 0
  %r394 = load ptr, ptr %v.parts
  call void @zfy_seq_get(ptr %r394, i64 %r392, ptr %r393, i32 8, i8 0)
  %r395 = load i128, ptr %r393
  %r396 = trunc i128 %r395 to i64
  %r397 = inttoptr i64 %r396 to ptr
  call void @zfy_print_str(ptr %r397)
  %r398 = getelementptr inbounds [2 x i8], ptr @.str36, i64 0, i64 0
  call void @zfy_print_str(ptr %r398)
  %r399 = add i64 3, 0
  %r401 = load ptr, ptr %v.parts
  call void @zfy_seq_get(ptr %r401, i64 %r399, ptr %r400, i32 8, i8 0)
  %r402 = load i128, ptr %r400
  %r403 = trunc i128 %r402 to i64
  %r404 = inttoptr i64 %r403 to ptr
  call void @zfy_print_str(ptr %r404)
  %r405 = getelementptr inbounds [2 x i8], ptr @.str37, i64 0, i64 0
  call void @zfy_print_str(ptr %r405)
  %r406 = add i64 0, 0
  %r407 = add i64 2, 0
  %r408 = load ptr, ptr %v.s
  %r409 = getelementptr inbounds [3 x i8], ptr @.str38, i64 0, i64 0
  %t81 = call ptr @zfy_str_replace(ptr %r408, i64 %r406, i64 %r407, ptr %r409)
  call void @zfy_print_str(ptr %t81)
  %r410 = getelementptr inbounds [2 x i8], ptr @.str39, i64 0, i64 0
  call void @zfy_print_str(ptr %r410)
  call void @zfy_free_str(ptr %t81)
  %r411 = load ptr, ptr %v.parts
  call void @zfy_seq_free(ptr %r411, i8 1)
  store ptr null, ptr %v.parts
  %r412 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r412)
  store ptr null, ptr %v.s
  %r413 = load ptr, ptr %v.picked
  call void @zfy_seq_free(ptr %r413, i8 1)
  store ptr null, ptr %v.picked
  %r414 = load ptr, ptr %v.names
  call void @zfy_seq_free(ptr %r414, i8 1)
  store ptr null, ptr %v.names
  %r415 = load ptr, ptr %v.stepped2
  call void @zfy_seq_free(ptr %r415, i8 0)
  store ptr null, ptr %v.stepped2
  %r416 = load ptr, ptr %v.hf
  call void @zfy_seq_free(ptr %r416, i8 0)
  store ptr null, ptr %v.hf
  %r417 = load ptr, ptr %v.big
  call void @zfy_seq_free(ptr %r417, i8 0)
  store ptr null, ptr %v.big
  %r418 = load ptr, ptr %v.stepped
  call void @zfy_seq_free(ptr %r418, i8 0)
  store ptr null, ptr %v.stepped
  %r419 = load ptr, ptr %v.sub
  call void @zfy_seq_free(ptr %r419, i8 0)
  store ptr null, ptr %v.sub
  %r420 = load ptr, ptr %v.n
  call void @zfy_seq_free(ptr %r420, i8 0)
  store ptr null, ptr %v.n
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
