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
@.str1 = private unnamed_addr constant [2 x i8] c",\00"
@.str2 = private unnamed_addr constant [2 x i8] c",\00"
@.str3 = private unnamed_addr constant [2 x i8] c",\00"
@.str4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str5 = private unnamed_addr constant [2 x i8] c"[\00"
@.str6 = private unnamed_addr constant [1 x i8] c"\00"
@.str7 = private unnamed_addr constant [1 x i8] c"\00"
@.str8 = private unnamed_addr constant [2 x i8] c"]\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str12 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str13 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str14 = private unnamed_addr constant [2 x i8] c";\00"
@.str15 = private unnamed_addr constant [2 x i8] c";\00"
@.str16 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str17 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str18 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str19 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str20 = private unnamed_addr constant [2 x i8] c"[\00"
@.str21 = private unnamed_addr constant [1 x i8] c"\00"
@.str22 = private unnamed_addr constant [1 x i8] c"\00"
@.str23 = private unnamed_addr constant [2 x i8] c",\00"
@.str24 = private unnamed_addr constant [1 x i8] c"\00"
@.str25 = private unnamed_addr constant [1 x i8] c"\00"
@.str26 = private unnamed_addr constant [2 x i8] c"]\00"
@.str27 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str28 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str29 = private unnamed_addr constant [4 x i8] c"abc\00"
@.str30 = private unnamed_addr constant [4 x i8] c"xyz\00"
@.str31 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str32 = private unnamed_addr constant [2 x i8] c"|\00"
@.str33 = private unnamed_addr constant [2 x i8] c"|\00"
@.str34 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str35 = private unnamed_addr constant [2 x i8] c",\00"
@.str36 = private unnamed_addr constant [2 x i8] c",\00"
@.str37 = private unnamed_addr constant [2 x i8] c",\00"
@.str38 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str39 = private unnamed_addr constant [1 x i8] c"\00"
@.str40 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str41 = private unnamed_addr constant [2 x i8] c",\00"
@.str42 = private unnamed_addr constant [2 x i8] c",\00"
@.str43 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.cs = alloca ptr
  %v.flags = alloca ptr
  %v.w = alloca ptr
  %v.big = alloca ptr
  %v.i = alloca i32
  %v.m = alloca i64
  %v.n = alloca ptr
  %r175 = alloca i128
  %r179 = alloca i128
  %r183 = alloca i128
  %r233 = alloca i128
  %r255 = alloca i128
  %r320 = alloca i128
  %r327 = alloca i128
  %r334 = alloca i128
  store ptr null, ptr %v.cs
  store ptr null, ptr %v.flags
  store ptr null, ptr %v.w
  store ptr null, ptr %v.big
  store i32 zeroinitializer, ptr %v.i
  store i64 zeroinitializer, ptr %v.m
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
  %r9 = sext i32 3 to i128
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
  %r18 = sext i32 4 to i128
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
  %r27 = sext i32 5 to i128
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
  %r36 = sext i32 6 to i128
  %r37 = trunc i128 %r36 to i32
  store i32 %r37, ptr %r35, align 1
  br label %L12
L12:
  %r38 = add i64 0, 0
  %r39 = load ptr, ptr %v.n
  %r40 = getelementptr inbounds %zfy.seq, ptr %r39, i32 0, i32 2
  %r41 = load i64, ptr %r40
  %r42 = icmp ult i64 %r38, %r41
  br i1 %r42, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r43 = load ptr, ptr %r39
  %r44 = mul i64 %r38, 4
  %r45 = getelementptr inbounds i8, ptr %r43, i64 %r44
  %r46 = load i32, ptr %r45, align 1
  %r47 = sext i32 %r46 to i128
  br label %L15
L15:
  %r48 = trunc i128 %r47 to i32
  %r49 = sext i32 %r48 to i64
  call void @zfy_print_i64(i64 %r49)
  %r50 = getelementptr inbounds [2 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r50)
  %r51 = add i64 1, 0
  %r52 = load ptr, ptr %v.n
  %r53 = getelementptr inbounds %zfy.seq, ptr %r52, i32 0, i32 2
  %r54 = load i64, ptr %r53
  %r55 = icmp ult i64 %r51, %r54
  br i1 %r55, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r56 = load ptr, ptr %r52
  %r57 = mul i64 %r51, 4
  %r58 = getelementptr inbounds i8, ptr %r56, i64 %r57
  %r59 = load i32, ptr %r58, align 1
  %r60 = sext i32 %r59 to i128
  br label %L18
