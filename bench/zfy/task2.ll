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
@.str1 = private unnamed_addr constant [11 x i8] c"T2 primes=\00"
@.str2 = private unnamed_addr constant [1 x i8] c"\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [8 x i8] c" first=\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [1 x i8] c"\00"
@.str7 = private unnamed_addr constant [7 x i8] c" last=\00"
@.str8 = private unnamed_addr constant [1 x i8] c"\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @task2() {
  %v.j$2 = alloca i64
  %v.key = alloca i64
  %v.i$1 = alloca i32
  %v.k = alloca i32
  %v.state = alloca i64
  %v.arr = alloca ptr
  %v.j = alloca i64
  %v.i = alloca i64
  %v.cnt = alloca i64
  %v.comp = alloca ptr
  %v.LCG_MOD = alloca i64
  %v.LCG_C = alloca i64
  %v.LCG_A = alloca i64
  store i64 zeroinitializer, ptr %v.j$2
  store i64 zeroinitializer, ptr %v.key
  store i32 zeroinitializer, ptr %v.i$1
  store i32 zeroinitializer, ptr %v.k
  store i64 zeroinitializer, ptr %v.state
  store ptr null, ptr %v.arr
  store i64 zeroinitializer, ptr %v.j
  store i64 zeroinitializer, ptr %v.i
  store i64 zeroinitializer, ptr %v.cnt
  store ptr null, ptr %v.comp
  store i64 zeroinitializer, ptr %v.LCG_MOD
  store i64 zeroinitializer, ptr %v.LCG_C
  store i64 zeroinitializer, ptr %v.LCG_A
  store i64 1103515245, ptr %v.LCG_A
  store i64 12345, ptr %v.LCG_C
  store i64 2147483647, ptr %v.LCG_MOD
  %r1 = call ptr @zfy_seq_new(i64 100001, i64 100001, i32 1)
  store ptr %r1, ptr %v.comp
  store i64 0, ptr %v.cnt
  store i64 2, ptr %v.i
  br label %b1
b1:
  %r3 = load i64, ptr %v.i
  %r2 = icmp sle i64 %r3, 100000
  br i1 %r2, label %b2, label %b4
b2:
  %r4 = load ptr, ptr %v.comp
  %r5 = load i64, ptr %v.i
  %r6 = getelementptr inbounds %zfy.seq, ptr %r4, i32 0, i32 2
  %r7 = load i64, ptr %r6
  %r8 = icmp ult i64 %r5, %r7
  br i1 %r8, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r9 = load ptr, ptr %r4
  %r10 = mul i64 %r5, 1
  %r11 = getelementptr inbounds i8, ptr %r9, i64 %r10
  %r12 = load i8, ptr %r11, align 1
  %r13 = zext i8 %r12 to i128
  br label %L3
L3:
  %r14 = trunc i128 %r13 to i1
  %r15 = xor i1 %r14, 1
  br i1 %r15, label %b5, label %b6
b3:
  %r17 = load i64, ptr %v.i
  %r16 = add i64 %r17, 1
  store i64 %r16, ptr %v.i
  br label %b1
b4:
  %r18 = call ptr @zfy_seq_new(i64 2000, i64 2000, i32 8)
  store ptr %r18, ptr %v.arr
  store i64 42, ptr %v.state
  store i32 0, ptr %v.k
  br label %b12
b5:
  %r20 = load i64, ptr %v.cnt
  %r19 = add i64 %r20, 1
  store i64 %r19, ptr %v.cnt
  %r22 = load i64, ptr %v.i
  %r23 = load i64, ptr %v.i
  %r21 = mul i64 %r22, %r23
  store i64 %r21, ptr %v.j
  br label %b8
b6:
  br label %b7
b7:
  br label %b3
b8:
  %r25 = load i64, ptr %v.j
  %r24 = icmp sle i64 %r25, 100000
  br i1 %r24, label %b9, label %b11
b9:
  %r26 = load ptr, ptr %v.comp
  %r27 = load i64, ptr %v.j
  %r28 = getelementptr inbounds %zfy.seq, ptr %r26, i32 0, i32 2
  %r29 = load i64, ptr %r28
  %r30 = icmp ult i64 %r27, %r29
  br i1 %r30, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r31 = load ptr, ptr %r26
  %r32 = mul i64 %r27, 1
  %r33 = getelementptr inbounds i8, ptr %r31, i64 %r32
  %r34 = zext i1 1 to i128
  %r35 = trunc i128 %r34 to i8
  store i8 %r35, ptr %r33, align 1
  br label %L6
