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
@.str1 = private unnamed_addr constant [3 x i8] c"a=\00"
@.str2 = private unnamed_addr constant [1 x i8] c"\00"
@.str3 = private unnamed_addr constant [3 x i8] c"b=\00"
@.str4 = private unnamed_addr constant [1 x i8] c"\00"
@.str5 = private unnamed_addr constant [3 x i8] c"c=\00"
@.str6 = private unnamed_addr constant [1 x i8] c"\00"
@.str7 = private unnamed_addr constant [3 x i8] c"d=\00"
@.str8 = private unnamed_addr constant [1 x i8] c"\00"
@.str9 = private unnamed_addr constant [3 x i8] c"e=\00"
@.str10 = private unnamed_addr constant [1 x i8] c"\00"
@.str11 = private unnamed_addr constant [3 x i8] c"f=\00"
@.str12 = private unnamed_addr constant [1 x i8] c"\00"
define void @zfy.globals() {
  ret void
}
define void @zfy.main() {
  %v.f = alloca i1
  %v.e2 = alloca i1
  %v.d = alloca i1
  %v.c = alloca i1
  %v.b2 = alloca i1
  %v.a = alloca i1
  %v.idx = alloca i32
  %v.i = alloca i32
  %v.arr = alloca ptr
  %t5 = alloca i1
  %t11 = alloca i1
  %t17 = alloca i1
  %t23 = alloca i1
  %t29 = alloca i1
  %t37 = alloca i1
  store i1 zeroinitializer, ptr %v.f
  store i1 zeroinitializer, ptr %v.e2
  store i1 zeroinitializer, ptr %v.d
  store i1 zeroinitializer, ptr %v.c
  store i1 zeroinitializer, ptr %v.b2
  store i1 zeroinitializer, ptr %v.a
  store i32 zeroinitializer, ptr %v.idx
  store i32 zeroinitializer, ptr %v.i
  store ptr null, ptr %v.arr
  %r1 = call ptr @zfy_seq_new(i64 5, i64 5, i32 4)
  store ptr %r1, ptr %v.arr
  store i32 0, ptr %v.i
  br label %b1
b1:
  %r3 = load i32, ptr %v.i
  %r2 = icmp slt i32 %r3, 5
  br i1 %r2, label %b2, label %b4
b2:
  %r5 = load i32, ptr %v.i
  %r4 = mul i32 %r5, 10
  %r7 = load i32, ptr %v.i
  %r6 = sext i32 %r7 to i64
  %r8 = load ptr, ptr %v.arr
  %r9 = getelementptr inbounds %zfy.seq, ptr %r8, i32 0, i32 2
  %r10 = load i64, ptr %r9
  %r11 = icmp ult i64 %r6, %r10
  br i1 %r11, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r12 = load ptr, ptr %r8
  %r13 = mul i64 %r6, 4
  %r14 = getelementptr inbounds i8, ptr %r12, i64 %r13
  %r15 = sext i32 %r4 to i128
  %r16 = trunc i128 %r15 to i32
  store i32 %r16, ptr %r14, align 1
  br label %L3
L3:
  br label %b3
b3:
  %r18 = load i32, ptr %v.i
  %r17 = add i32 %r18, 1
  store i32 %r17, ptr %v.i
  br label %b1
b4:
  store i32 7, ptr %v.idx
  store i1 zeroinitializer, ptr %t5
  %r20 = load i32, ptr %v.idx
  %r19 = icmp slt i32 %r20, 5
  br i1 %r19, label %b5, label %b6
b5:
  %r22 = load i32, ptr %v.idx
  %r21 = sext i32 %r22 to i64
  %r23 = load ptr, ptr %v.arr
  %r24 = getelementptr inbounds %zfy.seq, ptr %r23, i32 0, i32 2
  %r25 = load i64, ptr %r24
  %r26 = icmp ult i64 %r21, %r25
  br i1 %r26, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r27 = load ptr, ptr %r23
  %r28 = mul i64 %r21, 4
  %r29 = getelementptr inbounds i8, ptr %r27, i64 %r28
  %r30 = load i32, ptr %r29, align 1
  %r31 = sext i32 %r30 to i128
  br label %L6
L6:
  %r32 = trunc i128 %r31 to i32
  %r33 = icmp sgt i32 %r32, 0
  store i1 %r33, ptr %t5
  br label %b7
b6:
  store i1 0, ptr %t5
  br label %b7
b7:
  %r34 = load i1, ptr %t5
  store i1 %r34, ptr %v.a
  %r35 = getelementptr inbounds [3 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r35)
  %r36 = getelementptr inbounds [1 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r36)
  %r37 = load i1, ptr %v.a
  %r38 = zext i1 %r37 to i32
  call void @zfy_print_bool(i32 %r38)
  %t10 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t10)
  call void @zfy_free_str(ptr %t10)
  store i1 zeroinitializer, ptr %t11
  %r40 = load i32, ptr %v.idx
  %r39 = icmp sge i32 %r40, 5
  br i1 %r39, label %b9, label %b8