L18:
  %r61 = trunc i128 %r60 to i32
  %r62 = sext i32 %r61 to i64
  call void @zfy_print_i64(i64 %r62)
  %r63 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r63)
  %r64 = add i64 2, 0
  %r65 = load ptr, ptr %v.n
  %r66 = getelementptr inbounds %zfy.seq, ptr %r65, i32 0, i32 2
  %r67 = load i64, ptr %r66
  %r68 = icmp ult i64 %r64, %r67
  br i1 %r68, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r69 = load ptr, ptr %r65
  %r70 = mul i64 %r64, 4
  %r71 = getelementptr inbounds i8, ptr %r69, i64 %r70
  %r72 = load i32, ptr %r71, align 1
  %r73 = sext i32 %r72 to i128
  br label %L21
L21:
  %r74 = trunc i128 %r73 to i32
  %r75 = sext i32 %r74 to i64
  call void @zfy_print_i64(i64 %r75)
  %r76 = getelementptr inbounds [2 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r76)
  %r77 = add i64 3, 0
  %r78 = load ptr, ptr %v.n
  %r79 = getelementptr inbounds %zfy.seq, ptr %r78, i32 0, i32 2
  %r80 = load i64, ptr %r79
  %r81 = icmp ult i64 %r77, %r80
  br i1 %r81, label %L22, label %L23
L23:
  call void @zfy_bounds_fail()
  unreachable
L22:
  %r82 = load ptr, ptr %r78
  %r83 = mul i64 %r77, 4
  %r84 = getelementptr inbounds i8, ptr %r82, i64 %r83
  %r85 = load i32, ptr %r84, align 1
  %r86 = sext i32 %r85 to i128
  br label %L24
L24:
  %r87 = trunc i128 %r86 to i32
  %r88 = sext i32 %r87 to i64
  call void @zfy_print_i64(i64 %r88)
  %r89 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r89)
  %r90 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r90)
  %r91 = getelementptr inbounds [1 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r91)
  %r92 = add i64 4, 0
  %r93 = load ptr, ptr %v.n
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
  %r104 = getelementptr inbounds [1 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r104)
  %r105 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r105)
  %t11 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t11)
  call void @zfy_free_str(ptr %t11)
  %r106 = add i64 4, 0
  %r107 = load ptr, ptr %v.n
  %r108 = getelementptr inbounds %zfy.seq, ptr %r107, i32 0, i32 2
  %r109 = load i64, ptr %r108
  %r110 = icmp ult i64 %r106, %r109
  br i1 %r110, label %L28, label %L29
L29:
  call void @zfy_bounds_fail()
  unreachable
L28:
  %r111 = load ptr, ptr %r107
  %r112 = mul i64 %r106, 4
  %r113 = getelementptr inbounds i8, ptr %r111, i64 %r112
  %r114 = sext i32 7 to i128
  %r115 = trunc i128 %r114 to i32
  store i32 %r115, ptr %r113, align 1
  br label %L30
L30:
  %r116 = add i64 4, 0
  %r117 = load ptr, ptr %v.n
  %r118 = getelementptr inbounds %zfy.seq, ptr %r117, i32 0, i32 2
  %r119 = load i64, ptr %r118
  %r120 = icmp ult i64 %r116, %r119
  br i1 %r120, label %L31, label %L32
L32:
  call void @zfy_bounds_fail()
  unreachable
L31:
  %r121 = load ptr, ptr %r117
  %r122 = mul i64 %r116, 4
  %r123 = getelementptr inbounds i8, ptr %r121, i64 %r122
  %r124 = load i32, ptr %r123, align 1
  %r125 = sext i32 %r124 to i128
  br label %L33
L33:
  %r126 = trunc i128 %r125 to i32
  %r127 = sext i32 %r126 to i64
  call void @zfy_print_i64(i64 %r127)
  %r128 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r128)
  %r129 = add i64 2, 0
  %r130 = load ptr, ptr %v.n
  %r131 = getelementptr inbounds %zfy.seq, ptr %r130, i32 0, i32 2
  %r132 = load i64, ptr %r131
  %r133 = icmp ult i64 %r129, %r132
  br i1 %r133, label %L34, label %L35
L35:
  call void @zfy_bounds_fail()
  unreachable
L34:
  %r134 = load ptr, ptr %r130
  %r135 = mul i64 %r129, 4
  %r136 = getelementptr inbounds i8, ptr %r134, i64 %r135
  %r137 = load i32, ptr %r136, align 1
  %r138 = sext i32 %r137 to i128
  br label %L36
