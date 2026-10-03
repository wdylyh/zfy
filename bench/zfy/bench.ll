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
@.str1 = private unnamed_addr constant [8 x i8] c"T1 sum=\00"
@.str2 = private unnamed_addr constant [1 x i8] c"\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [8 x i8] c" count=\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [11 x i8] c"T2 primes=\00"
@.str8 = private unnamed_addr constant [1 x i8] c"\00"
@.str9 = private unnamed_addr constant [1 x i8] c"\00"
@.str10 = private unnamed_addr constant [8 x i8] c" first=\00"
@.str11 = private unnamed_addr constant [1 x i8] c"\00"
@.str12 = private unnamed_addr constant [1 x i8] c"\00"
@.str13 = private unnamed_addr constant [7 x i8] c" last=\00"
@.str14 = private unnamed_addr constant [1 x i8] c"\00"
@.str15 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str16 = private unnamed_addr constant [1 x i8] c"\00"
@.str17 = private unnamed_addr constant [1 x i8] c"\00"
@.str18 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str19 = private unnamed_addr constant [8 x i8] c"T3 sum=\00"
@.str20 = private unnamed_addr constant [1 x i8] c"\00"
@.str21 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str22 = private unnamed_addr constant [8 x i8] c"T4 acc=\00"
@.str23 = private unnamed_addr constant [1 x i8] c"\00"
@.str24 = private unnamed_addr constant [1 x i8] c"\00"
@.str25 = private unnamed_addr constant [6 x i8] c" len=\00"
@.str26 = private unnamed_addr constant [1 x i8] c"\00"
@.str27 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str28 = private unnamed_addr constant [10 x i8] c"T5 trace=\00"
@.str29 = private unnamed_addr constant [1 x i8] c"\00"
@.str30 = private unnamed_addr constant [1 x i8] c"\00"
@.str31 = private unnamed_addr constant [7 x i8] c" hash=\00"
@.str32 = private unnamed_addr constant [1 x i8] c"\00"
@.str33 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @task1() {
  %v.i$2 = alloca i64
  %v.s = alloca i64
  %v.i$1 = alloca i64
  %v.evens = alloca ptr
  %v.i = alloca i32
  %v.src = alloca ptr
  %r10 = alloca i128
  %r50 = alloca i128
  store i64 zeroinitializer, ptr %v.i$2
  store i64 zeroinitializer, ptr %v.s
  store i64 zeroinitializer, ptr %v.i$1
  store ptr null, ptr %v.evens
  store i32 zeroinitializer, ptr %v.i
  store ptr null, ptr %v.src
  %r1 = call ptr @zfy_seq_new(i64 0, i64 8, i32 4)
  store ptr %r1, ptr %v.src
  store i32 0, ptr %v.i
  br label %b1
b1:
  %r3 = load i32, ptr %v.i
  %r2 = icmp slt i32 %r3, 200000
  br i1 %r2, label %b2, label %b4
b2:
  %r4 = load ptr, ptr %v.src
  %r5 = getelementptr inbounds %zfy.seq, ptr %r4, i32 0, i32 2
  %r6 = load i64, ptr %r5
  %r7 = load ptr, ptr %v.src
  %r8 = load i32, ptr %v.i
  %r9 = sext i32 %r8 to i128
  store i128 %r9, ptr %r10
  call void @zfy_seq_set_w(ptr %r7, i64 %r6, ptr %r10, i32 4, i8 1)
  br label %b3
b3:
  %r12 = load i32, ptr %v.i
  %r11 = add i32 %r12, 1
  store i32 %r11, ptr %v.i
  br label %b1
b4:
  %r13 = call ptr @zfy_seq_new(i64 0, i64 8, i32 4)
  store ptr %r13, ptr %v.evens
  store i64 0, ptr %v.i$1
  br label %b5
b5:
  %r14 = load ptr, ptr %v.src
  %r15 = getelementptr inbounds %zfy.seq, ptr %r14, i32 0, i32 2
  %r16 = load i64, ptr %r15
  %r18 = load i64, ptr %v.i$1
  %r17 = icmp slt i64 %r18, %r16
  br i1 %r17, label %b6, label %b8
b6:
  %r19 = load ptr, ptr %v.src
  %r20 = load i64, ptr %v.i$1
  %r21 = getelementptr inbounds %zfy.seq, ptr %r19, i32 0, i32 2
  %r22 = load i64, ptr %r21
  %r23 = icmp ult i64 %r20, %r22
  br i1 %r23, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r24 = load ptr, ptr %r19
  %r25 = mul i64 %r20, 4
  %r26 = getelementptr inbounds i8, ptr %r24, i64 %r25
  %r27 = load i32, ptr %r26, align 1
  %r28 = sext i32 %r27 to i128
  br label %L3
L3:
  %r29 = trunc i128 %r28 to i32
  %r30 = srem i32 %r29, 2
  %r31 = icmp eq i32 %r30, 0
  br i1 %r31, label %b9, label %b10
b7:
  %r33 = load i64, ptr %v.i$1
  %r32 = add i64 %r33, 1
  store i64 %r32, ptr %v.i$1
  br label %b5
b8:
  store i64 0, ptr %v.s
  store i64 0, ptr %v.i$2
  br label %b12
b9:
  %r34 = load ptr, ptr %v.src
  %r35 = load i64, ptr %v.i$1
  %r36 = getelementptr inbounds %zfy.seq, ptr %r34, i32 0, i32 2
  %r37 = load i64, ptr %r36
  %r38 = icmp ult i64 %r35, %r37
  br i1 %r38, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r39 = load ptr, ptr %r34
  %r40 = mul i64 %r35, 4
  %r41 = getelementptr inbounds i8, ptr %r39, i64 %r40
  %r42 = load i32, ptr %r41, align 1
  %r43 = sext i32 %r42 to i128
  br label %L6
L6:
  %r44 = trunc i128 %r43 to i32
  %r45 = load ptr, ptr %v.evens
  %r46 = getelementptr inbounds %zfy.seq, ptr %r45, i32 0, i32 2
  %r47 = load i64, ptr %r46
  %r48 = load ptr, ptr %v.evens
  %r49 = sext i32 %r44 to i128
  store i128 %r49, ptr %r50
  call void @zfy_seq_set_w(ptr %r48, i64 %r47, ptr %r50, i32 4, i8 1)
  br label %b11
b10:
  br label %b11
b11:
  br label %b7
b12:
  %r51 = load ptr, ptr %v.evens
  %r52 = getelementptr inbounds %zfy.seq, ptr %r51, i32 0, i32 2
  %r53 = load i64, ptr %r52
  %r55 = load i64, ptr %v.i$2
  %r54 = icmp slt i64 %r55, %r53
  br i1 %r54, label %b13, label %b15
b13:
  %r56 = load ptr, ptr %v.evens
  %r57 = load i64, ptr %v.i$2
  %r58 = getelementptr inbounds %zfy.seq, ptr %r56, i32 0, i32 2
  %r59 = load i64, ptr %r58
  %r60 = icmp ult i64 %r57, %r59
  br i1 %r60, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r61 = load ptr, ptr %r56
  %r62 = mul i64 %r57, 4
  %r63 = getelementptr inbounds i8, ptr %r61, i64 %r62
  %r64 = load i32, ptr %r63, align 1
  %r65 = sext i32 %r64 to i128
  br label %L9
L9:
  %r66 = trunc i128 %r65 to i32
  %r67 = sext i32 %r66 to i64
  %r69 = load i64, ptr %v.s
  %r68 = add i64 %r69, %r67
  store i64 %r68, ptr %v.s
  br label %b14
b14:
  %r71 = load i64, ptr %v.i$2
  %r70 = add i64 %r71, 1
  store i64 %r70, ptr %v.i$2
  br label %b12
b15:
  %r72 = getelementptr inbounds [8 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r72)
  %r73 = getelementptr inbounds [1 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r73)
  %r74 = load i64, ptr %v.s
  call void @zfy_print_i64(i64 %r74)
  %r75 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r75)
  %r76 = getelementptr inbounds [8 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r76)
  %r77 = getelementptr inbounds [1 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r77)
  %r78 = load ptr, ptr %v.evens
  %r79 = getelementptr inbounds %zfy.seq, ptr %r78, i32 0, i32 2
  %r80 = load i64, ptr %r79
  call void @zfy_print_i64(i64 %r80)
  %r81 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r81)
  %r82 = load ptr, ptr %v.evens
  call void @zfy_seq_free(ptr %r82, i8 0)
  store ptr null, ptr %v.evens
  %r83 = load ptr, ptr %v.src
  call void @zfy_seq_free(ptr %r83, i8 0)
  store ptr null, ptr %v.src
  ret void
}
define void @task2() {
  %v.j$4 = alloca i64
  %v.key = alloca i64
  %v.i$3 = alloca i32
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
  store i64 zeroinitializer, ptr %v.j$4
  store i64 zeroinitializer, ptr %v.key
  store i32 zeroinitializer, ptr %v.i$3
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
  store i32 1, ptr %v.i$3
  br label %b16
b16:
  %r60 = load i32, ptr %v.i$3
  %r59 = icmp slt i32 %r60, 2000
  br i1 %r59, label %b17, label %b19
b17:
  %r62 = load i32, ptr %v.i$3
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
  %r74 = load i32, ptr %v.i$3
  %r73 = sext i32 %r74 to i64
  %r75 = sub i64 %r73, 1
  store i64 %r75, ptr %v.j$4
  br label %b20
b18:
  %r77 = load i32, ptr %v.i$3
  %r76 = add i32 %r77, 1
  store i32 %r76, ptr %v.i$3
  br label %b16
b19:
  %r78 = getelementptr inbounds [11 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r78)
  %r79 = getelementptr inbounds [1 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r79)
  %r80 = load i64, ptr %v.cnt
  call void @zfy_print_i64(i64 %r80)
  %r81 = getelementptr inbounds [1 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r81)
  %r82 = getelementptr inbounds [8 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r82)
  %r83 = getelementptr inbounds [1 x i8], ptr @.str11, i64 0, i64 0
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
  %r95 = getelementptr inbounds [1 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r95)
  %r96 = getelementptr inbounds [7 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r96)
  %r97 = getelementptr inbounds [1 x i8], ptr @.str14, i64 0, i64 0
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
  %r109 = getelementptr inbounds [2 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r109)
  %r110 = load ptr, ptr %v.arr
  call void @zfy_seq_free(ptr %r110, i8 0)
  store ptr null, ptr %v.arr
  %r111 = load ptr, ptr %v.comp
  call void @zfy_seq_free(ptr %r111, i8 0)
  store ptr null, ptr %v.comp
  ret void
b20:
  %r113 = load i64, ptr %v.j$4
  %r112 = icmp sge i64 %r113, 0
  br i1 %r112, label %b21, label %b22
b21:
  %r114 = load ptr, ptr %v.arr
  %r115 = load i64, ptr %v.j$4
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
  %r128 = load i64, ptr %v.j$4
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
  %r140 = load i64, ptr %v.j$4
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
  %r151 = load i64, ptr %v.j$4
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
  %r162 = load i64, ptr %v.j$4
  %r161 = sub i64 %r162, 1
  store i64 %r161, ptr %v.j$4
  br label %b25
b24:
  br label %b22
b25:
  br label %b20
}
define void @task3() {
  %v.k = alloca i32
  %v.v = alloca i64
  %v.s = alloca i64
  %v.n = alloca i64
  store i32 zeroinitializer, ptr %v.k
  store i64 zeroinitializer, ptr %v.v
  store i64 zeroinitializer, ptr %v.s
  store i64 zeroinitializer, ptr %v.n
  store i64 0, ptr %v.n
  %r1 = getelementptr inbounds [1 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_input_i64(ptr %v.n, ptr %r1)
  store i64 0, ptr %v.s
  store i64 0, ptr %v.v
  store i32 0, ptr %v.k
  br label %b1
b1:
  %r3 = load i64, ptr %v.n
  %r2 = trunc i64 %r3 to i32
  %r5 = load i32, ptr %v.k
  %r4 = icmp slt i32 %r5, %r2
  br i1 %r4, label %b2, label %b4
b2:
  store i64 0, ptr %v.v
  %r6 = getelementptr inbounds [1 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_input_i64(ptr %v.v, ptr %r6)
  %r8 = load i64, ptr %v.v
  %r7 = mul i64 %r8, 2
  store i64 %r7, ptr %v.v
  %r10 = load i64, ptr %v.s
  %r11 = load i64, ptr %v.v
  %r9 = add i64 %r10, %r11
  store i64 %r9, ptr %v.s
  %r12 = load i64, ptr %v.v
  call void @zfy_print_i64(i64 %r12)
  %r13 = getelementptr inbounds [2 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_print_str(ptr %r13)
  br label %b3
b3:
  %r15 = load i32, ptr %v.k
  %r14 = add i32 %r15, 1
  store i32 %r14, ptr %v.k
  br label %b1
b4:
  %r16 = getelementptr inbounds [8 x i8], ptr @.str19, i64 0, i64 0
  call void @zfy_print_str(ptr %r16)
  %r17 = getelementptr inbounds [1 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r17)
  %r18 = load i64, ptr %v.s
  call void @zfy_print_i64(i64 %r18)
  %r19 = getelementptr inbounds [2 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r19)
  ret void
}
define void @task4() {
  %v.idx = alloca i64
  %v.sl = alloca ptr
  %v.cp = alloca ptr
  %v.r = alloca i32
  %v.LCG_MOD = alloca i64
  %v.acc = alloca i64
  %v.i = alloca i32
  %v.base = alloca ptr
  %r51 = alloca i128
  store i64 zeroinitializer, ptr %v.idx
  store ptr null, ptr %v.sl
  store ptr null, ptr %v.cp
  store i32 zeroinitializer, ptr %v.r
  store i64 zeroinitializer, ptr %v.LCG_MOD
  store i64 zeroinitializer, ptr %v.acc
  store i32 zeroinitializer, ptr %v.i
  store ptr null, ptr %v.base
  %r1 = call ptr @zfy_seq_new(i64 50000, i64 50000, i32 4)
  store ptr %r1, ptr %v.base
  store i32 0, ptr %v.i
  br label %b1
b1:
  %r3 = load i32, ptr %v.i
  %r2 = icmp slt i32 %r3, 50000
  br i1 %r2, label %b2, label %b4
b2:
  %r5 = load i32, ptr %v.i
  %r4 = sext i32 %r5 to i64
  %r6 = load ptr, ptr %v.base
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
  %r13 = load i32, ptr %v.i
  %r14 = sext i32 %r13 to i128
  %r15 = trunc i128 %r14 to i32
  store i32 %r15, ptr %r12, align 1
  br label %L3
L3:
  br label %b3
b3:
  %r17 = load i32, ptr %v.i
  %r16 = add i32 %r17, 1
  store i32 %r16, ptr %v.i
  br label %b1
b4:
  store i64 0, ptr %v.acc
  store i64 2147483647, ptr %v.LCG_MOD
  store i32 0, ptr %v.r
  br label %b5
b5:
  %r19 = load i32, ptr %v.r
  %r18 = icmp slt i32 %r19, 200
  br i1 %r18, label %b6, label %b8
b6:
  %r20 = load ptr, ptr %v.cp
  call void @zfy_seq_free(ptr %r20, i8 0)
  %r21 = load ptr, ptr %v.base
  %r22 = call ptr @zfy_seq_clone(ptr %r21, i8 0)
  store ptr %r22, ptr %v.cp
  %r23 = add i64 0, 0
  %r24 = add i64 49998, 0
  %r25 = add i64 2, 0
  %r26 = load ptr, ptr %v.base
  %r27 = call ptr @zfy_seq_slice(ptr %r26, i64 %r23, i64 %r24, i64 %r25, i8 0)
  %r28 = load ptr, ptr %v.sl
  call void @zfy_seq_free(ptr %r28, i8 0)
  store ptr %r27, ptr %v.sl
  %r30 = load i32, ptr %v.r
  %r29 = sext i32 %r30 to i64
  %r31 = load ptr, ptr %v.sl
  %r32 = getelementptr inbounds %zfy.seq, ptr %r31, i32 0, i32 2
  %r33 = load i64, ptr %r32
  %r34 = srem i64 %r29, %r33
  store i64 %r34, ptr %v.idx
  %r35 = load ptr, ptr %v.sl
  %r36 = load i64, ptr %v.idx
  %r37 = getelementptr inbounds %zfy.seq, ptr %r35, i32 0, i32 2
  %r38 = load i64, ptr %r37
  %r39 = icmp ult i64 %r36, %r38
  br i1 %r39, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r40 = load ptr, ptr %r35
  %r41 = mul i64 %r36, 4
  %r42 = getelementptr inbounds i8, ptr %r40, i64 %r41
  %r43 = load i32, ptr %r42, align 1
  %r44 = sext i32 %r43 to i128
  br label %L6
L6:
  %r45 = trunc i128 %r44 to i32
  %r47 = load i32, ptr %v.r
  %r46 = add i32 %r45, %r47
  %r48 = load ptr, ptr %v.sl
  %r49 = load i64, ptr %v.idx
  %r50 = sext i32 %r46 to i128
  store i128 %r50, ptr %r51
  call void @zfy_seq_set_w(ptr %r48, i64 %r49, ptr %r51, i32 4, i8 1)
  %r52 = load ptr, ptr %v.sl
  %r53 = load i64, ptr %v.idx
  %r54 = getelementptr inbounds %zfy.seq, ptr %r52, i32 0, i32 2
  %r55 = load i64, ptr %r54
  %r56 = icmp ult i64 %r53, %r55
  br i1 %r56, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r57 = load ptr, ptr %r52
  %r58 = mul i64 %r53, 4
  %r59 = getelementptr inbounds i8, ptr %r57, i64 %r58
  %r60 = load i32, ptr %r59, align 1
  %r61 = sext i32 %r60 to i128
  br label %L9
L9:
  %r62 = trunc i128 %r61 to i32
  %r63 = sext i32 %r62 to i64
  %r65 = load i64, ptr %v.acc
  %r64 = add i64 %r65, %r63
  %r66 = srem i64 %r64, 2147483647
  store i64 %r66, ptr %v.acc
  %r67 = load ptr, ptr %v.sl
  call void @zfy_seq_free(ptr %r67, i8 0)
  store ptr null, ptr %v.sl
  %r68 = load ptr, ptr %v.cp
  call void @zfy_seq_free(ptr %r68, i8 0)
  store ptr null, ptr %v.cp
  br label %b7
b7:
  %r70 = load i32, ptr %v.r
  %r69 = add i32 %r70, 1
  store i32 %r69, ptr %v.r
  br label %b5
b8:
  %r71 = getelementptr inbounds [8 x i8], ptr @.str22, i64 0, i64 0
  call void @zfy_print_str(ptr %r71)
  %r72 = getelementptr inbounds [1 x i8], ptr @.str23, i64 0, i64 0
  call void @zfy_print_str(ptr %r72)
  %r73 = load i64, ptr %v.acc
  call void @zfy_print_i64(i64 %r73)
  %r74 = getelementptr inbounds [1 x i8], ptr @.str24, i64 0, i64 0
  call void @zfy_print_str(ptr %r74)
  %r75 = getelementptr inbounds [6 x i8], ptr @.str25, i64 0, i64 0
  call void @zfy_print_str(ptr %r75)
  %r76 = getelementptr inbounds [1 x i8], ptr @.str26, i64 0, i64 0
  call void @zfy_print_str(ptr %r76)
  %r77 = load ptr, ptr %v.base
  %r78 = getelementptr inbounds %zfy.seq, ptr %r77, i32 0, i32 2
  %r79 = load i64, ptr %r78
  call void @zfy_print_i64(i64 %r79)
  %r80 = getelementptr inbounds [2 x i8], ptr @.str27, i64 0, i64 0
  call void @zfy_print_str(ptr %r80)
  %r81 = load ptr, ptr %v.base
  call void @zfy_seq_free(ptr %r81, i8 0)
  store ptr null, ptr %v.base
  ret void
}
define void @task5() {
  %v.k$8 = alloca i32
  %v.hs = alloca i128
  %v.i$7 = alloca i32
  %v.tr = alloca double
  %v.j$6 = alloca i32
  %v.aik = alloca double
  %v.k = alloca i32
  %v.i$5 = alloca i32
  %v.j = alloca i32
  %v.i = alloca i32
  %v.c = alloca ptr
  %v.b = alloca ptr
  %v.a = alloca ptr
  %v.MOD7 = alloca i128
  %v.M2 = alloca i128
  %v.M1 = alloca i128
  %r166 = alloca i128
  store i32 zeroinitializer, ptr %v.k$8
  store i128 zeroinitializer, ptr %v.hs
  store i32 zeroinitializer, ptr %v.i$7
  store double zeroinitializer, ptr %v.tr
  store i32 zeroinitializer, ptr %v.j$6
  store double zeroinitializer, ptr %v.aik
  store i32 zeroinitializer, ptr %v.k
  store i32 zeroinitializer, ptr %v.i$5
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
  store i32 0, ptr %v.i$5
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
  %r56 = load i32, ptr %v.i$5
  %r55 = icmp slt i32 %r56, 256
  br i1 %r55, label %b10, label %b12
b10:
  store i32 0, ptr %v.k
  br label %b13
b11:
  %r58 = load i32, ptr %v.i$5
  %r57 = add i32 %r58, 1
  store i32 %r57, ptr %v.i$5
  br label %b9
b12:
  store double 0.0, ptr %v.tr
  store i32 0, ptr %v.i$7
  br label %b21
b13:
  %r60 = load i32, ptr %v.k
  %r59 = icmp slt i32 %r60, 256
  br i1 %r59, label %b14, label %b16
b14:
  %r62 = load i32, ptr %v.i$5
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
  store i32 0, ptr %v.j$6
  br label %b17
b15:
  %r78 = load i32, ptr %v.k
  %r77 = add i32 %r78, 1
  store i32 %r77, ptr %v.k
  br label %b13
b16:
  br label %b11
b17:
  %r80 = load i32, ptr %v.j$6
  %r79 = icmp slt i32 %r80, 256
  br i1 %r79, label %b18, label %b20
b18:
  %r82 = load i32, ptr %v.i$5
  %r81 = mul i32 %r82, 256
  %r84 = load i32, ptr %v.j$6
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
  %r100 = load i32, ptr %v.j$6
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
  %r127 = load i32, ptr %v.j$6
  %r126 = add i32 %r127, 1
  store i32 %r126, ptr %v.j$6
  br label %b17
b20:
  br label %b15
b21:
  %r129 = load i32, ptr %v.i$7
  %r128 = icmp slt i32 %r129, 256
  br i1 %r128, label %b22, label %b24
b22:
  %r131 = load i32, ptr %v.i$7
  %r130 = mul i32 %r131, 256
  %r133 = load i32, ptr %v.i$7
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
  %r149 = load i32, ptr %v.i$7
  %r148 = add i32 %r149, 1
  store i32 %r148, ptr %v.i$7
  br label %b21
b24:
  store i128 7, ptr %v.hs
  store i32 0, ptr %v.k$8
  br label %b25
b25:
  %r151 = load i32, ptr %v.k$8
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
  %r157 = load i32, ptr %v.k$8
  %r156 = add i32 %r157, 1
  store i32 %r156, ptr %v.k$8
  br label %b25
b28:
  %r158 = getelementptr inbounds [10 x i8], ptr @.str28, i64 0, i64 0
  call void @zfy_print_str(ptr %r158)
  %r159 = getelementptr inbounds [1 x i8], ptr @.str29, i64 0, i64 0
  call void @zfy_print_str(ptr %r159)
  %r160 = load double, ptr %v.tr
  %r161 = call ptr @zfy_tostr_f64(double %r160)
  %t52 = call ptr @zfy_prec_str(ptr %r161, i64 17)
  call void @zfy_print_str(ptr %t52)
  %r162 = getelementptr inbounds [1 x i8], ptr @.str30, i64 0, i64 0
  call void @zfy_print_str(ptr %r162)
  %r163 = getelementptr inbounds [7 x i8], ptr @.str31, i64 0, i64 0
  call void @zfy_print_str(ptr %r163)
  %r164 = getelementptr inbounds [1 x i8], ptr @.str32, i64 0, i64 0
  call void @zfy_print_str(ptr %r164)
  %r165 = load i128, ptr %v.hs
  store i128 %r165, ptr %r166
  call void @zfy_print_i128(ptr %r166)
  %r167 = getelementptr inbounds [2 x i8], ptr @.str33, i64 0, i64 0
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
  call void @task1()
  call void @task2()
  call void @task3()
  call void @task4()
  call void @task5()
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
