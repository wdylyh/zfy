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
@.str1 = private unnamed_addr constant [10 x i8] c"T5 trace=\00"
@.str2 = private unnamed_addr constant [1 x i8] c"\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [7 x i8] c" hash=\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @task5() {
  %v.k$4 = alloca i32
  %v.hs = alloca i128
  %v.i$3 = alloca i32
  %v.tr = alloca double
  %v.j$2 = alloca i32
  %v.aik = alloca double
  %v.k = alloca i32
  %v.i$1 = alloca i32
  %v.j = alloca i32
  %v.i = alloca i32
  %v.c = alloca ptr
  %v.b = alloca ptr
  %v.a = alloca ptr
  %v.MOD7 = alloca i128
  %v.M2 = alloca i128
  %v.M1 = alloca i128
  %r166 = alloca i128
  store i32 zeroinitializer, ptr %v.k$4
  store i128 zeroinitializer, ptr %v.hs
  store i32 zeroinitializer, ptr %v.i$3
  store double zeroinitializer, ptr %v.tr
  store i32 zeroinitializer, ptr %v.j$2
  store double zeroinitializer, ptr %v.aik
  store i32 zeroinitializer, ptr %v.k
  store i32 zeroinitializer, ptr %v.i$1
  store i32 zeroinitializer, ptr %v.j
  store i32 zeroinitializer, ptr %v.i
  store ptr null, ptr %v.c
  store ptr null, ptr %v.b
  store ptr null, ptr %v.a
  store i128 zeroinitializer, ptr %v.MOD7
  store i128 zeroinitializer, ptr %v.M2
  store i128 zeroinitializer, ptr %v.M1
  store i128 6364136223846793005, ptr %v.M1
  store i128 1442695040888963407, ptr %v.M2
  store i128 9223372036854775807, ptr %v.MOD7
  %r1 = call ptr @zfy_seq_new(i64 65536, i64 65536, i32 8)
  store ptr %r1, ptr %v.a
  %r2 = call ptr @zfy_seq_new(i64 65536, i64 65536, i32 8)
  store ptr %r2, ptr %v.b
  %r3 = call ptr @zfy_seq_new(i64 65536, i64 65536, i32 8)
  store ptr %r3, ptr %v.c
  store i32 0, ptr %v.i
  br label %b1
b1:
  %r5 = load i32, ptr %v.i
  %r4 = icmp slt i32 %r5, 256
  br i1 %r4, label %b2, label %b4
b2:
  store i32 0, ptr %v.j
  br label %b5
b3:
  %r7 = load i32, ptr %v.i
  %r6 = add i32 %r7, 1
  store i32 %r6, ptr %v.i
  br label %b1
b4:
  store i32 0, ptr %v.i$1
  br label %b9
b5:
  %r9 = load i32, ptr %v.j
  %r8 = icmp slt i32 %r9, 256
  br i1 %r8, label %b6, label %b8
b6:
  %r11 = load i32, ptr %v.i
  %r10 = mul i32 %r11, 256
  %r13 = load i32, ptr %v.j
  %r12 = add i32 %r10, %r13
  %r14 = srem i32 %r12, 97
  %r15 = sitofp i32 %r14 to double
  %r16 = fmul double %r15, 0.5
  %r18 = load i32, ptr %v.i
  %r17 = mul i32 %r18, 256
  %r20 = load i32, ptr %v.j
  %r19 = add i32 %r17, %r20
  %r21 = sext i32 %r19 to i64
  %r22 = load ptr, ptr %v.a
  %r23 = getelementptr inbounds %zfy.seq, ptr %r22, i32 0, i32 2
  %r24 = load i64, ptr %r23
  %r25 = icmp ult i64 %r21, %r24
  br i1 %r25, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r26 = load ptr, ptr %r22
  %r27 = mul i64 %r21, 8
  %r28 = getelementptr inbounds i8, ptr %r26, i64 %r27
  %r29 = bitcast double %r16 to i64
  %r30 = zext i64 %r29 to i128
  %r31 = trunc i128 %r30 to i64
  store i64 %r31, ptr %r28, align 1
  br label %L3
L3:
  %r33 = load i32, ptr %v.i
  %r34 = load i32, ptr %v.j
  %r32 = add i32 %r33, %r34
  %r35 = srem i32 %r32, 89
  %r36 = sitofp i32 %r35 to double
  %r37 = fmul double %r36, 0.25
  %r39 = load i32, ptr %v.i
  %r38 = mul i32 %r39, 256
  %r41 = load i32, ptr %v.j
  %r40 = add i32 %r38, %r41
  %r42 = sext i32 %r40 to i64
  %r43 = load ptr, ptr %v.b
  %r44 = getelementptr inbounds %zfy.seq, ptr %r43, i32 0, i32 2
  %r45 = load i64, ptr %r44
  %r46 = icmp ult i64 %r42, %r45
  br i1 %r46, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r47 = load ptr, ptr %r43
  %r48 = mul i64 %r42, 8
  %r49 = getelementptr inbounds i8, ptr %r47, i64 %r48
  %r50 = bitcast double %r37 to i64
  %r51 = zext i64 %r50 to i128
  %r52 = trunc i128 %r51 to i64
  store i64 %r52, ptr %r49, align 1
  br label %L6
L6:
  br label %b7
b7:
  %r54 = load i32, ptr %v.j
  %r53 = add i32 %r54, 1
  store i32 %r53, ptr %v.j
  br label %b5
b8:
  br label %b3
b9:
  %r56 = load i32, ptr %v.i$1
  %r55 = icmp slt i32 %r56, 256
  br i1 %r55, label %b10, label %b12
b10:
  store i32 0, ptr %v.k
  br label %b13
b11:
  %r58 = load i32, ptr %v.i$1
  %r57 = add i32 %r58, 1
  store i32 %r57, ptr %v.i$1
  br label %b9
b12:
  store double 0.0, ptr %v.tr
  store i32 0, ptr %v.i$3
  br label %b21
b13:
  %r60 = load i32, ptr %v.k
  %r59 = icmp slt i32 %r60, 256
  br i1 %r59, label %b14, label %b16
b14:
  %r62 = load i32, ptr %v.i$1
  %r61 = mul i32 %r62, 256
  %r64 = load i32, ptr %v.k
  %r63 = add i32 %r61, %r64
  %r65 = sext i32 %r63 to i64
  %r66 = load ptr, ptr %v.a
  %r67 = getelementptr inbounds %zfy.seq, ptr %r66, i32 0, i32 2
  %r68 = load i64, ptr %r67
  %r69 = icmp ult i64 %r65, %r68
  br i1 %r69, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r70 = load ptr, ptr %r66
  %r71 = mul i64 %r65, 8
  %r72 = getelementptr inbounds i8, ptr %r70, i64 %r71
  %r73 = load i64, ptr %r72, align 1
  %r74 = zext i64 %r73 to i128
  br label %L9
L9:
  %r75 = trunc i128 %r74 to i64
  %r76 = bitcast i64 %r75 to double
  store double %r76, ptr %v.aik
  store i32 0, ptr %v.j$2
  br label %b17
b15:
  %r78 = load i32, ptr %v.k
  %r77 = add i32 %r78, 1
  store i32 %r77, ptr %v.k
  br label %b13
b16:
  br label %b11
b17:
  %r80 = load i32, ptr %v.j$2
  %r79 = icmp slt i32 %r80, 256
  br i1 %r79, label %b18, label %b20
b18:
  %r82 = load i32, ptr %v.i$1
  %r81 = mul i32 %r82, 256
  %r84 = load i32, ptr %v.j$2
  %r83 = add i32 %r81, %r84
  %r85 = sext i32 %r83 to i64
  %r86 = load ptr, ptr %v.c
  %r87 = getelementptr inbounds %zfy.seq, ptr %r86, i32 0, i32 2
  %r88 = load i64, ptr %r87
  %r89 = icmp ult i64 %r85, %r88
  br i1 %r89, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r90 = load ptr, ptr %r86
  %r91 = mul i64 %r85, 8
  %r92 = getelementptr inbounds i8, ptr %r90, i64 %r91
  %r93 = load i64, ptr %r92, align 1
  %r94 = zext i64 %r93 to i128
  br label %L12
L12:
  %r95 = trunc i128 %r94 to i64
  %r96 = bitcast i64 %r95 to double
  %r98 = load i32, ptr %v.k
  %r97 = mul i32 %r98, 256
  %r100 = load i32, ptr %v.j$2
  %r99 = add i32 %r97, %r100
  %r101 = sext i32 %r99 to i64
  %r102 = load ptr, ptr %v.b
  %r103 = getelementptr inbounds %zfy.seq, ptr %r102, i32 0, i32 2
  %r104 = load i64, ptr %r103
  %r105 = icmp ult i64 %r101, %r104
  br i1 %r105, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r106 = load ptr, ptr %r102
  %r107 = mul i64 %r101, 8
  %r108 = getelementptr inbounds i8, ptr %r106, i64 %r107
  %r109 = load i64, ptr %r108, align 1
  %r110 = zext i64 %r109 to i128
  br label %L15
L15:
  %r111 = trunc i128 %r110 to i64
  %r112 = bitcast i64 %r111 to double
  %r114 = load double, ptr %v.aik
  %r113 = fmul double %r114, %r112
  %r115 = fadd double %r96, %r113
  %r116 = load ptr, ptr %v.c
  %r117 = getelementptr inbounds %zfy.seq, ptr %r116, i32 0, i32 2
  %r118 = load i64, ptr %r117
  %r119 = icmp ult i64 %r85, %r118
  br i1 %r119, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r120 = load ptr, ptr %r116
  %r121 = mul i64 %r85, 8
  %r122 = getelementptr inbounds i8, ptr %r120, i64 %r121
  %r123 = bitcast double %r115 to i64
  %r124 = zext i64 %r123 to i128
  %r125 = trunc i128 %r124 to i64
  store i64 %r125, ptr %r122, align 1
  br label %L18
L18:
  br label %b19
b19:
  %r127 = load i32, ptr %v.j$2
  %r126 = add i32 %r127, 1
  store i32 %r126, ptr %v.j$2
  br label %b17
b20:
  br label %b15
b21:
  %r129 = load i32, ptr %v.i$3
  %r128 = icmp slt i32 %r129, 256
  br i1 %r128, label %b22, label %b24
b22:
  %r131 = load i32, ptr %v.i$3
  %r130 = mul i32 %r131, 256
  %r133 = load i32, ptr %v.i$3
  %r132 = add i32 %r130, %r133
  %r134 = sext i32 %r132 to i64
  %r135 = load ptr, ptr %v.c
  %r136 = getelementptr inbounds %zfy.seq, ptr %r135, i32 0, i32 2
  %r137 = load i64, ptr %r136
  %r138 = icmp ult i64 %r134, %r137
  br i1 %r138, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r139 = load ptr, ptr %r135
  %r140 = mul i64 %r134, 8
  %r141 = getelementptr inbounds i8, ptr %r139, i64 %r140
  %r142 = load i64, ptr %r141, align 1
  %r143 = zext i64 %r142 to i128
  br label %L21
L21:
  %r144 = trunc i128 %r143 to i64
  %r145 = bitcast i64 %r144 to double
  %r147 = load double, ptr %v.tr
  %r146 = fadd double %r147, %r145
  store double %r146, ptr %v.tr
  br label %b23
b23:
  %r149 = load i32, ptr %v.i$3
  %r148 = add i32 %r149, 1
  store i32 %r148, ptr %v.i$3
  br label %b21
b24:
  store i128 7, ptr %v.hs
  store i32 0, ptr %v.k$4
  br label %b25
b25:
  %r151 = load i32, ptr %v.k$4
  %r150 = icmp slt i32 %r151, 5000000
  br i1 %r150, label %b26, label %b28
b26:
  %r153 = load i128, ptr %v.hs
  %r152 = mul i128 %r153, 6364136223846793005
  %r154 = add i128 %r152, 1442695040888963407
  %r155 = srem i128 %r154, 9223372036854775807
  store i128 %r155, ptr %v.hs
  br label %b27
b27:
  %r157 = load i32, ptr %v.k$4
  %r156 = add i32 %r157, 1
  store i32 %r156, ptr %v.k$4
  br label %b25
b28:
  %r158 = getelementptr inbounds [10 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r158)
  %r159 = getelementptr inbounds [1 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r159)
  %r160 = load double, ptr %v.tr
  %r161 = call ptr @zfy_tostr_f64(double %r160)
  %t52 = call ptr @zfy_prec_str(ptr %r161, i64 17)
  call void @zfy_print_str(ptr %t52)
  %r162 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r162)
  %r163 = getelementptr inbounds [7 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r163)
  %r164 = getelementptr inbounds [1 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r164)
  %r165 = load i128, ptr %v.hs
  store i128 %r165, ptr %r166
  call void @zfy_print_i128(ptr %r166)
  %r167 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r167)
  call void @zfy_free_str(ptr %t52)
  %r168 = load ptr, ptr %v.c
  call void @zfy_seq_free(ptr %r168, i8 0)
  store ptr null, ptr %v.c
  %r169 = load ptr, ptr %v.b
  call void @zfy_seq_free(ptr %r169, i8 0)
  store ptr null, ptr %v.b
  %r170 = load ptr, ptr %v.a
  call void @zfy_seq_free(ptr %r170, i8 0)
  store ptr null, ptr %v.a
  ret void
}
define void @zfy.main() {
  call void @task5()
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