L36:
  %r139 = trunc i128 %r138 to i32
  %r140 = sext i32 %r139 to i64
  store i64 %r140, ptr %v.m
  %r141 = load i64, ptr %v.m
  call void @zfy_print_i64(i64 %r141)
  %r142 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r142)
  store i32 1, ptr %v.i
  %r144 = load i32, ptr %v.i
  %r143 = add i32 %r144, 1
  %r145 = sext i32 %r143 to i64
  %r146 = load ptr, ptr %v.n
  %r147 = getelementptr inbounds %zfy.seq, ptr %r146, i32 0, i32 2
  %r148 = load i64, ptr %r147
  %r149 = icmp ult i64 %r145, %r148
  br i1 %r149, label %L37, label %L38
L38:
  call void @zfy_bounds_fail()
  unreachable
L37:
  %r150 = load ptr, ptr %r146
  %r151 = mul i64 %r145, 4
  %r152 = getelementptr inbounds i8, ptr %r150, i64 %r151
  %r153 = load i32, ptr %r152, align 1
  %r154 = sext i32 %r153 to i128
  br label %L39
L39:
  %r155 = trunc i128 %r154 to i32
  %r156 = sext i32 %r155 to i64
  call void @zfy_print_i64(i64 %r156)
  %r157 = getelementptr inbounds [2 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r157)
  %r158 = add i64 3, 0
  %r159 = load ptr, ptr %v.n
  %r160 = getelementptr inbounds %zfy.seq, ptr %r159, i32 0, i32 2
  %r161 = load i64, ptr %r160
  %r162 = icmp ult i64 %r158, %r161
  br i1 %r162, label %L40, label %L41
L41:
  call void @zfy_bounds_fail()
  unreachable
L40:
  %r163 = load ptr, ptr %r159
  %r164 = mul i64 %r158, 4
  %r165 = getelementptr inbounds i8, ptr %r163, i64 %r164
  %r166 = load i32, ptr %r165, align 1
  %r167 = sext i32 %r166 to i128
  br label %L42
L42:
  %r168 = trunc i128 %r167 to i32
  %r169 = sext i32 %r168 to i64
  call void @zfy_print_i64(i64 %r169)
  %r170 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r170)
  %r171 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r171, ptr %v.big
  %r172 = load ptr, ptr %v.big
  %r173 = bitcast double 23.34 to i64
  %r174 = zext i64 %r173 to i128
  store i128 %r174, ptr %r175
  call void @zfy_seq_set_w(ptr %r172, i64 0, ptr %r175, i32 8, i8 1)
  %r176 = load ptr, ptr %v.big
  %r177 = bitcast double 34.450000000000003 to i64
  %r178 = zext i64 %r177 to i128
  store i128 %r178, ptr %r179
  call void @zfy_seq_set_w(ptr %r176, i64 1, ptr %r179, i32 8, i8 1)
  %r180 = load ptr, ptr %v.big
  %r181 = bitcast double 4545.4555499999997 to i64
  %r182 = zext i64 %r181 to i128
  store i128 %r182, ptr %r183
  call void @zfy_seq_set_w(ptr %r180, i64 2, ptr %r183, i32 8, i8 1)
  %r184 = load ptr, ptr %v.big
  %r185 = getelementptr inbounds %zfy.seq, ptr %r184, i32 0, i32 2
  %r186 = load i64, ptr %r185
  call void @zfy_print_i64(i64 %r186)
  %r187 = getelementptr inbounds [2 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r187)
  %r188 = add i64 0, 0
  %r189 = load ptr, ptr %v.big
  %r190 = getelementptr inbounds %zfy.seq, ptr %r189, i32 0, i32 2
  %r191 = load i64, ptr %r190
  %r192 = icmp ult i64 %r188, %r191
  br i1 %r192, label %L43, label %L44
L44:
  call void @zfy_bounds_fail()
  unreachable
L43:
  %r193 = load ptr, ptr %r189
  %r194 = mul i64 %r188, 8
  %r195 = getelementptr inbounds i8, ptr %r193, i64 %r194
  %r196 = load i64, ptr %r195, align 1
  %r197 = zext i64 %r196 to i128
  br label %L45
L45:
  %r198 = trunc i128 %r197 to i64
  %r199 = bitcast i64 %r198 to double
  call void @zfy_print_f64(double %r199)
  %r200 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r200)
  %r201 = add i64 1, 0
  %r202 = load ptr, ptr %v.big
  %r203 = getelementptr inbounds %zfy.seq, ptr %r202, i32 0, i32 2
  %r204 = load i64, ptr %r203
  %r205 = icmp ult i64 %r201, %r204
  br i1 %r205, label %L46, label %L47