L6:
  br label %b10
b10:
  %r37 = load i64, ptr %v.j
  %r38 = load i64, ptr %v.i
  %r36 = add i64 %r37, %r38
  store i64 %r36, ptr %v.j
  br label %b8
b11:
  br label %b7
b12:
  %r40 = load i32, ptr %v.k
  %r39 = icmp slt i32 %r40, 2000
  br i1 %r39, label %b13, label %b15
b13:
  %r42 = load i64, ptr %v.state
  %r41 = mul i64 %r42, 1103515245
  %r43 = add i64 %r41, 12345
  %r44 = srem i64 %r43, 2147483647
  store i64 %r44, ptr %v.state
  %r46 = load i32, ptr %v.k
  %r45 = sext i32 %r46 to i64
  %r47 = load ptr, ptr %v.arr
  %r48 = getelementptr inbounds %zfy.seq, ptr %r47, i32 0, i32 2
  %r49 = load i64, ptr %r48
  %r50 = icmp ult i64 %r45, %r49
  br i1 %r50, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r51 = load ptr, ptr %r47
  %r52 = mul i64 %r45, 8
  %r53 = getelementptr inbounds i8, ptr %r51, i64 %r52
  %r54 = load i64, ptr %v.state
  %r55 = sext i64 %r54 to i128
  %r56 = trunc i128 %r55 to i64
  store i64 %r56, ptr %r53, align 1
  br label %L9
L9:
  br label %b14
b14:
  %r58 = load i32, ptr %v.k
  %r57 = add i32 %r58, 1
  store i32 %r57, ptr %v.k
  br label %b12
b15:
  store i32 1, ptr %v.i$1
  br label %b16
b16:
  %r60 = load i32, ptr %v.i$1
  %r59 = icmp slt i32 %r60, 2000
  br i1 %r59, label %b17, label %b19
b17:
  %r62 = load i32, ptr %v.i$1
  %r61 = sext i32 %r62 to i64
  %r63 = load ptr, ptr %v.arr
  %r64 = getelementptr inbounds %zfy.seq, ptr %r63, i32 0, i32 2
  %r65 = load i64, ptr %r64
  %r66 = icmp ult i64 %r61, %r65
  br i1 %r66, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r67 = load ptr, ptr %r63
  %r68 = mul i64 %r61, 8
  %r69 = getelementptr inbounds i8, ptr %r67, i64 %r68
  %r70 = load i64, ptr %r69, align 1
  %r71 = sext i64 %r70 to i128
  br label %L12
L12:
  %r72 = trunc i128 %r71 to i64
  store i64 %r72, ptr %v.key
  %r74 = load i32, ptr %v.i$1
  %r73 = sext i32 %r74 to i64
  %r75 = sub i64 %r73, 1
  store i64 %r75, ptr %v.j$2
  br label %b20
b18:
  %r77 = load i32, ptr %v.i$1
  %r76 = add i32 %r77, 1
  store i32 %r76, ptr %v.i$1
  br label %b16
b19:
  %r78 = getelementptr inbounds [11 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r78)
  %r79 = getelementptr inbounds [1 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r79)
  %r80 = load i64, ptr %v.cnt
  call void @zfy_print_i64(i64 %r80)
  %r81 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r81)
  %r82 = getelementptr inbounds [8 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r82)
  %r83 = getelementptr inbounds [1 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r83)
  %r84 = add i64 0, 0
  %r85 = load ptr, ptr %v.arr
  %r86 = getelementptr inbounds %zfy.seq, ptr %r85, i32 0, i32 2
  %r87 = load i64, ptr %r86
  %r88 = icmp ult i64 %r84, %r87
  br i1 %r88, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r89 = load ptr, ptr %r85
  %r90 = mul i64 %r84, 8
  %r91 = getelementptr inbounds i8, ptr %r89, i64 %r90
  %r92 = load i64, ptr %r91, align 1
  %r93 = sext i64 %r92 to i128
  br label %L15
L15:
  %r94 = trunc i128 %r93 to i64
  call void @zfy_print_i64(i64 %r94)
  %r95 = getelementptr inbounds [1 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r95)
  %r96 = getelementptr inbounds [7 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r96)
  %r97 = getelementptr inbounds [1 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r97)
  %r98 = add i64 1999, 0
  %r99 = load ptr, ptr %v.arr
  %r100 = getelementptr inbounds %zfy.seq, ptr %r99, i32 0, i32 2
  %r101 = load i64, ptr %r100
  %r102 = icmp ult i64 %r98, %r101
  br i1 %r102, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r103 = load ptr, ptr %r99
  %r104 = mul i64 %r98, 8
  %r105 = getelementptr inbounds i8, ptr %r103, i64 %r104
  %r106 = load i64, ptr %r105, align 1
  %r107 = sext i64 %r106 to i128
  br label %L18
