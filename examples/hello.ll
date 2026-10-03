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
@.str2 = private unnamed_addr constant [1 x i8] c"\00"
@.str3 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str4 = private unnamed_addr constant [3 x i8] c"y=\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [6 x i8] c"hello\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str12 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define i32 @add(i32 %a, i32 %b) {
  %v.a = alloca i32
  store i32 %a, ptr %v.a
  %v.b = alloca i32
  store i32 %b, ptr %v.b
  %r2 = load i32, ptr %v.a
  %r3 = load i32, ptr %v.b
  %r1 = add i32 %r2, %r3
  ret i32 %r1
}
define void @zfy.main() {
  %v.acc = alloca i32
  %v.flag = alloca i1
  %v.c = alloca i8
  %v.msg = alloca ptr
  %v.j = alloca i64
  %v.i$1 = alloca i64
  %v.i = alloca i64
  %v.y = alloca i32
  %v.x = alloca i32
  %t3 = alloca i1
  %t12 = alloca i1
  store i32 zeroinitializer, ptr %v.acc
  store i1 zeroinitializer, ptr %v.flag
  store i8 zeroinitializer, ptr %v.c
  store ptr null, ptr %v.msg
  store i64 zeroinitializer, ptr %v.j
  store i64 zeroinitializer, ptr %v.i$1
  store i64 zeroinitializer, ptr %v.i
  store i32 zeroinitializer, ptr %v.y
  store i32 zeroinitializer, ptr %v.x
  store i32 42, ptr %v.x
  %t1 = call i32 @add(i32 1, i32 2)
  %r2 = load i32, ptr %v.x
  %r1 = add i32 %r2, %t1
  store i32 %r1, ptr %v.y
  store i1 zeroinitializer, ptr %t3
  %r4 = load i32, ptr %v.y
  %r3 = icmp sgt i32 %r4, 2
  br i1 %r3, label %b1, label %b2
b1:
  store i1 1, ptr %t3
  br label %b3
b2:
  store i1 0, ptr %t3
  br label %b3
b3:
  %r5 = load i1, ptr %t3
  br i1 %r5, label %b4, label %b5
b4:
  %r7 = load i32, ptr %v.y
  %r6 = sub i32 %r7, 1
  store i32 %r6, ptr %v.y
  br label %b6
b5:
  %r9 = load i32, ptr %v.y
  %r8 = add i32 %r9, 1
  store i32 %r8, ptr %v.y
  br label %b6
b6:
  br label %b7
b7:
  %r11 = load i32, ptr %v.y
  %r10 = icmp sgt i32 %r11, 0
  br i1 %r10, label %b8, label %b9
b8:
  %r13 = load i32, ptr %v.y
  %r12 = sub i32 %r13, 1
  store i32 %r12, ptr %v.y
  br label %b7
b9:
  store i64 0, ptr %v.i
  br label %b10
b10:
  %r15 = load i64, ptr %v.i
  %r14 = icmp slt i64 %r15, 3
  br i1 %r14, label %b11, label %b13
b11:
  %r16 = load i64, ptr %v.i
  call void @zfy_print_i64(i64 %r16)
  %r17 = getelementptr inbounds [2 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r17)
  br label %b12
b12:
  %r19 = load i64, ptr %v.i
  %r18 = add i64 %r19, 1
  store i64 %r18, ptr %v.i
  br label %b10
b13:
  store i64 0, ptr %v.i$1
  store i64 10, ptr %v.j
  br label %b14
b14:
  store i1 zeroinitializer, ptr %t12
  %r21 = load i64, ptr %v.i$1
  %r20 = icmp slt i64 %r21, 5
  br i1 %r20, label %b18, label %b19
b15:
  %r23 = load i64, ptr %v.i$1
  %r24 = load i64, ptr %v.j
  %r22 = add i64 %r23, %r24
  call void @zfy_print_i64(i64 %r22)
  %t16 = call ptr @zfy_tostr_char(i8 59)
  call void @zfy_print_str(ptr %t16)
  call void @zfy_free_str(ptr %t16)
  br label %b16
b16:
  %r26 = load i64, ptr %v.i$1
  %r25 = add i64 %r26, 1
  store i64 %r25, ptr %v.i$1
  %r28 = load i64, ptr %v.j
  %r27 = sub i64 %r28, 1
  store i64 %r27, ptr %v.j
  br label %b14
b17:
  %r29 = getelementptr inbounds [1 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r29)
  %r30 = getelementptr inbounds [2 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r30)
  %r31 = getelementptr inbounds [3 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r31)
  %r32 = getelementptr inbounds [1 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r32)
  %r33 = load i32, ptr %v.y
  %r34 = sext i32 %r33 to i64
  call void @zfy_print_i64(i64 %r34)
  %r35 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r35)
  %r36 = load ptr, ptr %v.msg
  call void @zfy_free_str(ptr %r36)
  %r37 = getelementptr inbounds [6 x i8], ptr @.str7, i64 0, i64 0
  %r38 = call ptr @zfy_strdup(ptr %r37)
  store ptr %r38, ptr %v.msg
  store i8 122, ptr %v.c
  %r39 = load ptr, ptr %v.msg
  call void @zfy_print_str(ptr %r39)
  %t19 = call ptr @zfy_tostr_char(i8 45)
  call void @zfy_print_str(ptr %t19)
  %r40 = load i8, ptr %v.c
  call void @zfy_print_char(i8 %r40)
  %t20 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t20)
  call void @zfy_free_str(ptr %t19)
  call void @zfy_free_str(ptr %t20)
  store i1 0, ptr %v.flag
  %r41 = load i1, ptr %v.flag
  %r42 = zext i1 %r41 to i32
  call void @zfy_print_bool(i32 %r42)
  %r43 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r43)
  store i32 10, ptr %v.acc
  %r45 = load i32, ptr %v.acc
  %r44 = add i32 %r45, 5
  store i32 %r44, ptr %v.acc
  %r47 = load i32, ptr %v.acc
  %r46 = mul i32 %r47, 2
  store i32 %r46, ptr %v.acc
  %r49 = load i32, ptr %v.acc
  %r48 = sub i32 %r49, 3
  store i32 %r48, ptr %v.acc
  %r51 = load i32, ptr %v.acc
  %r50 = sdiv i32 %r51, 2
  store i32 %r50, ptr %v.acc
  %r52 = load i32, ptr %v.acc
  %r53 = sext i32 %r52 to i64
  call void @zfy_print_i64(i64 %r53)
  %r54 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r54)
  %r56 = load i32, ptr %v.acc
  %r55 = add i32 %r56, 1
  store i32 %r55, ptr %v.acc
  %r57 = load i32, ptr %v.acc
  %r58 = sext i32 %r57 to i64
  call void @zfy_print_i64(i64 %r58)
  %r59 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r59)
  %r61 = load i32, ptr %v.acc
  %r60 = sub i32 %r61, 1
  store i32 %r60, ptr %v.acc
  %r62 = load i32, ptr %v.acc
  %r63 = sext i32 %r62 to i64
  call void @zfy_print_i64(i64 %r63)
  %r64 = getelementptr inbounds [2 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r64)
  %r65 = sitofp i64 7 to double
  %r66 = fdiv double %r65, 2.0
  call void @zfy_print_f64(double %r66)
  %t29 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t29)
  call void @zfy_free_str(ptr %t29)
  %r67 = load ptr, ptr %v.msg
  %t30 = call i64 @strlen(ptr %r67)
  call void @zfy_print_i64(i64 %t30)
  %r68 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r68)
  %r69 = load ptr, ptr %v.msg
  call void @zfy_free_str(ptr %r69)
  store ptr null, ptr %v.msg
  ret void
b18:
  %r71 = load i64, ptr %v.j
  %r70 = icmp sgt i64 %r71, 5
  store i1 %r70, ptr %t12
  br label %b20
b19:
  store i1 0, ptr %t12
  br label %b20
b20:
  %r72 = load i1, ptr %t12
  br i1 %r72, label %b15, label %b17
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
