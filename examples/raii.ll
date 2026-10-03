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
@.str1 = private unnamed_addr constant [19 x i8] c"== \E5\BE\AA\E7\8E\AF\E6\BC\94\E7\A4\BA ==\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [3 x i8] c"i=\00"
@.str4 = private unnamed_addr constant [1 x i8] c"\00"
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [11 x i8] c"1+...+10 =\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [19 x i8] c"== input \E6\BC\94\E7\A4\BA ==\00"
@.str9 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str10 = private unnamed_addr constant [1 x i8] c"\00"
@.str11 = private unnamed_addr constant [1 x i8] c"\00"
@.str12 = private unnamed_addr constant [8 x i8] c"\E4\BD\A0\E5\A5\BD,\00"
@.str13 = private unnamed_addr constant [1 x i8] c"\00"
@.str14 = private unnamed_addr constant [1 x i8] c"\00"
@.str15 = private unnamed_addr constant [14 x i8] c",\E6\98\8E\E5\B9\B4\E4\BD\A0\E5\B0\B1\00"
@.str16 = private unnamed_addr constant [1 x i8] c"\00"
@.str17 = private unnamed_addr constant [1 x i8] c"\00"
@.str18 = private unnamed_addr constant [7 x i8] c"\E5\B2\81\E4\BA\86\00"
@.str19 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str20 = private unnamed_addr constant [6 x i8] c"round\00"
@.str21 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.age = alloca i64
  %v.name = alloca ptr
  %v.i$2 = alloca i64
  %v.i$1 = alloca i64
  %v.sum = alloca i64
  %v.i = alloca i64
  store i64 zeroinitializer, ptr %v.age
  store ptr null, ptr %v.name
  store i64 zeroinitializer, ptr %v.i$2
  store i64 zeroinitializer, ptr %v.i$1
  store i64 zeroinitializer, ptr %v.sum
  store i64 zeroinitializer, ptr %v.i
  %r1 = getelementptr inbounds [19 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r1)
  %r2 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r2)
  store i64 1, ptr %v.i
  br label %b1
b1:
  %r4 = load i64, ptr %v.i
  %r3 = icmp sle i64 %r4, 5
  br i1 %r3, label %b2, label %b4
b2:
  %r5 = getelementptr inbounds [3 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r5)
  %t2 = call ptr @zfy_tostr_char(i8 61)
  call void @zfy_print_str(ptr %t2)
  %r6 = load i64, ptr %v.i
  call void @zfy_print_i64(i64 %r6)
  %t3 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t3)
  call void @zfy_free_str(ptr %t2)
  call void @zfy_free_str(ptr %t3)
  br label %b3
b3:
  %r8 = load i64, ptr %v.i
  %r7 = add i64 %r8, 1
  store i64 %r7, ptr %v.i
  br label %b1
b4:
  %r9 = getelementptr inbounds [1 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r9)
  %r10 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r10)
  store i64 0, ptr %v.sum
  store i64 1, ptr %v.i$1
  br label %b5
b5:
  %r12 = load i64, ptr %v.i$1
  %r11 = icmp sle i64 %r12, 10
  br i1 %r11, label %b6, label %b8
b6:
  %r14 = load i64, ptr %v.sum
  %r15 = load i64, ptr %v.i$1
  %r13 = add i64 %r14, %r15
  store i64 %r13, ptr %v.sum
  br label %b7
b7:
  %r17 = load i64, ptr %v.i$1
  %r16 = add i64 %r17, 1
  store i64 %r16, ptr %v.i$1
  br label %b5
b8:
  %r18 = getelementptr inbounds [11 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r18)
  %t8 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t8)
  %r19 = load i64, ptr %v.sum
  call void @zfy_print_i64(i64 %r19)
  %r20 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r20)
  call void @zfy_free_str(ptr %t8)
  store i64 0, ptr %v.i$2
  br label %b9
b9:
  %r22 = load i64, ptr %v.i$2
  %r21 = icmp slt i64 %r22, 5
  br i1 %r21, label %b10, label %b12
b10:
  %r24 = load i64, ptr %v.i$2
  %r23 = icmp eq i64 %r24, 1
  br i1 %r23, label %b13, label %b14
b11:
  %r26 = load i64, ptr %v.i$2
  %r25 = add i64 %r26, 1
  store i64 %r25, ptr %v.i$2
  br label %b9
b12:
  %r27 = getelementptr inbounds [19 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r27)
  %r28 = getelementptr inbounds [2 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r28)
  %r29 = getelementptr inbounds [1 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_input_str(ptr %v.name, ptr %r29)
  %r30 = getelementptr inbounds [1 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_input_i64(ptr %v.age, ptr %r30)
  %r31 = getelementptr inbounds [8 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r31)
  %r32 = getelementptr inbounds [1 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r32)
  %r33 = load ptr, ptr %v.name
  call void @zfy_print_str(ptr %r33)
  %r34 = getelementptr inbounds [1 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r34)
  %r35 = getelementptr inbounds [14 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r35)
  %r36 = getelementptr inbounds [1 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r36)
  %r38 = load i64, ptr %v.age
  %r37 = add i64 %r38, 1
  call void @zfy_print_i64(i64 %r37)
  %r39 = getelementptr inbounds [1 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r39)
  %r40 = getelementptr inbounds [7 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_print_str(ptr %r40)
  %r41 = getelementptr inbounds [2 x i8], ptr @.str19, i64 0, i64 0
  call void @zfy_print_str(ptr %r41)
  %r42 = load ptr, ptr %v.name
  call void @zfy_free_str(ptr %r42)
  store ptr null, ptr %v.name
  ret void
b13:
  br label %b11
b14:
  br label %b15
b15:
  %r44 = load i64, ptr %v.i$2
  %r43 = icmp eq i64 %r44, 3
  br i1 %r43, label %b17, label %b18
b17:
  br label %b12
b18:
  br label %b19
b19:
  %r45 = getelementptr inbounds [6 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r45)
  %t12 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t12)
  %r46 = load i64, ptr %v.i$2
  call void @zfy_print_i64(i64 %r46)
  %r47 = getelementptr inbounds [2 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r47)
  call void @zfy_free_str(ptr %t12)
  br label %b11
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