L18:
  %r108 = trunc i128 %r107 to i64
  call void @zfy_print_i64(i64 %r108)
  %r109 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r109)
  %r110 = load ptr, ptr %v.arr
  call void @zfy_seq_free(ptr %r110, i8 0)
  store ptr null, ptr %v.arr
  %r111 = load ptr, ptr %v.comp
  call void @zfy_seq_free(ptr %r111, i8 0)
  store ptr null, ptr %v.comp
  ret void
b20:
  %r113 = load i64, ptr %v.j$2
  %r112 = icmp sge i64 %r113, 0
  br i1 %r112, label %b21, label %b22
b21:
  %r114 = load ptr, ptr %v.arr
  %r115 = load i64, ptr %v.j$2
  %r116 = getelementptr inbounds %zfy.seq, ptr %r114, i32 0, i32 2
  %r117 = load i64, ptr %r116
  %r118 = icmp ult i64 %r115, %r117
  br i1 %r118, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r119 = load ptr, ptr %r114
  %r120 = mul i64 %r115, 8
  %r121 = getelementptr inbounds i8, ptr %r119, i64 %r120
  %r122 = load i64, ptr %r121, align 1
  %r123 = sext i64 %r122 to i128
  br label %L21
L21:
  %r124 = trunc i128 %r123 to i64
  %r126 = load i64, ptr %v.key
  %r125 = icmp sgt i64 %r124, %r126
  br i1 %r125, label %b23, label %b24
b22:
  %r128 = load i64, ptr %v.j$2
  %r127 = add i64 %r128, 1
  %r129 = load ptr, ptr %v.arr
  %r130 = getelementptr inbounds %zfy.seq, ptr %r129, i32 0, i32 2
  %r131 = load i64, ptr %r130
  %r132 = icmp ult i64 %r127, %r131
  br i1 %r132, label %L22, label %L23
L23:
  call void @zfy_bounds_fail()
  unreachable
L22:
  %r133 = load ptr, ptr %r129
  %r134 = mul i64 %r127, 8
  %r135 = getelementptr inbounds i8, ptr %r133, i64 %r134
  %r136 = load i64, ptr %v.key
  %r137 = sext i64 %r136 to i128
  %r138 = trunc i128 %r137 to i64
  store i64 %r138, ptr %r135, align 1
  br label %L24
L24:
  br label %b18
b23:
  %r139 = load ptr, ptr %v.arr
  %r140 = load i64, ptr %v.j$2
  %r141 = getelementptr inbounds %zfy.seq, ptr %r139, i32 0, i32 2
  %r142 = load i64, ptr %r141
  %r143 = icmp ult i64 %r140, %r142
  br i1 %r143, label %L25, label %L26
L26:
  call void @zfy_bounds_fail()
  unreachable
L25:
  %r144 = load ptr, ptr %r139
  %r145 = mul i64 %r140, 8
  %r146 = getelementptr inbounds i8, ptr %r144, i64 %r145
  %r147 = load i64, ptr %r146, align 1
  %r148 = sext i64 %r147 to i128
  br label %L27
L27:
  %r149 = trunc i128 %r148 to i64
  %r151 = load i64, ptr %v.j$2
  %r150 = add i64 %r151, 1
  %r152 = load ptr, ptr %v.arr
  %r153 = getelementptr inbounds %zfy.seq, ptr %r152, i32 0, i32 2
  %r154 = load i64, ptr %r153
  %r155 = icmp ult i64 %r150, %r154
  br i1 %r155, label %L28, label %L29
L29:
  call void @zfy_bounds_fail()
  unreachable
L28:
  %r156 = load ptr, ptr %r152
  %r157 = mul i64 %r150, 8
  %r158 = getelementptr inbounds i8, ptr %r156, i64 %r157
  %r159 = sext i64 %r149 to i128
  %r160 = trunc i128 %r159 to i64
  store i64 %r160, ptr %r158, align 1
  br label %L30
L30:
  %r162 = load i64, ptr %v.j$2
  %r161 = sub i64 %r162, 1
  store i64 %r161, ptr %v.j$2
  br label %b25
b24:
  br label %b22
b25:
  br label %b20
}
define void @zfy.main() {
  call void @task2()
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
