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
@.str4 = private unnamed_addr constant [2 x i8] c"x\00"
@.str5 = private unnamed_addr constant [3 x i8] c"yz\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.s = alloca ptr
  %v.d = alloca ptr
  %v.a = alloca ptr
  %r4 = alloca i128
  %r7 = alloca i128
  %r13 = alloca i128
  %r19 = alloca i128
  %r77 = alloca i128
  %r84 = alloca i128
  %r107 = alloca i128
  store ptr null, ptr %v.s
  store ptr null, ptr %v.d
  store ptr null, ptr %v.a
  %r1 = call ptr @zfy_seq_new(i64 0, i64 8, i32 4)
  store ptr %r1, ptr %v.a
  %r2 = load ptr, ptr %v.a
  %r3 = sext i32 1 to i128
  store i128 %r3, ptr %r4
  call void @zfy_seq_set_w(ptr %r2, i64 0, ptr %r4, i32 4, i8 1)
  %r5 = load ptr, ptr %v.a
  %r6 = sext i32 2 to i128
  store i128 %r6, ptr %r7
  call void @zfy_seq_set_w(ptr %r5, i64 1, ptr %r7, i32 4, i8 1)
  %r8 = load ptr, ptr %v.a
  %r9 = getelementptr inbounds %zfy.seq, ptr %r8, i32 0, i32 2
  %r10 = load i64, ptr %r9
  %r11 = load ptr, ptr %v.a
  %r12 = sext i32 3 to i128
  store i128 %r12, ptr %r13
  call void @zfy_seq_set_w(ptr %r11, i64 %r10, ptr %r13, i32 4, i8 1)
  %r14 = load ptr, ptr %v.a
  %r15 = getelementptr inbounds %zfy.seq, ptr %r14, i32 0, i32 2
  %r16 = load i64, ptr %r15
  %r17 = load ptr, ptr %v.a
  %r18 = sext i32 4 to i128
  store i128 %r18, ptr %r19
  call void @zfy_seq_set_w(ptr %r17, i64 %r16, ptr %r19, i32 4, i8 1)
  %r20 = load ptr, ptr %v.a
  %r21 = getelementptr inbounds %zfy.seq, ptr %r20, i32 0, i32 2
  %r22 = load i64, ptr %r21
  call void @zfy_print_i64(i64 %r22)
  %r23 = getelementptr inbounds [2 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r23)
  %r24 = add i64 0, 0
  %r25 = load ptr, ptr %v.a
  %r26 = getelementptr inbounds %zfy.seq, ptr %r25, i32 0, i32 2
  %r27 = load i64, ptr %r26
  %r28 = icmp ult i64 %r24, %r27
  br i1 %r28, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r29 = load ptr, ptr %r25
  %r30 = mul i64 %r24, 4
  %r31 = getelementptr inbounds i8, ptr %r29, i64 %r30
  %r32 = load i32, ptr %r31, align 1
  %r33 = sext i32 %r32 to i128
  br label %L3
L3:
  %r34 = trunc i128 %r33 to i32
  %r35 = sext i32 %r34 to i64
  call void @zfy_print_i64(i64 %r35)
  %t6 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t6)
  %r36 = add i64 1, 0
  %r37 = load ptr, ptr %v.a
  %r38 = getelementptr inbounds %zfy.seq, ptr %r37, i32 0, i32 2
  %r39 = load i64, ptr %r38
  %r40 = icmp ult i64 %r36, %r39
  br i1 %r40, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r41 = load ptr, ptr %r37
  %r42 = mul i64 %r36, 4
  %r43 = getelementptr inbounds i8, ptr %r41, i64 %r42
  %r44 = load i32, ptr %r43, align 1
  %r45 = sext i32 %r44 to i128
  br label %L6
L6:
  %r46 = trunc i128 %r45 to i32
  %r47 = sext i32 %r46 to i64
  call void @zfy_print_i64(i64 %r47)
  %t9 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t9)
  %r48 = add i64 2, 0
  %r49 = load ptr, ptr %v.a
  %r50 = getelementptr inbounds %zfy.seq, ptr %r49, i32 0, i32 2
  %r51 = load i64, ptr %r50
  %r52 = icmp ult i64 %r48, %r51
  br i1 %r52, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r53 = load ptr, ptr %r49
  %r54 = mul i64 %r48, 4
  %r55 = getelementptr inbounds i8, ptr %r53, i64 %r54
  %r56 = load i32, ptr %r55, align 1
  %r57 = sext i32 %r56 to i128
  br label %L9
