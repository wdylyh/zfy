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
@.str4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.au = alloca ptr
  %v.e = alloca i64
  %v.d = alloca i16
  %v.c = alloca i8
  %v.b = alloca i128
  %v.a = alloca i32
  %r5 = alloca i128
  store ptr null, ptr %v.au
  store i64 zeroinitializer, ptr %v.e
  store i16 zeroinitializer, ptr %v.d
  store i8 zeroinitializer, ptr %v.c
  store i128 zeroinitializer, ptr %v.b
  store i32 zeroinitializer, ptr %v.a
  store i32 3000000000, ptr %v.a
  store i128 1234567890123456789, ptr %v.b
  store i8 255, ptr %v.c
  store i16 65535, ptr %v.d
  store i64 4000000000, ptr %v.e
  %r1 = load i32, ptr %v.a
  %r2 = zext i32 %r1 to i64
  call void @zfy_print_u64(i64 %r2)
  %r3 = getelementptr inbounds [2 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r3)
  %r4 = load i128, ptr %v.b
  store i128 %r4, ptr %r5
  call void @zfy_print_u128(ptr %r5)
  %r6 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r6)
  %r7 = load i8, ptr %v.c
  %r8 = zext i8 %r7 to i64
  call void @zfy_print_u64(i64 %r8)
  %r9 = getelementptr inbounds [2 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r9)
  %r10 = load i16, ptr %v.d
  %r11 = zext i16 %r10 to i64
  call void @zfy_print_u64(i64 %r11)
  %r12 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r12)
  %r13 = load i64, ptr %v.e
  call void @zfy_print_u64(i64 %r13)
  %r14 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r14)
  %r15 = call ptr @zfy_seq_new(i64 3, i64 3, i32 4)
  store ptr %r15, ptr %v.au
  %r16 = load ptr, ptr %v.au
  %r17 = getelementptr inbounds %zfy.seq, ptr %r16, i32 0, i32 2
  %r18 = load i64, ptr %r17
  %r19 = icmp ult i64 0, %r18
  br i1 %r19, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r20 = load ptr, ptr %r16
  %r21 = mul i64 0, 4
  %r22 = getelementptr inbounds i8, ptr %r20, i64 %r21
  %r23 = zext i32 1 to i128
  %r24 = trunc i128 %r23 to i32
  store i32 %r24, ptr %r22, align 1
  br label %L3
L3:
  %r25 = load ptr, ptr %v.au
  %r26 = getelementptr inbounds %zfy.seq, ptr %r25, i32 0, i32 2
  %r27 = load i64, ptr %r26
  %r28 = icmp ult i64 1, %r27
  br i1 %r28, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r29 = load ptr, ptr %r25
  %r30 = mul i64 1, 4
  %r31 = getelementptr inbounds i8, ptr %r29, i64 %r30
  %r32 = zext i32 2 to i128
  %r33 = trunc i128 %r32 to i32
  store i32 %r33, ptr %r31, align 1
  br label %L6
L6:
  %r34 = load ptr, ptr %v.au
  %r35 = getelementptr inbounds %zfy.seq, ptr %r34, i32 0, i32 2
  %r36 = load i64, ptr %r35
  %r37 = icmp ult i64 2, %r36
  br i1 %r37, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r38 = load ptr, ptr %r34
  %r39 = mul i64 2, 4
  %r40 = getelementptr inbounds i8, ptr %r38, i64 %r39
  %r41 = zext i32 3 to i128
  %r42 = trunc i128 %r41 to i32
  store i32 %r42, ptr %r40, align 1
  br label %L9
L9:
  %r43 = add i64 2, 0
  %r44 = load ptr, ptr %v.au
  %r45 = getelementptr inbounds %zfy.seq, ptr %r44, i32 0, i32 2
  %r46 = load i64, ptr %r45
  %r47 = icmp ult i64 %r43, %r46
  br i1 %r47, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r48 = load ptr, ptr %r44
  %r49 = mul i64 %r43, 4
  %r50 = getelementptr inbounds i8, ptr %r48, i64 %r49
  %r51 = zext i32 4000000000 to i128
  %r52 = trunc i128 %r51 to i32
  store i32 %r52, ptr %r50, align 1
  br label %L12
