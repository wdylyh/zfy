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
define void @zfy.main() {
  call void @task1()
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