b8:
  %r42 = load i32, ptr %v.idx
  %r41 = sext i32 %r42 to i64
  %r43 = load ptr, ptr %v.arr
  %r44 = getelementptr inbounds %zfy.seq, ptr %r43, i32 0, i32 2
  %r45 = load i64, ptr %r44
  %r46 = icmp ult i64 %r41, %r45
  br i1 %r46, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r47 = load ptr, ptr %r43
  %r48 = mul i64 %r41, 4
  %r49 = getelementptr inbounds i8, ptr %r47, i64 %r48
  %r50 = load i32, ptr %r49, align 1
  %r51 = sext i32 %r50 to i128
  br label %L9
L9:
  %r52 = trunc i128 %r51 to i32
  %r53 = icmp sgt i32 %r52, 0
  store i1 %r53, ptr %t11
  br label %b10
b9:
  store i1 1, ptr %t11
  br label %b10
b10:
  %r54 = load i1, ptr %t11
  store i1 %r54, ptr %v.b2
  %r55 = getelementptr inbounds [3 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r55)
  %r56 = getelementptr inbounds [1 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r56)
  %r57 = load i1, ptr %v.b2
  %r58 = zext i1 %r57 to i32
  call void @zfy_print_bool(i32 %r58)
  %t16 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t16)
  call void @zfy_free_str(ptr %t16)
  store i1 zeroinitializer, ptr %t17
  %r60 = load i32, ptr %v.idx
  %r59 = icmp slt i32 %r60, 5
  br i1 %r59, label %b11, label %b12
b11:
  %r61 = add i64 2, 0
  %r62 = load ptr, ptr %v.arr
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
  %r72 = icmp eq i32 %r71, 20
  store i1 %r72, ptr %t17
  br label %b13
b12:
  store i1 0, ptr %t17
  br label %b13
b13:
  %r73 = load i1, ptr %t17
  store i1 %r73, ptr %v.c
  %r74 = getelementptr inbounds [3 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r74)
  %r75 = getelementptr inbounds [1 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r75)
  %r76 = load i1, ptr %v.c
  %r77 = zext i1 %r76 to i32
  call void @zfy_print_bool(i32 %r77)
  %t22 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t22)
  call void @zfy_free_str(ptr %t22)
  store i1 zeroinitializer, ptr %t23
  %r79 = load i32, ptr %v.idx
  %r78 = icmp sgt i32 %r79, 5
  br i1 %r78, label %b15, label %b14
b14:
  %r80 = add i64 1, 0
  %r81 = load ptr, ptr %v.arr
  %r82 = getelementptr inbounds %zfy.seq, ptr %r81, i32 0, i32 2
  %r83 = load i64, ptr %r82
  %r84 = icmp ult i64 %r80, %r83
  br i1 %r84, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r85 = load ptr, ptr %r81
  %r86 = mul i64 %r80, 4
  %r87 = getelementptr inbounds i8, ptr %r85, i64 %r86
  %r88 = load i32, ptr %r87, align 1
  %r89 = sext i32 %r88 to i128
  br label %L15
L15:
  %r90 = trunc i128 %r89 to i32
  %r91 = icmp eq i32 %r90, 10
  store i1 %r91, ptr %t23
  br label %b16
b15:
  store i1 1, ptr %t23
  br label %b16
b16:
  %r92 = load i1, ptr %t23
  store i1 %r92, ptr %v.d
  %r93 = getelementptr inbounds [3 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r93)
  %r94 = getelementptr inbounds [1 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r94)
  %r95 = load i1, ptr %v.d
  %r96 = zext i1 %r95 to i32
  call void @zfy_print_bool(i32 %r96)
  %t28 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t28)
  call void @zfy_free_str(ptr %t28)
  store i1 zeroinitializer, ptr %t29
  %r97 = add i64 2, 0
  %r98 = load ptr, ptr %v.arr
  %r99 = getelementptr inbounds %zfy.seq, ptr %r98, i32 0, i32 2
  %r100 = load i64, ptr %r99
  %r101 = icmp ult i64 %r97, %r100
  br i1 %r101, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r102 = load ptr, ptr %r98
  %r103 = mul i64 %r97, 4
  %r104 = getelementptr inbounds i8, ptr %r102, i64 %r103
  %r105 = load i32, ptr %r104, align 1
  %r106 = sext i32 %r105 to i128
  br label %L18