L12:
  %r53 = add i64 0, 0
  %r54 = load ptr, ptr %v.au
  %r55 = getelementptr inbounds %zfy.seq, ptr %r54, i32 0, i32 2
  %r56 = load i64, ptr %r55
  %r57 = icmp ult i64 %r53, %r56
  br i1 %r57, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r58 = load ptr, ptr %r54
  %r59 = mul i64 %r53, 4
  %r60 = getelementptr inbounds i8, ptr %r58, i64 %r59
  %r61 = load i32, ptr %r60, align 1
  %r62 = zext i32 %r61 to i128
  br label %L15
L15:
  %r63 = trunc i128 %r62 to i32
  %r64 = zext i32 %r63 to i64
  call void @zfy_print_u64(i64 %r64)
  %t4 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t4)
  %r65 = add i64 1, 0
  %r66 = load ptr, ptr %v.au
  %r67 = getelementptr inbounds %zfy.seq, ptr %r66, i32 0, i32 2
  %r68 = load i64, ptr %r67
  %r69 = icmp ult i64 %r65, %r68
  br i1 %r69, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r70 = load ptr, ptr %r66
  %r71 = mul i64 %r65, 4
  %r72 = getelementptr inbounds i8, ptr %r70, i64 %r71
  %r73 = load i32, ptr %r72, align 1
  %r74 = zext i32 %r73 to i128
  br label %L18
L18:
  %r75 = trunc i128 %r74 to i32
  %r76 = zext i32 %r75 to i64
  call void @zfy_print_u64(i64 %r76)
  %t7 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t7)
  %r77 = add i64 2, 0
  %r78 = load ptr, ptr %v.au
  %r79 = getelementptr inbounds %zfy.seq, ptr %r78, i32 0, i32 2
  %r80 = load i64, ptr %r79
  %r81 = icmp ult i64 %r77, %r80
  br i1 %r81, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r82 = load ptr, ptr %r78
  %r83 = mul i64 %r77, 4
  %r84 = getelementptr inbounds i8, ptr %r82, i64 %r83
  %r85 = load i32, ptr %r84, align 1
  %r86 = zext i32 %r85 to i128
  br label %L21
L21:
  %r87 = trunc i128 %r86 to i32
  %r88 = zext i32 %r87 to i64
  call void @zfy_print_u64(i64 %r88)
  %r89 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r89)
  call void @zfy_free_str(ptr %t4)
  call void @zfy_free_str(ptr %t7)
  %r91 = load i32, ptr %v.a
  %r90 = zext i32 %r91 to i64
  %r92 = add i64 2, 0
  %r93 = load ptr, ptr %v.au
  %r94 = getelementptr inbounds %zfy.seq, ptr %r93, i32 0, i32 2
  %r95 = load i64, ptr %r94
  %r96 = icmp ult i64 %r92, %r95
  br i1 %r96, label %L22, label %L23
L23:
  call void @zfy_bounds_fail()
  unreachable
L22:
  %r97 = load ptr, ptr %r93
  %r98 = mul i64 %r92, 4
  %r99 = getelementptr inbounds i8, ptr %r97, i64 %r98
  %r100 = load i32, ptr %r99, align 1
  %r101 = zext i32 %r100 to i128
  br label %L24
L24:
  %r102 = trunc i128 %r101 to i32
  %r103 = zext i32 %r102 to i64
  %r104 = add i64 %r90, %r103
  call void @zfy_print_u64(i64 %r104)
  %r105 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r105)
  %r106 = load ptr, ptr %v.au
  call void @zfy_seq_free(ptr %r106, i8 0)
  store ptr null, ptr %v.au
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