L47:
  call void @zfy_bounds_fail()
  unreachable
L46:
  %r206 = load ptr, ptr %r202
  %r207 = mul i64 %r201, 8
  %r208 = getelementptr inbounds i8, ptr %r206, i64 %r207
  %r209 = load i64, ptr %r208, align 1
  %r210 = zext i64 %r209 to i128
  br label %L48
L48:
  %r211 = trunc i128 %r210 to i64
  %r212 = bitcast i64 %r211 to double
  call void @zfy_print_f64(double %r212)
  %r213 = getelementptr inbounds [2 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r213)
  %r214 = add i64 2, 0
  %r215 = load ptr, ptr %v.big
  %r216 = getelementptr inbounds %zfy.seq, ptr %r215, i32 0, i32 2
  %r217 = load i64, ptr %r216
  %r218 = icmp ult i64 %r214, %r217
  br i1 %r218, label %L49, label %L50
L50:
  call void @zfy_bounds_fail()
  unreachable
L49:
  %r219 = load ptr, ptr %r215
  %r220 = mul i64 %r214, 8
  %r221 = getelementptr inbounds i8, ptr %r219, i64 %r220
  %r222 = load i64, ptr %r221, align 1
  %r223 = zext i64 %r222 to i128
  br label %L51
L51:
  %r224 = trunc i128 %r223 to i64
  %r225 = bitcast i64 %r224 to double
  call void @zfy_print_f64(double %r225)
  %r226 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r226)
  %r227 = load ptr, ptr %v.big
  %r228 = getelementptr inbounds %zfy.seq, ptr %r227, i32 0, i32 2
  %r229 = load i64, ptr %r228
  %r230 = load ptr, ptr %v.big
  %r231 = bitcast double 34.399999999999999 to i64
  %r232 = zext i64 %r231 to i128
  store i128 %r232, ptr %r233
  call void @zfy_seq_set_w(ptr %r230, i64 %r229, ptr %r233, i32 8, i8 1)
  %r234 = load ptr, ptr %v.big
  %r235 = getelementptr inbounds %zfy.seq, ptr %r234, i32 0, i32 2
  %r236 = load i64, ptr %r235
  call void @zfy_print_i64(i64 %r236)
  %r237 = getelementptr inbounds [2 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r237)
  %r238 = add i64 3, 0
  %r239 = load ptr, ptr %v.big
  %r240 = getelementptr inbounds %zfy.seq, ptr %r239, i32 0, i32 2
  %r241 = load i64, ptr %r240
  %r242 = icmp ult i64 %r238, %r241
  br i1 %r242, label %L52, label %L53
L53:
  call void @zfy_bounds_fail()
  unreachable
L52:
  %r243 = load ptr, ptr %r239
  %r244 = mul i64 %r238, 8
  %r245 = getelementptr inbounds i8, ptr %r243, i64 %r244
  %r246 = load i64, ptr %r245, align 1
  %r247 = zext i64 %r246 to i128
  br label %L54
