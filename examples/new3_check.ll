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
declare ptr @zfy_tostr_bool(i8)
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
declare void @zfy_input_f64(ptr, ptr, i8)
declare void @zfy_input_bool(ptr, ptr)
declare void @zfy_input_char(ptr, ptr)
declare ptr @zfy_seq_new(i64, i64, i32)
declare void @zfy_seq_set_w(ptr, i64, ptr, i32, i8)
declare void @zfy_seq_set_str(ptr, i64, ptr, i8)
declare void @zfy_seq_get(ptr, i64, ptr, i32, i8)
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
declare void @zfy_seq_aug_range(ptr, i64, i64, i64, i8, ptr, i32, i8, i8)
@.str1 = private unnamed_addr constant [1 x i8] c"\00"
@.str2 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str3 = private unnamed_addr constant [1 x i8] c"\00"
@.str4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str7 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [1 x i8] c"\00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [1 x i8] c"\00"
@.str12 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str13 = private unnamed_addr constant [1 x i8] c"\00"
@.str14 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str15 = private unnamed_addr constant [1 x i8] c"\00"
@.str16 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str17 = private unnamed_addr constant [8 x i8] c"A\09B\0BC\07D\00"
@.str18 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str19 = private unnamed_addr constant [6 x i8] c"hello\00"
@.str20 = private unnamed_addr constant [1 x i8] c"\00"
@.str21 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str22 = private unnamed_addr constant [4 x i8] c"abc\00"
@.str23 = private unnamed_addr constant [1 x i8] c"\00"
@.str24 = private unnamed_addr constant [1 x i8] c"\00"
@.str25 = private unnamed_addr constant [1 x i8] c"\00"
@.str26 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str27 = private unnamed_addr constant [1 x i8] c"\00"
@.str28 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str29 = private unnamed_addr constant [1 x i8] c"\00"
@.str30 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str31 = private unnamed_addr constant [4 x i8] c"123\00"
@.str32 = private unnamed_addr constant [4 x i8] c"xyz\00"
@.str33 = private unnamed_addr constant [1 x i8] c"\00"
@.str34 = private unnamed_addr constant [2 x i8] c"\0A\00"
define void @zfy.main() {
  %v.ib = alloca ptr
  %v.ia = alloca ptr
  %v.s2 = alloca ptr
  %v.s1 = alloca ptr
  %v.carr = alloca ptr
  %v.k = alloca i64
  %v.one = alloca ptr
  %v.s0 = alloca ptr
  %v.pos = alloca i64
  %v.pi$1 = alloca i32
  %v.pi = alloca double
  %v.sb = alloca ptr
  %v.sa = alloca ptr
  %v.m = alloca i64
  %v.lst = alloca ptr
  %v.arr = alloca ptr
  %v.c = alloca %frac.i32
  %v.ur2 = alloca %frac.i32
  %v.a = alloca %frac.i32
  %v.ur = alloca %frac.i32
  %r3 = alloca %frac.i32
  %r10 = alloca %frac.i32
  %r17 = alloca %frac.i32
  %r20 = alloca %frac.i32
  %r26 = alloca i128
  %r29 = alloca i128
  %r32 = alloca i128
  %r36 = alloca i128
  %r41 = alloca i128
  %r46 = alloca i128
  %r51 = alloca i128
  %r63 = alloca i128
  %r67 = alloca i128
  %r71 = alloca i128
  %r75 = alloca i128
  %r79 = alloca i128
  %r85 = alloca i128
  %r91 = alloca i128
  %r108 = alloca i128
  %r111 = alloca i128
  %r114 = alloca i128
  %r117 = alloca i128
  %r120 = alloca i128
  %r123 = alloca i128
  %r127 = alloca i128
  %r130 = alloca i128
  %r135 = alloca i128
  %r140 = alloca i128
  %r145 = alloca i128
  %r150 = alloca i128
  %r155 = alloca i128
  %r164 = alloca i128
  %r167 = alloca i128
  %r170 = alloca i128
  %r173 = alloca i128
  %r176 = alloca i128
  %r179 = alloca i128
  %r184 = alloca i128
  %r187 = alloca i128
  %r192 = alloca i128
  %r197 = alloca i128
  %r229 = alloca i128
  %r246 = alloca i128
  %r249 = alloca i128
  %r252 = alloca i128
  %r254 = alloca i128
  %r275 = alloca i128
  %r278 = alloca i128
  %r281 = alloca i128
  %r289 = alloca i128
  %r291 = alloca i128
  %r297 = alloca i128
  store ptr null, ptr %v.ib
  store ptr null, ptr %v.ia
  store ptr null, ptr %v.s2
  store ptr null, ptr %v.s1
  store ptr null, ptr %v.carr
  store i64 zeroinitializer, ptr %v.k
  store ptr null, ptr %v.one
  store ptr null, ptr %v.s0
  store i64 zeroinitializer, ptr %v.pos
  store i32 zeroinitializer, ptr %v.pi$1
  store double zeroinitializer, ptr %v.pi
  store ptr null, ptr %v.sb
  store ptr null, ptr %v.sa
  store i64 zeroinitializer, ptr %v.m
  store ptr null, ptr %v.lst
  store ptr null, ptr %v.arr
  store %frac.i32 zeroinitializer, ptr %v.c
  store %frac.i32 zeroinitializer, ptr %v.ur2
  store %frac.i32 zeroinitializer, ptr %v.a
  store %frac.i32 zeroinitializer, ptr %v.ur
  %r1 = trunc i64 6 to i32
  %r2 = trunc i64 48 to i32
  %r4 = getelementptr inbounds %frac.i32, ptr %r3, i32 0, i32 0
  store i32 %r1, ptr %r4
  %r5 = getelementptr inbounds %frac.i32, ptr %r3, i32 0, i32 1
  store i32 %r2, ptr %r5
  call void @llvm.memcpy.p0.p0.i64(ptr %v.ur, ptr %r3, i64 8, i1 false)
  call void @zfy_frac_print_i32(ptr %v.ur)
  %t4 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t4)
  call void @zfy_free_str(ptr %t4)
  %r6 = getelementptr inbounds [1 x i8], ptr @.str1, i64 0, i64 0
  call void @zfy_print_str(ptr %r6)
  %r7 = getelementptr inbounds [2 x i8], ptr @.str2, i64 0, i64 0
  call void @zfy_print_str(ptr %r7)
  %r8 = trunc i64 6 to i32
  %r9 = trunc i64 48 to i32
  %r11 = getelementptr inbounds %frac.i32, ptr %r10, i32 0, i32 0
  store i32 %r8, ptr %r11
  %r12 = getelementptr inbounds %frac.i32, ptr %r10, i32 0, i32 1
  store i32 %r9, ptr %r12
  call void @llvm.memcpy.p0.p0.i64(ptr %v.a, ptr %r10, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.a)
  call void @zfy_frac_print_i32(ptr %v.a)
  %t8 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t8)
  call void @zfy_free_str(ptr %t8)
  %r13 = getelementptr inbounds [1 x i8], ptr @.str3, i64 0, i64 0
  call void @zfy_print_str(ptr %r13)
  %r14 = getelementptr inbounds [2 x i8], ptr @.str4, i64 0, i64 0
  call void @zfy_print_str(ptr %r14)
  %r15 = trunc i64 2 to i32
  %r16 = trunc i64 4 to i32
  %r18 = getelementptr inbounds %frac.i32, ptr %r17, i32 0, i32 0
  store i32 %r15, ptr %r18
  %r19 = getelementptr inbounds %frac.i32, ptr %r17, i32 0, i32 1
  store i32 %r16, ptr %r19
  call void @llvm.memcpy.p0.p0.i64(ptr %v.ur2, ptr %r17, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.ur2)
  call void @zfy_frac_mul_i32(ptr %r20, ptr %v.ur, ptr %v.ur2)
  call void @llvm.memcpy.p0.p0.i64(ptr %v.c, ptr %r20, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.c)
  call void @zfy_frac_print_i32(ptr %v.c)
  %t13 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t13)
  call void @zfy_free_str(ptr %t13)
  %r21 = getelementptr inbounds [1 x i8], ptr @.str5, i64 0, i64 0
  call void @zfy_print_str(ptr %r21)
  %r22 = getelementptr inbounds [2 x i8], ptr @.str6, i64 0, i64 0
  call void @zfy_print_str(ptr %r22)
  %r23 = call ptr @zfy_seq_new(i64 5, i64 5, i32 8)
  store ptr %r23, ptr %v.arr
  %r24 = load ptr, ptr %v.arr
  %r25 = sext i64 1 to i128
  store i128 %r25, ptr %r26
  call void @zfy_seq_set_w(ptr %r24, i64 0, ptr %r26, i32 8, i8 0)
  %r27 = load ptr, ptr %v.arr
  %r28 = sext i64 2 to i128
  store i128 %r28, ptr %r29
  call void @zfy_seq_set_w(ptr %r27, i64 1, ptr %r29, i32 8, i8 0)
  %r30 = load ptr, ptr %v.arr
  %r31 = sext i64 3 to i128
  store i128 %r31, ptr %r32
  call void @zfy_seq_set_w(ptr %r30, i64 2, ptr %r32, i32 8, i8 0)
  %r33 = add i64 1, 0
  %r34 = load ptr, ptr %v.arr
  call void @zfy_seq_zero(ptr %r34, i64 %r33, i8 0)
  %r35 = add i64 0, 0
  %r37 = load ptr, ptr %v.arr
  call void @zfy_seq_get(ptr %r37, i64 %r35, ptr %r36, i32 8, i8 1)
  %r38 = load i128, ptr %r36
  %r39 = trunc i128 %r38 to i64
  call void @zfy_print_i64(i64 %r39)
  %t17 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t17)
  %r40 = add i64 1, 0
  %r42 = load ptr, ptr %v.arr
  call void @zfy_seq_get(ptr %r42, i64 %r40, ptr %r41, i32 8, i8 1)
  %r43 = load i128, ptr %r41
  %r44 = trunc i128 %r43 to i64
  call void @zfy_print_i64(i64 %r44)
  %t20 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t20)
  %r45 = add i64 2, 0
  %r47 = load ptr, ptr %v.arr
  call void @zfy_seq_get(ptr %r47, i64 %r45, ptr %r46, i32 8, i8 1)
  %r48 = load i128, ptr %r46
  %r49 = trunc i128 %r48 to i64
  call void @zfy_print_i64(i64 %r49)
  %t23 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t23)
  %r50 = add i64 4, 0
  %r52 = load ptr, ptr %v.arr
  call void @zfy_seq_get(ptr %r52, i64 %r50, ptr %r51, i32 8, i8 1)
  %r53 = load i128, ptr %r51
  %r54 = trunc i128 %r53 to i64
  call void @zfy_print_i64(i64 %r54)
  %t26 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t26)
  call void @zfy_free_str(ptr %t17)
  call void @zfy_free_str(ptr %t20)
  call void @zfy_free_str(ptr %t23)
  call void @zfy_free_str(ptr %t26)
  %r55 = load ptr, ptr %v.arr
  %r56 = getelementptr inbounds %zfy.seq, ptr %r55, i32 0, i32 2
  %r57 = load i64, ptr %r56
  call void @zfy_print_i64(i64 %r57)
  %r58 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  call void @zfy_print_str(ptr %r58)
  %r59 = call ptr @zfy_seq_new(i64 0, i64 8, i32 8)
  store ptr %r59, ptr %v.lst
  %r60 = load ptr, ptr %v.lst
  %r61 = bitcast double 1.5 to i64
  %r62 = zext i64 %r61 to i128
  store i128 %r62, ptr %r63
  call void @zfy_seq_set_w(ptr %r60, i64 0, ptr %r63, i32 8, i8 1)
  %r64 = load ptr, ptr %v.lst
  %r65 = bitcast double 2.5 to i64
  %r66 = zext i64 %r65 to i128
  store i128 %r66, ptr %r67
  call void @zfy_seq_set_w(ptr %r64, i64 1, ptr %r67, i32 8, i8 1)
  %r68 = load ptr, ptr %v.lst
  %r69 = bitcast double 3.5 to i64
  %r70 = zext i64 %r69 to i128
  store i128 %r70, ptr %r71
  call void @zfy_seq_set_w(ptr %r68, i64 2, ptr %r71, i32 8, i8 1)
  %r72 = load ptr, ptr %v.lst
  %r73 = bitcast double 4.5 to i64
  %r74 = zext i64 %r73 to i128
  store i128 %r74, ptr %r75
  call void @zfy_seq_set_w(ptr %r72, i64 3, ptr %r75, i32 8, i8 1)
  %r76 = add i64 1, 0
  %r77 = load ptr, ptr %v.lst
  call void @zfy_seq_remove(ptr %r77, i64 %r76, i8 0)
  %r78 = add i64 0, 0
  %r80 = load ptr, ptr %v.lst
  call void @zfy_seq_get(ptr %r80, i64 %r78, ptr %r79, i32 8, i8 0)
  %r81 = load i128, ptr %r79
  %r82 = trunc i128 %r81 to i64
  %r83 = bitcast i64 %r82 to double
  call void @zfy_print_f64(double %r83)
  %t31 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t31)
  %r84 = add i64 1, 0
  %r86 = load ptr, ptr %v.lst
  call void @zfy_seq_get(ptr %r86, i64 %r84, ptr %r85, i32 8, i8 0)
  %r87 = load i128, ptr %r85
  %r88 = trunc i128 %r87 to i64
  %r89 = bitcast i64 %r88 to double
  call void @zfy_print_f64(double %r89)
  %t34 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t34)
  %r90 = add i64 2, 0
  %r92 = load ptr, ptr %v.lst
  call void @zfy_seq_get(ptr %r92, i64 %r90, ptr %r91, i32 8, i8 0)
  %r93 = load i128, ptr %r91
  %r94 = trunc i128 %r93 to i64
  %r95 = bitcast i64 %r94 to double
  call void @zfy_print_f64(double %r95)
  %t37 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t37)
  call void @zfy_free_str(ptr %t31)
  call void @zfy_free_str(ptr %t34)
  call void @zfy_free_str(ptr %t37)
  %r96 = load ptr, ptr %v.lst
  %r97 = getelementptr inbounds %zfy.seq, ptr %r96, i32 0, i32 2
  %r98 = load i64, ptr %r97
  call void @zfy_print_i64(i64 %r98)
  %r99 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  call void @zfy_print_str(ptr %r99)
  store i64 17, ptr %v.m
  %r101 = load i64, ptr %v.m
  %r100 = srem i64 %r101, 5
  store i64 %r100, ptr %v.m
  %r102 = load i64, ptr %v.m
  call void @zfy_print_i64(i64 %r102)
  %t40 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t40)
  call void @zfy_free_str(ptr %t40)
  %r103 = getelementptr inbounds [1 x i8], ptr @.str9, i64 0, i64 0
  call void @zfy_print_str(ptr %r103)
  %r104 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  call void @zfy_print_str(ptr %r104)
  %r105 = call ptr @zfy_seq_new(i64 6, i64 6, i32 8)
  store ptr %r105, ptr %v.sa
  %r106 = load ptr, ptr %v.sa
  %r107 = sext i64 1 to i128
  store i128 %r107, ptr %r108
  call void @zfy_seq_set_w(ptr %r106, i64 0, ptr %r108, i32 8, i8 0)
  %r109 = load ptr, ptr %v.sa
  %r110 = sext i64 2 to i128
  store i128 %r110, ptr %r111
  call void @zfy_seq_set_w(ptr %r109, i64 1, ptr %r111, i32 8, i8 0)
  %r112 = load ptr, ptr %v.sa
  %r113 = sext i64 3 to i128
  store i128 %r113, ptr %r114
  call void @zfy_seq_set_w(ptr %r112, i64 2, ptr %r114, i32 8, i8 0)
  %r115 = load ptr, ptr %v.sa
  %r116 = sext i64 4 to i128
  store i128 %r116, ptr %r117
  call void @zfy_seq_set_w(ptr %r115, i64 3, ptr %r117, i32 8, i8 0)
  %r118 = load ptr, ptr %v.sa
  %r119 = sext i64 5 to i128
  store i128 %r119, ptr %r120
  call void @zfy_seq_set_w(ptr %r118, i64 4, ptr %r120, i32 8, i8 0)
  %r121 = load ptr, ptr %v.sa
  %r122 = sext i64 6 to i128
  store i128 %r122, ptr %r123
  call void @zfy_seq_set_w(ptr %r121, i64 5, ptr %r123, i32 8, i8 0)
  %r124 = add i64 3, 0
  %r125 = add i64 1, 0
  %r126 = load ptr, ptr %v.sa
  %r128 = zext i64 10 to i128
  store i128 %r128, ptr %r127
  call void @zfy_seq_aug_range(ptr %r126, i64 %r125, i64 %r124, i64 1, i8 0, ptr %r127, i32 8, i8 1, i8 0)
  %r129 = add i64 0, 0
  %r131 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r131, i64 %r129, ptr %r130, i32 8, i8 1)
  %r132 = load i128, ptr %r130
  %r133 = trunc i128 %r132 to i64
  call void @zfy_print_i64(i64 %r133)
  %t45 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t45)
  %r134 = add i64 1, 0
  %r136 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r136, i64 %r134, ptr %r135, i32 8, i8 1)
  %r137 = load i128, ptr %r135
  %r138 = trunc i128 %r137 to i64
  call void @zfy_print_i64(i64 %r138)
  %t48 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t48)
  %r139 = add i64 2, 0
  %r141 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r141, i64 %r139, ptr %r140, i32 8, i8 1)
  %r142 = load i128, ptr %r140
  %r143 = trunc i128 %r142 to i64
  call void @zfy_print_i64(i64 %r143)
  %t51 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t51)
  %r144 = add i64 3, 0
  %r146 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r146, i64 %r144, ptr %r145, i32 8, i8 1)
  %r147 = load i128, ptr %r145
  %r148 = trunc i128 %r147 to i64
  call void @zfy_print_i64(i64 %r148)
  %t54 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t54)
  %r149 = add i64 4, 0
  %r151 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r151, i64 %r149, ptr %r150, i32 8, i8 1)
  %r152 = load i128, ptr %r150
  %r153 = trunc i128 %r152 to i64
  call void @zfy_print_i64(i64 %r153)
  %t57 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t57)
  %r154 = add i64 5, 0
  %r156 = load ptr, ptr %v.sa
  call void @zfy_seq_get(ptr %r156, i64 %r154, ptr %r155, i32 8, i8 1)
  %r157 = load i128, ptr %r155
  %r158 = trunc i128 %r157 to i64
  call void @zfy_print_i64(i64 %r158)
  %t60 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t60)
  call void @zfy_free_str(ptr %t45)
  call void @zfy_free_str(ptr %t48)
  call void @zfy_free_str(ptr %t51)
  call void @zfy_free_str(ptr %t54)
  call void @zfy_free_str(ptr %t57)
  call void @zfy_free_str(ptr %t60)
  %r159 = getelementptr inbounds [1 x i8], ptr @.str11, i64 0, i64 0
  call void @zfy_print_str(ptr %r159)
  %r160 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  call void @zfy_print_str(ptr %r160)
  %r161 = call ptr @zfy_seq_new(i64 6, i64 6, i32 8)
  store ptr %r161, ptr %v.sb
  %r162 = load ptr, ptr %v.sb
  %r163 = sext i64 1 to i128
  store i128 %r163, ptr %r164
  call void @zfy_seq_set_w(ptr %r162, i64 0, ptr %r164, i32 8, i8 0)
  %r165 = load ptr, ptr %v.sb
  %r166 = sext i64 2 to i128
  store i128 %r166, ptr %r167
  call void @zfy_seq_set_w(ptr %r165, i64 1, ptr %r167, i32 8, i8 0)
  %r168 = load ptr, ptr %v.sb
  %r169 = sext i64 3 to i128
  store i128 %r169, ptr %r170
  call void @zfy_seq_set_w(ptr %r168, i64 2, ptr %r170, i32 8, i8 0)
  %r171 = load ptr, ptr %v.sb
  %r172 = sext i64 4 to i128
  store i128 %r172, ptr %r173
  call void @zfy_seq_set_w(ptr %r171, i64 3, ptr %r173, i32 8, i8 0)
  %r174 = load ptr, ptr %v.sb
  %r175 = sext i64 5 to i128
  store i128 %r175, ptr %r176
  call void @zfy_seq_set_w(ptr %r174, i64 4, ptr %r176, i32 8, i8 0)
  %r177 = load ptr, ptr %v.sb
  %r178 = sext i64 6 to i128
  store i128 %r178, ptr %r179
  call void @zfy_seq_set_w(ptr %r177, i64 5, ptr %r179, i32 8, i8 0)
  %r180 = add i64 2, 0
  %r181 = add i64 5, 0
  %r182 = add i64 0, 0
  %r183 = load ptr, ptr %v.sb
  %r185 = zext i64 3 to i128
  store i128 %r185, ptr %r184
  call void @zfy_seq_aug_range(ptr %r183, i64 %r182, i64 %r181, i64 %r180, i8 2, ptr %r184, i32 8, i8 1, i8 0)
  %r186 = add i64 0, 0
  %r188 = load ptr, ptr %v.sb
  call void @zfy_seq_get(ptr %r188, i64 %r186, ptr %r187, i32 8, i8 1)
  %r189 = load i128, ptr %r187
  %r190 = trunc i128 %r189 to i64
  call void @zfy_print_i64(i64 %r190)
  %t66 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t66)
  %r191 = add i64 2, 0
  %r193 = load ptr, ptr %v.sb
  call void @zfy_seq_get(ptr %r193, i64 %r191, ptr %r192, i32 8, i8 1)
  %r194 = load i128, ptr %r192
  %r195 = trunc i128 %r194 to i64
  call void @zfy_print_i64(i64 %r195)
  %t69 = call ptr @zfy_tostr_char(i8 44)
  call void @zfy_print_str(ptr %t69)
  %r196 = add i64 4, 0
  %r198 = load ptr, ptr %v.sb
  call void @zfy_seq_get(ptr %r198, i64 %r196, ptr %r197, i32 8, i8 1)
  %r199 = load i128, ptr %r197
  %r200 = trunc i128 %r199 to i64
  call void @zfy_print_i64(i64 %r200)
  %t72 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t72)
  call void @zfy_free_str(ptr %t66)
  call void @zfy_free_str(ptr %t69)
  call void @zfy_free_str(ptr %t72)
  %r201 = getelementptr inbounds [1 x i8], ptr @.str13, i64 0, i64 0
  call void @zfy_print_str(ptr %r201)
  %r202 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  call void @zfy_print_str(ptr %r202)
  store double 3.75, ptr %v.pi
  %r204 = load double, ptr %v.pi
  %r203 = fptosi double %r204 to i32
  store i32 %r203, ptr %v.pi$1
  %r205 = load i32, ptr %v.pi$1
  %r206 = sext i32 %r205 to i64
  call void @zfy_print_i64(i64 %r206)
  %t74 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t74)
  call void @zfy_free_str(ptr %t74)
  %r207 = getelementptr inbounds [1 x i8], ptr @.str15, i64 0, i64 0
  call void @zfy_print_str(ptr %r207)
  %r208 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  call void @zfy_print_str(ptr %r208)
  %r209 = getelementptr inbounds [8 x i8], ptr @.str17, i64 0, i64 0
  call void @zfy_print_str(ptr %r209)
  %r210 = getelementptr inbounds [2 x i8], ptr @.str18, i64 0, i64 0
  call void @zfy_print_str(ptr %r210)
  %r211 = add i64 2, 0
  %r212 = getelementptr inbounds [6 x i8], ptr @.str19, i64 0, i64 0
  %t76 = call i64 @zfy_str_find(ptr %r212, i8 108, i64 %r211)
  store i64 %t76, ptr %v.pos
  %r213 = load i64, ptr %v.pos
  call void @zfy_print_i64(i64 %r213)
  %t77 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t77)
  call void @zfy_free_str(ptr %t77)
  %r214 = getelementptr inbounds [1 x i8], ptr @.str20, i64 0, i64 0
  call void @zfy_print_str(ptr %r214)
  %r215 = getelementptr inbounds [2 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r215)
  %r216 = load ptr, ptr %v.s0
  call void @zfy_free_str(ptr %r216)
  %r217 = getelementptr inbounds [4 x i8], ptr @.str22, i64 0, i64 0
  %r218 = call ptr @zfy_strdup(ptr %r217)
  store ptr %r218, ptr %v.s0
  %r219 = load ptr, ptr %v.s0
  %r220 = getelementptr inbounds [1 x i8], ptr @.str23, i64 0, i64 0
  %t78 = call ptr @zfy_str_trim_str(ptr %r219, ptr %r220)
  call void @zfy_print_str(ptr %t78)
  %t79 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t79)
  call void @zfy_free_str(ptr %t78)
  call void @zfy_free_str(ptr %t79)
  %r221 = load ptr, ptr %v.one
  call void @zfy_seq_free(ptr %r221, i8 1)
  %r222 = load ptr, ptr %v.s0
  %r224 = getelementptr inbounds [1 x i8], ptr @.str24, i64 0, i64 0
  %r223 = call ptr @zfy_str_split_str(ptr %r222, ptr %r224)
  store ptr %r223, ptr %v.one
  %r225 = load ptr, ptr %v.one
  %r226 = getelementptr inbounds %zfy.seq, ptr %r225, i32 0, i32 2
  %r227 = load i64, ptr %r226
  call void @zfy_print_i64(i64 %r227)
  %t81 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t81)
  call void @zfy_free_str(ptr %t81)
  %r228 = add i64 0, 0
  %r230 = load ptr, ptr %v.one
  call void @zfy_seq_get(ptr %r230, i64 %r228, ptr %r229, i32 8, i8 0)
  %r231 = load i128, ptr %r229
  %r232 = trunc i128 %r231 to i64
  %r233 = inttoptr i64 %r232 to ptr
  call void @zfy_print_str(ptr %r233)
  %t84 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t84)
  call void @zfy_free_str(ptr %t84)
  %r234 = getelementptr inbounds [1 x i8], ptr @.str25, i64 0, i64 0
  call void @zfy_print_str(ptr %r234)
  %r235 = getelementptr inbounds [2 x i8], ptr @.str26, i64 0, i64 0
  call void @zfy_print_str(ptr %r235)
  store i64 3, ptr %v.k
  br label %b1
