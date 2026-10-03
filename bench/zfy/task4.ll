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
@.str1 = private unnamed_addr constant [8 x i8] c"T4 acc=\00"
@.str2 = private unnamed_addr constant [1 x i8] c"\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [6 x i8] c" len=\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
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
  %r71 = getelementptr inbounds [8 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r71)
  %r72 = getelementptr inbounds [1 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r72)
  %r73 = load i64, ptr %v.acc
  call void @zfy_print_i64(i64 %r73)
  %r74 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r74)
  %r75 = getelementptr inbounds [6 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r75)
  %r76 = getelementptr inbounds [1 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r76)
  %r77 = load ptr, ptr %v.base
  %r78 = getelementptr inbounds %zfy.seq, ptr %r77, i32 0, i32 2
  %r79 = load i64, ptr %r78
  call void @zfy_print_i64(i64 %r79)
  %r80 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r80)
  %r81 = load ptr, ptr %v.base
  call void @zfy_seq_free(ptr %r81, i8 0)
  store ptr null, ptr %v.base
  ret void
}
define void @zfy.main() {
  call void @task4()
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