L54:
  %r248 = trunc i128 %r247 to i64
  %r249 = bitcast i64 %r248 to double
  call void @zfy_print_f64(double %r249)
  %r250 = getelementptr inbounds [2 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_print_str(ptr %r250)
  %r251 = add i64 256, 0
  %r252 = load ptr, ptr %v.big
  %r253 = bitcast double 1.5 to i64
  %r254 = zext i64 %r253 to i128
  store i128 %r254, ptr %r255
  call void @zfy_seq_set_w(ptr %r252, i64 %r251, ptr %r255, i32 8, i8 1)
  %r256 = load ptr, ptr %v.big
  %r257 = getelementptr inbounds %zfy.seq, ptr %r256, i32 0, i32 2
  %r258 = load i64, ptr %r257
  call void @zfy_print_i64(i64 %r258)
  %r259 = getelementptr inbounds [2 x i8], ptr @.str19, i64 0, i64 0
  call void @zfy_print_str(ptr %r259)
  %r260 = getelementptr inbounds [2 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r260)
  %r261 = getelementptr inbounds [1 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r261)
  %r262 = add i64 129, 0
  %r263 = load ptr, ptr %v.big
  %r264 = getelementptr inbounds %zfy.seq, ptr %r263, i32 0, i32 2
  %r265 = load i64, ptr %r264
  %r266 = icmp ult i64 %r262, %r265
  br i1 %r266, label %L55, label %L56
L56:
  call void @zfy_bounds_fail()
  unreachable
L55:
  %r267 = load ptr, ptr %r263
  %r268 = mul i64 %r262, 8
  %r269 = getelementptr inbounds i8, ptr %r267, i64 %r268
  %r270 = load i64, ptr %r269, align 1
  %r271 = zext i64 %r270 to i128
  br label %L57
L57:
  %r272 = trunc i128 %r271 to i64
  %r273 = bitcast i64 %r272 to double
  call void @zfy_print_f64(double %r273)
  %r274 = getelementptr inbounds [1 x i8], ptr @.str22, i64 0, i64 0
  call void @zfy_print_str(ptr %r274)
  %r275 = getelementptr inbounds [2 x i8], ptr @.str23, i64 0, i64 0
  call void @zfy_print_str(ptr %r275)
  %r276 = getelementptr inbounds [1 x i8], ptr @.str24, i64 0, i64 0
  call void @zfy_print_str(ptr %r276)
  %r277 = add i64 255, 0
  %r278 = load ptr, ptr %v.big
  %r279 = getelementptr inbounds %zfy.seq, ptr %r278, i32 0, i32 2
  %r280 = load i64, ptr %r279
  %r281 = icmp ult i64 %r277, %r280
  br i1 %r281, label %L58, label %L59
L59:
  call void @zfy_bounds_fail()
  unreachable
L58:
  %r282 = load ptr, ptr %r278
  %r283 = mul i64 %r277, 8
  %r284 = getelementptr inbounds i8, ptr %r282, i64 %r283
  %r285 = load i64, ptr %r284, align 1
  %r286 = zext i64 %r285 to i128
  br label %L60
L60:
  %r287 = trunc i128 %r286 to i64
  %r288 = bitcast i64 %r287 to double
  call void @zfy_print_f64(double %r288)
  %r289 = getelementptr inbounds [1 x i8], ptr @.str25, i64 0, i64 0
  call void @zfy_print_str(ptr %r289)
  %r290 = getelementptr inbounds [2 x i8], ptr @.str26, i64 0, i64 0
  call void @zfy_print_str(ptr %r290)
  %t41 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t41)
  call void @zfy_free_str(ptr %t41)
  %r291 = add i64 256, 0
  %r292 = load ptr, ptr %v.big
  %r293 = getelementptr inbounds %zfy.seq, ptr %r292, i32 0, i32 2
  %r294 = load i64, ptr %r293
  %r295 = icmp ult i64 %r291, %r294
  br i1 %r295, label %L61, label %L62
L62:
  call void @zfy_bounds_fail()
  unreachable
L61:
  %r296 = load ptr, ptr %r292
  %r297 = mul i64 %r291, 8
  %r298 = getelementptr inbounds i8, ptr %r296, i64 %r297
  %r299 = load i64, ptr %r298, align 1
  %r300 = zext i64 %r299 to i128
  br label %L63