L9:
  %r58 = trunc i128 %r57 to i32
  %r59 = sext i32 %r58 to i64
  call void @zfy_print_i64(i64 %r59)
  %t12 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t12)
  %r60 = add i64 3, 0
  %r61 = load ptr, ptr %v.a
  %r62 = getelementptr inbounds %zfy.seq, ptr %r61, i32 0, i32 2
  %r63 = load i64, ptr %r62
  %r64 = icmp ult i64 %r60, %r63
  br i1 %r64, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r65 = load ptr, ptr %r61
  %r66 = mul i64 %r60, 4
  %r67 = getelementptr inbounds i8, ptr %r65, i64 %r66
  %r68 = load i32, ptr %r67, align 1
  %r69 = sext i32 %r68 to i128
  br label %L12
L12:
  %r70 = trunc i128 %r69 to i32
  %r71 = sext i32 %r70 to i64
  call void @zfy_print_i64(i64 %r71)
  %r72 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r72)
  call void @zfy_free_str(ptr %t6)
  call void @zfy_free_str(ptr %t9)
  call void @zfy_free_str(ptr %t12)
  %r73 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r73, ptr %v.d
  %r74 = load ptr, ptr %v.d
  %r75 = bitcast double 1.5 to i64
  %r76 = zext i64 %r75 to i128
  store i128 %r76, ptr %r77
  call void @zfy_seq_set_w(ptr %r74, i64 0, ptr %r77, i32 8, i8 1)
  %r78 = load ptr, ptr %v.d
  %r79 = getelementptr inbounds %zfy.seq, ptr %r78, i32 0, i32 2
  %r80 = load i64, ptr %r79
  %r81 = load ptr, ptr %v.d
  %r82 = bitcast double 2.5 to i64
  %r83 = zext i64 %r82 to i128
  store i128 %r83, ptr %r84
  call void @zfy_seq_set_w(ptr %r81, i64 %r80, ptr %r84, i32 8, i8 1)
  %r85 = add i64 1, 0
  %r86 = load ptr, ptr %v.d
  %r87 = getelementptr inbounds %zfy.seq, ptr %r86, i32 0, i32 2
  %r88 = load i64, ptr %r87
  %r89 = icmp ult i64 %r85, %r88
  br i1 %r89, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r90 = load ptr, ptr %r86
  %r91 = mul i64 %r85, 8
  %r92 = getelementptr inbounds i8, ptr %r90, i64 %r91
  %r93 = load i64, ptr %r92, align 1
  %r94 = zext i64 %r93 to i128
  br label %L15
L15:
  %r95 = trunc i128 %r94 to i64
  %r96 = bitcast i64 %r95 to double
  call void @zfy_print_f64(double %r96)
  %r97 = getelementptr inbounds [2 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r97)
  %r98 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r98, ptr %v.s
  %r99 = load ptr, ptr %v.s
  %r100 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r99, i64 0, ptr %r100, i8 1)
  %r101 = load ptr, ptr %v.s
  %r102 = getelementptr inbounds %zfy.seq, ptr %r101, i32 0, i32 2
  %r103 = load i64, ptr %r102
  %r104 = load ptr, ptr %v.s
  %r105 = getelementptr inbounds [3 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_seq_set_str(ptr %r104, i64 %r103, ptr %r105, i8 1)
  %r106 = add i64 1, 0
  %r108 = load ptr, ptr %v.s
  call void @zfy_seq_get(ptr %r108, i64 %r106, ptr %r107, i32 8, i8 0)
  %r109 = load i128, ptr %r107
  %r110 = trunc i128 %r109 to i64
  %r111 = inttoptr i64 %r110 to ptr
  call void @zfy_print_str(ptr %r111)
  %r112 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r112)
  %r113 = load ptr, ptr %v.s
  call void @zfy_seq_free(ptr %r113, i8 1)
  store ptr null, ptr %v.s
  %r114 = load ptr, ptr %v.d
  call void @zfy_seq_free(ptr %r114, i8 0)
  store ptr null, ptr %v.d
  %r115 = load ptr, ptr %v.a
  call void @zfy_seq_free(ptr %r115, i8 0)
  store ptr null, ptr %v.a
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