L18:
  %r107 = trunc i128 %r106 to i32
  %r108 = icmp eq i32 %r107, 20
  br i1 %r108, label %b17, label %b18
b17:
  %r109 = add i64 3, 0
  %r110 = load ptr, ptr %v.arr
  %r111 = getelementptr inbounds %zfy.seq, ptr %r110, i32 0, i32 2
  %r112 = load i64, ptr %r111
  %r113 = icmp ult i64 %r109, %r112
  br i1 %r113, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r114 = load ptr, ptr %r110
  %r115 = mul i64 %r109, 4
  %r116 = getelementptr inbounds i8, ptr %r114, i64 %r115
  %r117 = load i32, ptr %r116, align 1
  %r118 = sext i32 %r117 to i128
  br label %L21
L21:
  %r119 = trunc i128 %r118 to i32
  %r120 = icmp eq i32 %r119, 30
  store i1 %r120, ptr %t29
  br label %b19
b18:
  store i1 0, ptr %t29
  br label %b19
b19:
  %r121 = load i1, ptr %t29
  store i1 %r121, ptr %v.e2
  %r122 = getelementptr inbounds [3 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r122)
  %r123 = getelementptr inbounds [1 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r123)
  %r124 = load i1, ptr %v.e2
  %r125 = zext i1 %r124 to i32
  call void @zfy_print_bool(i32 %r125)
  %t36 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t36)
  call void @zfy_free_str(ptr %t36)
  store i1 zeroinitializer, ptr %t37
  %r126 = add i64 0, 0
  %r127 = load ptr, ptr %v.arr
  %r128 = getelementptr inbounds %zfy.seq, ptr %r127, i32 0, i32 2
  %r129 = load i64, ptr %r128
  %r130 = icmp ult i64 %r126, %r129
  br i1 %r130, label %L22, label %L23
L23:
  call void @zfy_bounds_fail()
  unreachable
L22:
  %r131 = load ptr, ptr %r127
  %r132 = mul i64 %r126, 4
  %r133 = getelementptr inbounds i8, ptr %r131, i64 %r132
  %r134 = load i32, ptr %r133, align 1
  %r135 = sext i32 %r134 to i128
  br label %L24
L24:
  %r136 = trunc i128 %r135 to i32
  %r137 = icmp eq i32 %r136, 99
  br i1 %r137, label %b21, label %b20
b20:
  %r138 = add i64 4, 0
  %r139 = load ptr, ptr %v.arr
  %r140 = getelementptr inbounds %zfy.seq, ptr %r139, i32 0, i32 2
  %r141 = load i64, ptr %r140
  %r142 = icmp ult i64 %r138, %r141
  br i1 %r142, label %L25, label %L26
L26:
  call void @zfy_bounds_fail()
  unreachable
L25:
  %r143 = load ptr, ptr %r139
  %r144 = mul i64 %r138, 4
  %r145 = getelementptr inbounds i8, ptr %r143, i64 %r144
  %r146 = load i32, ptr %r145, align 1
  %r147 = sext i32 %r146 to i128
  br label %L27
L27:
  %r148 = trunc i128 %r147 to i32
  %r149 = icmp eq i32 %r148, 40
  store i1 %r149, ptr %t37
  br label %b22
b21:
  store i1 1, ptr %t37
  br label %b22
b22:
  %r150 = load i1, ptr %t37
  store i1 %r150, ptr %v.f
  %r151 = getelementptr inbounds [3 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r151)
  %r152 = getelementptr inbounds [1 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r152)
  %r153 = load i1, ptr %v.f
  %r154 = zext i1 %r153 to i32
  call void @zfy_print_bool(i32 %r154)
  %t44 = call ptr @zfy_tostr_char(i8 10)
  call void @zfy_print_str(ptr %t44)
  call void @zfy_free_str(ptr %t44)
  %r155 = load ptr, ptr %v.arr
  call void @zfy_seq_free(ptr %r155, i8 0)
  store ptr null, ptr %v.arr
  ret void
}
define i32 @main() {
  call void @zfy.globals()
  call void @zfy.main()
  ret i32 0
}