L63:
  %r301 = trunc i128 %r300 to i64
  %r302 = bitcast i64 %r301 to double
  call void @zfy_print_f64(double %r302)
  %r303 = getelementptr inbounds [2 x i8], ptr @.str27, i64 0, i64 0
  call void @zfy_print_str(ptr %r303)
  %r304 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r304, ptr %v.w
  %r305 = load ptr, ptr %v.w
  %r306 = getelementptr inbounds %zfy.seq, ptr %r305, i32 0, i32 2
  %r307 = load i64, ptr %r306
  call void @zfy_print_i64(i64 %r307)
  %r308 = getelementptr inbounds [2 x i8], ptr @.str28, i64 0, i64 0
  call void @zfy_print_str(ptr %r308)
  %r309 = add i64 0, 0
  %r310 = load ptr, ptr %v.w
  %r311 = getelementptr inbounds [4 x i8], ptr @.str29, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r310, i64 %r309, ptr %r311, i8 1)
  %r312 = add i64 2, 0
  %r313 = load ptr, ptr %v.w
  %r314 = getelementptr inbounds [4 x i8], ptr @.str30, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r313, i64 %r312, ptr %r314, i8 1)
  %r315 = load ptr, ptr %v.w
  %r316 = getelementptr inbounds %zfy.seq, ptr %r315, i32 0, i32 2
  %r317 = load i64, ptr %r316
  call void @zfy_print_i64(i64 %r317)
  %r318 = getelementptr inbounds [2 x i8], ptr @.str31, i64 0, i64 0
  call void @zfy_print_str(ptr %r318)
  %r319 = add i64 0, 0
  %r321 = load ptr, ptr %v.w
  call void @zfy_seq_get(ptr %r321, i64 %r319, ptr %r320, i32 8, i8 0)
  %r322 = load i128, ptr %r320
  %r323 = trunc i128 %r322 to i64
  %r324 = inttoptr i64 %r323 to ptr
  call void @zfy_print_str(ptr %r324)
  %r325 = getelementptr inbounds [2 x i8], ptr @.str32, i64 0, i64 0
  call void @zfy_print_str(ptr %r325)
  %r326 = add i64 1, 0
  %r328 = load ptr, ptr %v.w
  call void @zfy_seq_get(ptr %r328, i64 %r326, ptr %r327, i32 8, i8 0)
  %r329 = load i128, ptr %r327
  %r330 = trunc i128 %r329 to i64
  %r331 = inttoptr i64 %r330 to ptr
  call void @zfy_print_str(ptr %r331)
  %r332 = getelementptr inbounds [2 x i8], ptr @.str33, i64 0, i64 0
  call void @zfy_print_str(ptr %r332)
  %r333 = add i64 2, 0
  %r335 = load ptr, ptr %v.w
  call void @zfy_seq_get(ptr %r335, i64 %r333, ptr %r334, i32 8, i8 0)
  %r336 = load i128, ptr %r334
  %r337 = trunc i128 %r336 to i64
  %r338 = inttoptr i64 %r337 to ptr
  call void @zfy_print_str(ptr %r338)
  %r339 = getelementptr inbounds [2 x i8], ptr @.str34, i64 0, i64 0
  call void @zfy_print_str(ptr %r339)
  %r340 = call ptr @zfy_seq_new(i64 4, i64 4, i32 1)
  store ptr %r340, ptr %v.flags
  %r341 = load ptr, ptr %v.flags
  %r342 = getelementptr inbounds %zfy.seq, ptr %r341, i32 0, i32 2
  %r343 = load i64, ptr %r342
  %r344 = icmp ult i64 0, %r343
  br i1 %r344, label %L64, label %L65
L65:
  call void @zfy_bounds_fail()
  unreachable
L64:
  %r345 = load ptr, ptr %r341
  %r346 = mul i64 0, 1
  %r347 = getelementptr inbounds i8, ptr %r345, i64 %r346
  %r348 = zext i1 1 to i128
  %r349 = trunc i128 %r348 to i8
  store i8 %r349, ptr %r347, align 1
  br label %L66
L66:
  %r350 = load ptr, ptr %v.flags
  %r351 = getelementptr inbounds %zfy.seq, ptr %r350, i32 0, i32 2
  %r352 = load i64, ptr %r351
  %r353 = icmp ult i64 1, %r352
  br i1 %r353, label %L67, label %L68
L68:
  call void @zfy_bounds_fail()
  unreachable
L67:
  %r354 = load ptr, ptr %r350
  %r355 = mul i64 1, 1
  %r356 = getelementptr inbounds i8, ptr %r354, i64 %r355
  %r357 = zext i1 0 to i128
  %r358 = trunc i128 %r357 to i8
  store i8 %r358, ptr %r356, align 1
  br label %L69
L69:
  %r359 = load ptr, ptr %v.flags
  %r360 = getelementptr inbounds %zfy.seq, ptr %r359, i32 0, i32 2
  %r361 = load i64, ptr %r360
  %r362 = icmp ult i64 2, %r361
  br i1 %r362, label %L70, label %L71
L71:
  call void @zfy_bounds_fail()
  unreachable
L70:
  %r363 = load ptr, ptr %r359
  %r364 = mul i64 2, 1
  %r365 = getelementptr inbounds i8, ptr %r363, i64 %r364
  %r366 = zext i1 1 to i128
  %r367 = trunc i128 %r366 to i8
  store i8 %r367, ptr %r365, align 1
  br label %L72
L72:
  %r368 = add i64 0, 0
  %r369 = load ptr, ptr %v.flags
  %r370 = getelementptr inbounds %zfy.seq, ptr %r369, i32 0, i32 2
  %r371 = load i64, ptr %r370
  %r372 = icmp ult i64 %r368, %r371
  br i1 %r372, label %L73, label %L74
L74:
  call void @zfy_bounds_fail()
  unreachable
