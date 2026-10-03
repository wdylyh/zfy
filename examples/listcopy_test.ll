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
@.str1 = private unnamed_addr constant [1 x i8] c"\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.c = alloca ptr
  %v.b = alloca ptr
  %v.a = alloca ptr
  %r4 = alloca i128
  %r7 = alloca i128
  %r10 = alloca i128
  %r17 = alloca i128
  %r47 = alloca i128
  %r80 = alloca i128
  store ptr null, ptr %v.c
  store ptr null, ptr %v.b
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
  %r9 = sext i32 3 to i128
  store i128 %r9, ptr %r10
  call void @zfy_seq_set_w(ptr %r8, i64 2, ptr %r10, i32 4, i8 1)
  %r11 = load ptr, ptr %v.b
  call void @zfy_seq_free(ptr %r11, i8 0)
  %r12 = load ptr, ptr %v.a
  %r13 = call ptr @zfy_seq_clone(ptr %r12, i8 0)
  store ptr %r13, ptr %v.b
  %r14 = add i64 0, 0
  %r15 = load ptr, ptr %v.b
  %r16 = sext i32 100 to i128
  store i128 %r16, ptr %r17
  call void @zfy_seq_set_w(ptr %r15, i64 %r14, ptr %r17, i32 4, i8 1)
  %r18 = add i64 0, 0
  %r19 = load ptr, ptr %v.a
  %r20 = getelementptr inbounds %zfy.seq, ptr %r19, i32 0, i32 2
  %r21 = load i64, ptr %r20
  %r22 = icmp ult i64 %r18, %r21
  br i1 %r22, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r23 = load ptr, ptr %r19
  %r24 = mul i64 %r18, 4
  %r25 = getelementptr inbounds i8, ptr %r23, i64 %r24
  %r26 = load i32, ptr %r25, align 1
  %r27 = sext i32 %r26 to i128
  br label %L3
L3:
  %r28 = trunc i128 %r27 to i32
  %r29 = sext i32 %r28 to i64
  call void @zfy_print_i64(i64 %r29)
  %r30 = getelementptr inbounds [1 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r30)
  %r31 = add i64 0, 0
  %r32 = load ptr, ptr %v.b
  %r33 = getelementptr inbounds %zfy.seq, ptr %r32, i32 0, i32 2
  %r34 = load i64, ptr %r33
  %r35 = icmp ult i64 %r31, %r34
  br i1 %r35, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r36 = load ptr, ptr %r32
  %r37 = mul i64 %r31, 4
  %r38 = getelementptr inbounds i8, ptr %r36, i64 %r37
  %r39 = load i32, ptr %r38, align 1
  %r40 = sext i32 %r39 to i128
  br label %L6
L6:
  %r41 = trunc i128 %r40 to i32
  %r42 = sext i32 %r41 to i64
  call void @zfy_print_i64(i64 %r42)
  %r43 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r43)
  %r44 = add i64 2, 0
  %r45 = load ptr, ptr %v.b
  %r46 = sext i32 7 to i128
  store i128 %r46, ptr %r47
  call void @zfy_seq_set_w(ptr %r45, i64 %r44, ptr %r47, i32 4, i8 1)
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
  %r60 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r60)
  %r61 = add i64 2, 0
  %r62 = load ptr, ptr %v.b
  %r63 = getelementptr inbounds %zfy.seq, ptr %r62, i32 0, i32 2
  %r64 = load i64, ptr %r63
  %r65 = icmp ult i64 %r61, %r64
  br i1 %r65, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r66 = load ptr, ptr %r62
  %r67 = mul i64 %r61, 4
  %r68 = getelementptr inbounds i8, ptr %r66, i64 %r67
  %r69 = load i32, ptr %r68, align 1
  %r70 = sext i32 %r69 to i128
  br label %L12
L12:
  %r71 = trunc i128 %r70 to i32
  %r72 = sext i32 %r71 to i64
  call void @zfy_print_i64(i64 %r72)
  %r73 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r73)
  %r74 = load ptr, ptr %v.c
  call void @zfy_seq_free(ptr %r74, i8 0)
  %r75 = load ptr, ptr %v.a
  %r76 = call ptr @zfy_seq_clone(ptr %r75, i8 0)
  store ptr %r76, ptr %v.c
  %r77 = add i64 0, 0
  %r78 = load ptr, ptr %v.c
  %r79 = sext i32 5 to i128
  store i128 %r79, ptr %r80
  call void @zfy_seq_set_w(ptr %r78, i64 %r77, ptr %r80, i32 4, i8 1)
  %r81 = add i64 0, 0
  %r82 = load ptr, ptr %v.a
  %r83 = getelementptr inbounds %zfy.seq, ptr %r82, i32 0, i32 2
  %r84 = load i64, ptr %r83
  %r85 = icmp ult i64 %r81, %r84
  br i1 %r85, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r86 = load ptr, ptr %r82
  %r87 = mul i64 %r81, 4
  %r88 = getelementptr inbounds i8, ptr %r86, i64 %r87
  %r89 = load i32, ptr %r88, align 1
  %r90 = sext i32 %r89 to i128
  br label %L15
L15:
  %r91 = trunc i128 %r90 to i32
  %r92 = sext i32 %r91 to i64
  call void @zfy_print_i64(i64 %r92)
  %r93 = getelementptr inbounds [1 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r93)
  %r94 = add i64 0, 0
  %r95 = load ptr, ptr %v.c
  %r96 = getelementptr inbounds %zfy.seq, ptr %r95, i32 0, i32 2
  %r97 = load i64, ptr %r96
  %r98 = icmp ult i64 %r94, %r97
  br i1 %r98, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r99 = load ptr, ptr %r95
  %r100 = mul i64 %r94, 4
  %r101 = getelementptr inbounds i8, ptr %r99, i64 %r100
  %r102 = load i32, ptr %r101, align 1
  %r103 = sext i32 %r102 to i128
  br label %L18
L18:
  %r104 = trunc i128 %r103 to i32
  %r105 = sext i32 %r104 to i64
  call void @zfy_print_i64(i64 %r105)
  %r106 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r106)
  %r107 = load ptr, ptr %v.c
  call void @zfy_seq_free(ptr %r107, i8 0)
  store ptr null, ptr %v.c
  %r108 = load ptr, ptr %v.b
  call void @zfy_seq_free(ptr %r108, i8 0)
  store ptr null, ptr %v.b
  %r109 = load ptr, ptr %v.a
  call void @zfy_seq_free(ptr %r109, i8 0)
  store ptr null, ptr %v.a
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