b1:
  %r237 = load i64, ptr %v.k
  %r236 = icmp sgt i64 %r237, 0
  br i1 %r236, label %b2, label %b4
b2:
  %r238 = load i64, ptr %v.k
  call void @zfy_print_i64(i64 %r238)
  %t86 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t86)
  call void @zfy_free_str(ptr %t86)
  br label %b3
b3:
  %r240 = load i64, ptr %v.k
  %r239 = sub i64 %r240, 1
  store i64 %r239, ptr %v.k
  br label %b1
b4:
  %r241 = getelementptr inbounds [1 x i8], ptr @.str27, i64 0, i64 0
  call void @zfy_print_str(ptr %r241)
  %r242 = getelementptr inbounds [2 x i8], ptr @.str28, i64 0, i64 0
  call void @zfy_print_str(ptr %r242)
  %r243 = call ptr @zfy_seq_new(i64 3, i64 3, i32 8)
  store ptr %r243, ptr %v.carr
  %r244 = load ptr, ptr %v.carr
  %r245 = sext i64 7 to i128
  store i128 %r245, ptr %r246
  call void @zfy_seq_set_w(ptr %r244, i64 0, ptr %r246, i32 8, i8 0)
  %r247 = load ptr, ptr %v.carr
  %r248 = sext i64 8 to i128
  store i128 %r248, ptr %r249
  call void @zfy_seq_set_w(ptr %r247, i64 1, ptr %r249, i32 8, i8 0)
  %r250 = load ptr, ptr %v.carr
  %r251 = sext i64 9 to i128
  store i128 %r251, ptr %r252
  call void @zfy_seq_set_w(ptr %r250, i64 2, ptr %r252, i32 8, i8 0)
  %r253 = add i64 2, 0
  %r255 = load ptr, ptr %v.carr
  call void @zfy_seq_get(ptr %r255, i64 %r253, ptr %r254, i32 8, i8 1)
  %r256 = load i128, ptr %r254
  %r257 = trunc i128 %r256 to i64
  call void @zfy_print_i64(i64 %r257)
  %t90 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t90)
  call void @zfy_free_str(ptr %t90)
  %r258 = getelementptr inbounds [1 x i8], ptr @.str29, i64 0, i64 0
  call void @zfy_print_str(ptr %r258)
  %r259 = getelementptr inbounds [2 x i8], ptr @.str30, i64 0, i64 0
  call void @zfy_print_str(ptr %r259)
  %r260 = load ptr, ptr %v.s1
  call void @zfy_free_str(ptr %r260)
  %r261 = getelementptr inbounds [4 x i8], ptr @.str31, i64 0, i64 0
  %r262 = call ptr @zfy_strdup(ptr %r261)
  store ptr %r262, ptr %v.s1
  %r263 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r263)
  %r264 = load ptr, ptr %v.s1
  %r265 = call ptr @zfy_strdup(ptr %r264)
  store ptr %r265, ptr %v.s2
  %r266 = load ptr, ptr %v.s2
  %r267 = getelementptr inbounds [4 x i8], ptr @.str32, i64 0, i64 0
  %t91 = call ptr @zfy_str_concat(ptr %r266, ptr %r267)
  %r268 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r268)
  %r269 = call ptr @zfy_strdup(ptr %t91)
  store ptr %r269, ptr %v.s2
  call void @zfy_free_str(ptr %t91)
  %r270 = load ptr, ptr %v.s1
  call void @zfy_print_str(ptr %r270)
  %t92 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t92)
  %r271 = load ptr, ptr %v.s2
  call void @zfy_print_str(ptr %r271)
  %t93 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t93)
  call void @zfy_free_str(ptr %t92)
  call void @zfy_free_str(ptr %t93)
  %r272 = call ptr @zfy_seq_new(i64 3, i64 3, i32 4)
  store ptr %r272, ptr %v.ia
  %r273 = load ptr, ptr %v.ia
  %r274 = sext i32 1 to i128
  store i128 %r274, ptr %r275
  call void @zfy_seq_set_w(ptr %r273, i64 0, ptr %r275, i32 4, i8 0)
  %r276 = load ptr, ptr %v.ia
  %r277 = sext i32 2 to i128
  store i128 %r277, ptr %r278
  call void @zfy_seq_set_w(ptr %r276, i64 1, ptr %r278, i32 4, i8 0)
  %r279 = load ptr, ptr %v.ia
  %r280 = sext i32 3 to i128
  store i128 %r280, ptr %r281
  call void @zfy_seq_set_w(ptr %r279, i64 2, ptr %r281, i32 4, i8 0)
  %r282 = call ptr @zfy_seq_new(i64 3, i64 3, i32 4)
  store ptr %r282, ptr %v.ib
  %r283 = load ptr, ptr %v.ib
  call void @zfy_seq_free(ptr %r283, i8 0)
  %r284 = load ptr, ptr %v.ia
  %r285 = call ptr @zfy_seq_clone(ptr %r284, i8 0)
  store ptr %r285, ptr %v.ib
  %r286 = add i64 0, 0
  %r287 = load ptr, ptr %v.ib
  %r288 = sext i32 99 to i128
  store i128 %r288, ptr %r289
  call void @zfy_seq_set_w(ptr %r287, i64 %r286, ptr %r289, i32 4, i8 0)
  %r290 = add i64 0, 0
  %r292 = load ptr, ptr %v.ia
  call void @zfy_seq_get(ptr %r292, i64 %r290, ptr %r291, i32 4, i8 1)
  %r293 = load i128, ptr %r291
  %r294 = trunc i128 %r293 to i32
  %r295 = sext i32 %r294 to i64
  call void @zfy_print_i64(i64 %r295)
  %t97 = call ptr @zfy_tostr_char(i8 124)
  call void @zfy_print_str(ptr %t97)
  %r296 = add i64 0, 0
  %r298 = load ptr, ptr %v.ib
  call void @zfy_seq_get(ptr %r298, i64 %r296, ptr %r297, i32 4, i8 1)
  %r299 = load i128, ptr %r297
  %r300 = trunc i128 %r299 to i32
  %r301 = sext i32 %r300 to i64
  call void @zfy_print_i64(i64 %r301)
  %t100 = call ptr @zfy_tostr_char(i8 32)
  call void @zfy_print_str(ptr %t100)
  call void @zfy_free_str(ptr %t97)
  call void @zfy_free_str(ptr %t100)
  %r302 = getelementptr inbounds [1 x i8], ptr @.str33, i64 0, i64 0
  call void @zfy_print_str(ptr %r302)
  %r303 = getelementptr inbounds [2 x i8], ptr @.str34, i64 0, i64 0
  call void @zfy_print_str(ptr %r303)
  %r304 = load ptr, ptr %v.ib
  call void @zfy_seq_free(ptr %r304, i8 0)
  store ptr null, ptr %v.ib
  %r305 = load ptr, ptr %v.ia
  call void @zfy_seq_free(ptr %r305, i8 0)
  store ptr null, ptr %v.ia
  %r306 = load ptr, ptr %v.s2
  call void @zfy_free_str(ptr %r306)
  store ptr null, ptr %v.s2
  %r307 = load ptr, ptr %v.s1
  call void @zfy_free_str(ptr %r307)
  store ptr null, ptr %v.s1
  %r308 = load ptr, ptr %v.carr
  call void @zfy_seq_free(ptr %r308, i8 0)
  store ptr null, ptr %v.carr
  %r309 = load ptr, ptr %v.s0
  call void @zfy_free_str(ptr %r309)
  store ptr null, ptr %v.s0
  %r310 = load ptr, ptr %v.sb
  call void @zfy_seq_free(ptr %r310, i8 0)
  store ptr null, ptr %v.sb
  %r311 = load ptr, ptr %v.sa
  call void @zfy_seq_free(ptr %r311, i8 0)
  store ptr null, ptr %v.sa
  %r312 = load ptr, ptr %v.lst
  call void @zfy_seq_free(ptr %r312, i8 0)
  store ptr null, ptr %v.lst
  %r313 = load ptr, ptr %v.arr
  call void @zfy_seq_free(ptr %r313, i8 0)
  store ptr null, ptr %v.arr
  ret void
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