L73:
  %r373 = load ptr, ptr %r369
  %r374 = mul i64 %r368, 1
  %r375 = getelementptr inbounds i8, ptr %r373, i64 %r374
  %r376 = load i8, ptr %r375, align 1
  %r377 = zext i8 %r376 to i128
  br label %L75
L75:
  %r378 = trunc i128 %r377 to i1
  %r379 = zext i1 %r378 to i32
  call void @zfy_print_bool(i32 %r379)
  %r380 = getelementptr inbounds [2 x i8], ptr @.str35, i64 0, i64 0
  call void @zfy_print_str(ptr %r380)
  %r381 = add i64 1, 0
  %r382 = load ptr, ptr %v.flags
  %r383 = getelementptr inbounds %zfy.seq, ptr %r382, i32 0, i32 2
  %r384 = load i64, ptr %r383
  %r385 = icmp ult i64 %r381, %r384
  br i1 %r385, label %L76, label %L77
L77:
  call void @zfy_bounds_fail()
  unreachable
L76:
  %r386 = load ptr, ptr %r382
  %r387 = mul i64 %r381, 1
  %r388 = getelementptr inbounds i8, ptr %r386, i64 %r387
  %r389 = load i8, ptr %r388, align 1
  %r390 = zext i8 %r389 to i128
  br label %L78
L78:
  %r391 = trunc i128 %r390 to i1
  %r392 = zext i1 %r391 to i32
  call void @zfy_print_bool(i32 %r392)
  %r393 = getelementptr inbounds [2 x i8], ptr @.str36, i64 0, i64 0
  call void @zfy_print_str(ptr %r393)
  %r394 = add i64 2, 0
  %r395 = load ptr, ptr %v.flags
  %r396 = getelementptr inbounds %zfy.seq, ptr %r395, i32 0, i32 2
  %r397 = load i64, ptr %r396
  %r398 = icmp ult i64 %r394, %r397
  br i1 %r398, label %L79, label %L80
L80:
  call void @zfy_bounds_fail()
  unreachable
L79:
  %r399 = load ptr, ptr %r395
  %r400 = mul i64 %r394, 1
  %r401 = getelementptr inbounds i8, ptr %r399, i64 %r400
  %r402 = load i8, ptr %r401, align 1
  %r403 = zext i8 %r402 to i128
  br label %L81
L81:
  %r404 = trunc i128 %r403 to i1
  %r405 = zext i1 %r404 to i32
  call void @zfy_print_bool(i32 %r405)
  %r406 = getelementptr inbounds [2 x i8], ptr @.str37, i64 0, i64 0
  call void @zfy_print_str(ptr %r406)
  %r407 = add i64 3, 0
  %r408 = load ptr, ptr %v.flags
  %r409 = getelementptr inbounds %zfy.seq, ptr %r408, i32 0, i32 2
  %r410 = load i64, ptr %r409
  %r411 = icmp ult i64 %r407, %r410
  br i1 %r411, label %L82, label %L83
L83:
  call void @zfy_bounds_fail()
  unreachable
L82:
  %r412 = load ptr, ptr %r408
  %r413 = mul i64 %r407, 1
  %r414 = getelementptr inbounds i8, ptr %r412, i64 %r413
  %r415 = load i8, ptr %r414, align 1
  %r416 = zext i8 %r415 to i128
  br label %L84
L84:
  %r417 = trunc i128 %r416 to i1
  %r418 = zext i1 %r417 to i32
  call void @zfy_print_bool(i32 %r418)
  %r419 = getelementptr inbounds [2 x i8], ptr @.str38, i64 0, i64 0
  call void @zfy_print_str(ptr %r419)
  %r420 = getelementptr inbounds [1 x i8], ptr @.str39, i64 0, i64 0
  call void @zfy_print_str(ptr %r420)
  %r421 = getelementptr inbounds [2 x i8], ptr @.str40, i64 0, i64 0
  call void @zfy_print_str(ptr %r421)
  %r422 = call ptr @zfy_seq_new(i64 3, i64 3, i32 1)
  store ptr %r422, ptr %v.cs
  %r423 = load ptr, ptr %v.cs
  %r424 = getelementptr inbounds %zfy.seq, ptr %r423, i32 0, i32 2
  %r425 = load i64, ptr %r424
  %r426 = icmp ult i64 0, %r425
  br i1 %r426, label %L85, label %L86
L86:
  call void @zfy_bounds_fail()
  unreachable
L85:
  %r427 = load ptr, ptr %r423
  %r428 = mul i64 0, 1
  %r429 = getelementptr inbounds i8, ptr %r427, i64 %r428
  %r430 = zext i8 97 to i128
  %r431 = trunc i128 %r430 to i8
  store i8 %r431, ptr %r429, align 1
  br label %L87
L87:
  %r432 = load ptr, ptr %v.cs
  %r433 = getelementptr inbounds %zfy.seq, ptr %r432, i32 0, i32 2
  %r434 = load i64, ptr %r433
  %r435 = icmp ult i64 1, %r434
  br i1 %r435, label %L88, label %L89
L89:
  call void @zfy_bounds_fail()
  unreachable
L88:
  %r436 = load ptr, ptr %r432
  %r437 = mul i64 1, 1
  %r438 = getelementptr inbounds i8, ptr %r436, i64 %r437
  %r439 = zext i8 98 to i128
  %r440 = trunc i128 %r439 to i8
  store i8 %r440, ptr %r438, align 1
  br label %L90
L90:
  %r441 = add i64 0, 0
  %r442 = load ptr, ptr %v.cs
  %r443 = getelementptr inbounds %zfy.seq, ptr %r442, i32 0, i32 2
  %r444 = load i64, ptr %r443
  %r445 = icmp ult i64 %r441, %r444
  br i1 %r445, label %L91, label %L92
L92:
  call void @zfy_bounds_fail()
  unreachable
L91:
  %r446 = load ptr, ptr %r442
  %r447 = mul i64 %r441, 1
  %r448 = getelementptr inbounds i8, ptr %r446, i64 %r447
  %r449 = load i8, ptr %r448, align 1
  %r450 = zext i8 %r449 to i128
  br label %L93
L93:
  %r451 = trunc i128 %r450 to i8
  call void @zfy_print_char(i8 %r451)
  %r452 = getelementptr inbounds [2 x i8], ptr @.str41, i64 0, i64 0
  call void @zfy_print_str(ptr %r452)
  %r453 = add i64 1, 0
  %r454 = load ptr, ptr %v.cs
  %r455 = getelementptr inbounds %zfy.seq, ptr %r454, i32 0, i32 2
  %r456 = load i64, ptr %r455
  %r457 = icmp ult i64 %r453, %r456
  br i1 %r457, label %L94, label %L95
L95:
  call void @zfy_bounds_fail()
  unreachable
L94:
  %r458 = load ptr, ptr %r454
  %r459 = mul i64 %r453, 1
  %r460 = getelementptr inbounds i8, ptr %r458, i64 %r459
  %r461 = load i8, ptr %r460, align 1
  %r462 = zext i8 %r461 to i128
  br label %L96
L96:
  %r463 = trunc i128 %r462 to i8
  call void @zfy_print_char(i8 %r463)
  %r464 = getelementptr inbounds [2 x i8], ptr @.str42, i64 0, i64 0
  call void @zfy_print_str(ptr %r464)
  %r465 = add i64 2, 0
  %r466 = load ptr, ptr %v.cs
  %r467 = getelementptr inbounds %zfy.seq, ptr %r466, i32 0, i32 2
  %r468 = load i64, ptr %r467
  %r469 = icmp ult i64 %r465, %r468
  br i1 %r469, label %L97, label %L98
L98:
  call void @zfy_bounds_fail()
  unreachable
L97:
  %r470 = load ptr, ptr %r466
  %r471 = mul i64 %r465, 1
  %r472 = getelementptr inbounds i8, ptr %r470, i64 %r471
  %r473 = load i8, ptr %r472, align 1
  %r474 = zext i8 %r473 to i128
  br label %L99
L99:
  %r475 = trunc i128 %r474 to i8
  call void @zfy_print_char(i8 %r475)
  %r476 = getelementptr inbounds [2 x i8], ptr @.str43, i64 0, i64 0
  call void @zfy_print_str(ptr %r476)
  %r477 = load ptr, ptr %v.cs
  call void @zfy_seq_free(ptr %r477, i8 0)
  store ptr null, ptr %v.cs
  %r478 = load ptr, ptr %v.flags
  call void @zfy_seq_free(ptr %r478, i8 0)
  store ptr null, ptr %v.flags
  %r479 = load ptr, ptr %v.w
  call void @zfy_seq_free(ptr %r479, i8 1)
  store ptr null, ptr %v.w
  %r480 = load ptr, ptr %v.big
  call void @zfy_seq_free(ptr %r480, i8 0)
  store ptr null, ptr %v.big
  %r481 = load ptr, ptr %v.n
  call void @zfy_seq_free(ptr %r481, i8 0)
  store ptr null, ptr %v.n
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
