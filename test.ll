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
@.str1 = private unnamed_addr constant [1 x i8] c"\00"
@.str2 = private unnamed_addr constant [9 x i8] c"\E5\AD\A6\E7\94\9F: \00"
@.str3 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str4 = private unnamed_addr constant [9 x i8] c"\E6\80\BB\E5\88\86: \00"
@.str5 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str6 = private unnamed_addr constant [12 x i8] c"\E5\B9\B3\E5\9D\87\E5\88\86: \00"
@.str7 = private unnamed_addr constant [2 x i8] c"/\00"
@.str8 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str9 = private unnamed_addr constant [18 x i8] c"\E6\9C\80\E9\AB\98\E5\88\86\E4\B8\8B\E6\A0\87: \00"
@.str10 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str11 = private unnamed_addr constant [15 x i8] c"  zfy-report  \00"
@.str12 = private unnamed_addr constant [2 x i8] c" \00"
@.str13 = private unnamed_addr constant [9 x i8] c"\E6\A0\87\E9\A2\98: \00"
@.str14 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str15 = private unnamed_addr constant [26 x i8] c"\E6\A0\87\E9\A2\98\E4\B8\AD '-' \E7\9A\84\E4\BD\8D\E7\BD\AE: \00"
@.str16 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str17 = private unnamed_addr constant [4 x i8] c"ZFY\00"
@.str18 = private unnamed_addr constant [12 x i8] c"\E6\9B\BF\E6\8D\A2\E5\90\8E: \00"
@.str19 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str20 = private unnamed_addr constant [1 x i8] c"\00"
@.str21 = private unnamed_addr constant [25 x i8] c"\E8\AF\B7\E8\BE\93\E5\85\A5\E5\AD\A6\E7\94\9F\E5\A7\93\E5\90\8D\EF\BC\9A\00"
@.str22 = private unnamed_addr constant [1 x i8] c"\00"
@.str23 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str24 = private unnamed_addr constant [1 x i8] c"\00"
@.str25 = private unnamed_addr constant [15 x i8] c"\E5\8F\8A\E6\A0\BC\E4\BA\BA\E6\95\B0: \00"
@.str26 = private unnamed_addr constant [1 x i8] c"\00"
@.str27 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str28 = private unnamed_addr constant [15 x i8] c"\E5\8F\8A\E6\A0\BC\E5\88\86\E6\95\B0: \00"
@.str29 = private unnamed_addr constant [1 x i8] c"\00"
@.str30 = private unnamed_addr constant [1 x i8] c"\00"
@.str31 = private unnamed_addr constant [1 x i8] c"\00"
@.str32 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str33 = private unnamed_addr constant [20 x i8] c"\E5\8F\8A\E6\A0\BC\E7\8E\87(\E5\88\86\E6\95\B0): \00"
@.str34 = private unnamed_addr constant [1 x i8] c"\00"
@.str35 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str36 = private unnamed_addr constant [10 x i8] c"hello zfy\00"
@.str37 = private unnamed_addr constant [24 x i8] c"\E7\AC\AC\E4\BA\8C\E4\B8\AA l \E7\9A\84\E4\BD\8D\E7\BD\AE: \00"
@.str38 = private unnamed_addr constant [1 x i8] c"\00"
@.str39 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str40 = private unnamed_addr constant [6 x i8] c"HELLO\00"
@.str41 = private unnamed_addr constant [12 x i8] c"\E6\9B\BF\E6\8D\A2\E5\90\8E: \00"
@.str42 = private unnamed_addr constant [1 x i8] c"\00"
@.str43 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str44 = private unnamed_addr constant [12 x i8] c"\E7\AA\84\E5\8C\96\E5\90\8E: \00"
@.str45 = private unnamed_addr constant [1 x i8] c"\00"
@.str46 = private unnamed_addr constant [1 x i8] c"\00"
@.str47 = private unnamed_addr constant [13 x i8] c" \E8\BD\AC\E6\B5\AE\E7\82\B9: \00"
@.str48 = private unnamed_addr constant [1 x i8] c"\00"
@.str49 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str50 = private unnamed_addr constant [12 x i8] c"\E7\BA\A6\E5\88\86\E5\90\8E: \00"
@.str51 = private unnamed_addr constant [1 x i8] c"\00"
@.str52 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str53 = private unnamed_addr constant [42 x i8] c"\E5\88\A0\E9\99\A4\E7\AC\AC\E4\B8\80\E4\B8\AA\E5\8F\8A\E6\A0\BC\E5\88\86\E6\95\B0\E5\90\8E\EF\BC\8C\E5\89\A9\E4\BD\99: \00"
@.str54 = private unnamed_addr constant [1 x i8] c"\00"
@.str55 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str56 = private unnamed_addr constant [12 x i8] c"\E5\80\92\E8\AE\A1\E6\97\B6: \00"
@.str57 = private unnamed_addr constant [1 x i8] c"\00"
@.str58 = private unnamed_addr constant [1 x i8] c"\00"
@.str59 = private unnamed_addr constant [1 x i8] c"\00"
@.str60 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str61 = private unnamed_addr constant [17 x i8] c"0..9 \E7\B4\AF\E5\8A\A0\E5\92\8C: \00"
@.str62 = private unnamed_addr constant [1 x i8] c"\00"
@.str63 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str64 = private unnamed_addr constant [20 x i8] c"\E7\B4\AF\E5\8A\A0\E5\92\8C\E8\B6\85\E8\BF\87 100\00"
@.str65 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str66 = private unnamed_addr constant [19 x i8] c"\E7\B4\AF\E5\8A\A0\E5\92\8C\E6\AD\A3\E5\A5\BD 45\00"
@.str67 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str68 = private unnamed_addr constant [14 x i8] c"\E7\B4\AF\E5\8A\A0\E5\92\8C\E6\98\AF \00"
@.str69 = private unnamed_addr constant [1 x i8] c"\00"
@.str70 = private unnamed_addr constant [2 x i8] c"\0A\00"
define i64 @sum_int(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e, i32 %f) {
  %v.s = alloca i64
  %v.a = alloca i32
  store i32 %a, ptr %v.a
  %v.b = alloca i32
  store i32 %b, ptr %v.b
  %v.c = alloca i32
  store i32 %c, ptr %v.c
  %v.d = alloca i32
  store i32 %d, ptr %v.d
  %v.e = alloca i32
  store i32 %e, ptr %v.e
  %v.f = alloca i32
  store i32 %f, ptr %v.f
  store i64 zeroinitializer, ptr %v.s
  store i64 0, ptr %v.s
  %r2 = load i32, ptr %v.a
  %r1 = sext i32 %r2 to i64
  %r4 = load i64, ptr %v.s
  %r3 = add i64 %r4, %r1
  store i64 %r3, ptr %v.s
  %r6 = load i32, ptr %v.b
  %r5 = sext i32 %r6 to i64
  %r8 = load i64, ptr %v.s
  %r7 = add i64 %r8, %r5
  store i64 %r7, ptr %v.s
  %r10 = load i32, ptr %v.c
  %r9 = sext i32 %r10 to i64
  %r12 = load i64, ptr %v.s
  %r11 = add i64 %r12, %r9
  store i64 %r11, ptr %v.s
  %r14 = load i32, ptr %v.d
  %r13 = sext i32 %r14 to i64
  %r16 = load i64, ptr %v.s
  %r15 = add i64 %r16, %r13
  store i64 %r15, ptr %v.s
  %r18 = load i32, ptr %v.e
  %r17 = sext i32 %r18 to i64
  %r20 = load i64, ptr %v.s
  %r19 = add i64 %r20, %r17
  store i64 %r19, ptr %v.s
  %r22 = load i32, ptr %v.f
  %r21 = sext i32 %r22 to i64
  %r24 = load i64, ptr %v.s
  %r23 = add i64 %r24, %r21
  store i64 %r23, ptr %v.s
  %r25 = load i64, ptr %v.s
  ret i64 %r25
}
define ptr @make_report(ptr %name, i64 %total, i64 %avg_num, i64 %avg_den, i64 %best) {
  %v.replaced = alloca ptr
  %v.dash_pos = alloca i64
  %v.cleaned = alloca ptr
  %v.raw = alloca ptr
  %v.line = alloca ptr
  %v.name = alloca ptr
  %r1 = call ptr @zfy_strdup(ptr %name)
  store ptr %r1, ptr %v.name
  %v.total = alloca i64
  store i64 %total, ptr %v.total
  %v.avg_num = alloca i64
  store i64 %avg_num, ptr %v.avg_num
  %v.avg_den = alloca i64
  store i64 %avg_den, ptr %v.avg_den
  %v.best = alloca i64
  store i64 %best, ptr %v.best
  store ptr null, ptr %v.replaced
  store i64 zeroinitializer, ptr %v.dash_pos
  store ptr null, ptr %v.cleaned
  store ptr null, ptr %v.raw
  store ptr null, ptr %v.line
  %r2 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r2)
  %r3 = getelementptr inbounds [1 x i8], ptr @.str1, i64 0, i64 0
  %r4 = call ptr @zfy_strdup(ptr %r3)
  store ptr %r4, ptr %v.line
  %r5 = load ptr, ptr %v.line
  %r6 = getelementptr inbounds [9 x i8], ptr @.str2, i64 0, i64 0
  %t1 = call ptr @zfy_str_concat(ptr %r5, ptr %r6)
  %r7 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r7)
  %r8 = call ptr @zfy_strdup(ptr %t1)
  store ptr %r8, ptr %v.line
  call void @zfy_free_str(ptr %t1)
  %r9 = load ptr, ptr %v.line
  %r10 = load ptr, ptr %v.name
  %t2 = call ptr @zfy_str_concat(ptr %r9, ptr %r10)
  %r11 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r11)
  %r12 = call ptr @zfy_strdup(ptr %t2)
  store ptr %r12, ptr %v.line
  call void @zfy_free_str(ptr %t2)
  %r13 = load ptr, ptr %v.line
  %r14 = getelementptr inbounds [2 x i8], ptr @.str3, i64 0, i64 0
  %t3 = call ptr @zfy_str_concat(ptr %r13, ptr %r14)
  %r15 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r15)
  %r16 = call ptr @zfy_strdup(ptr %t3)
  store ptr %r16, ptr %v.line
  call void @zfy_free_str(ptr %t3)
  %r17 = load ptr, ptr %v.line
  %r18 = getelementptr inbounds [9 x i8], ptr @.str4, i64 0, i64 0
  %t4 = call ptr @zfy_str_concat(ptr %r17, ptr %r18)
  %r19 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r19)
  %r20 = call ptr @zfy_strdup(ptr %t4)
  store ptr %r20, ptr %v.line
  call void @zfy_free_str(ptr %t4)
  %r21 = load i64, ptr %v.total
  %r22 = call ptr @zfy_tostr_i64(i64 %r21)
  %t5 = call ptr @zfy_prec_str(ptr %r22, i64 8)
  %r23 = load ptr, ptr %v.line
  %t6 = call ptr @zfy_str_concat(ptr %r23, ptr %t5)
  %r24 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r24)
  %r25 = call ptr @zfy_strdup(ptr %t6)
  store ptr %r25, ptr %v.line
  call void @zfy_free_str(ptr %t5)
  call void @zfy_free_str(ptr %t6)
  %r26 = load ptr, ptr %v.line
  %r27 = getelementptr inbounds [2 x i8], ptr @.str5, i64 0, i64 0
  %t7 = call ptr @zfy_str_concat(ptr %r26, ptr %r27)
  %r28 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r28)
  %r29 = call ptr @zfy_strdup(ptr %t7)
  store ptr %r29, ptr %v.line
  call void @zfy_free_str(ptr %t7)
  %r30 = load ptr, ptr %v.line
  %r31 = getelementptr inbounds [12 x i8], ptr @.str6, i64 0, i64 0
  %t8 = call ptr @zfy_str_concat(ptr %r30, ptr %r31)
  %r32 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r32)
  %r33 = call ptr @zfy_strdup(ptr %t8)
  store ptr %r33, ptr %v.line
  call void @zfy_free_str(ptr %t8)
  %r34 = load i64, ptr %v.avg_num
  %r35 = call ptr @zfy_tostr_i64(i64 %r34)
  %t9 = call ptr @zfy_prec_str(ptr %r35, i64 8)
  %r36 = load ptr, ptr %v.line
  %t10 = call ptr @zfy_str_concat(ptr %r36, ptr %t9)
  %r37 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r37)
  %r38 = call ptr @zfy_strdup(ptr %t10)
  store ptr %r38, ptr %v.line
  call void @zfy_free_str(ptr %t9)
  call void @zfy_free_str(ptr %t10)
  %r39 = load ptr, ptr %v.line
  %r40 = getelementptr inbounds [2 x i8], ptr @.str7, i64 0, i64 0
  %t11 = call ptr @zfy_str_concat(ptr %r39, ptr %r40)
  %r41 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r41)
  %r42 = call ptr @zfy_strdup(ptr %t11)
  store ptr %r42, ptr %v.line
  call void @zfy_free_str(ptr %t11)
  %r43 = load i64, ptr %v.avg_den
  %r44 = call ptr @zfy_tostr_i64(i64 %r43)
  %t12 = call ptr @zfy_prec_str(ptr %r44, i64 4)
  %r45 = load ptr, ptr %v.line
  %t13 = call ptr @zfy_str_concat(ptr %r45, ptr %t12)
  %r46 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r46)
  %r47 = call ptr @zfy_strdup(ptr %t13)
  store ptr %r47, ptr %v.line
  call void @zfy_free_str(ptr %t12)
  call void @zfy_free_str(ptr %t13)
  %r48 = load ptr, ptr %v.line
  %r49 = getelementptr inbounds [2 x i8], ptr @.str8, i64 0, i64 0
  %t14 = call ptr @zfy_str_concat(ptr %r48, ptr %r49)
  %r50 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r50)
  %r51 = call ptr @zfy_strdup(ptr %t14)
  store ptr %r51, ptr %v.line
  call void @zfy_free_str(ptr %t14)
  %r52 = load ptr, ptr %v.line
  %r53 = getelementptr inbounds [18 x i8], ptr @.str9, i64 0, i64 0
  %t15 = call ptr @zfy_str_concat(ptr %r52, ptr %r53)
  %r54 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r54)
  %r55 = call ptr @zfy_strdup(ptr %t15)
  store ptr %r55, ptr %v.line
  call void @zfy_free_str(ptr %t15)
  %r56 = load i64, ptr %v.best
  %r57 = call ptr @zfy_tostr_i64(i64 %r56)
  %t16 = call ptr @zfy_prec_str(ptr %r57, i64 4)
  %r58 = load ptr, ptr %v.line
  %t17 = call ptr @zfy_str_concat(ptr %r58, ptr %t16)
  %r59 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r59)
  %r60 = call ptr @zfy_strdup(ptr %t17)
  store ptr %r60, ptr %v.line
  call void @zfy_free_str(ptr %t16)
  call void @zfy_free_str(ptr %t17)
  %r61 = load ptr, ptr %v.line
  %r62 = getelementptr inbounds [2 x i8], ptr @.str10, i64 0, i64 0
  %t18 = call ptr @zfy_str_concat(ptr %r61, ptr %r62)
  %r63 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r63)
  %r64 = call ptr @zfy_strdup(ptr %t18)
  store ptr %r64, ptr %v.line
  call void @zfy_free_str(ptr %t18)
  %r65 = load ptr, ptr %v.raw
  call void @zfy_free_str(ptr %r65)
  %r66 = getelementptr inbounds [15 x i8], ptr @.str11, i64 0, i64 0
  %r67 = call ptr @zfy_strdup(ptr %r66)
  store ptr %r67, ptr %v.raw
  %r68 = load ptr, ptr %v.raw
  %r69 = getelementptr inbounds [2 x i8], ptr @.str12, i64 0, i64 0
  %t19 = call ptr @zfy_str_trim_str(ptr %r68, ptr %r69)
  %r70 = load ptr, ptr %v.cleaned
  call void @zfy_free_str(ptr %r70)
  %r71 = call ptr @zfy_strdup(ptr %t19)
  store ptr %r71, ptr %v.cleaned
  call void @zfy_free_str(ptr %t19)
  %r72 = load ptr, ptr %v.line
  %r73 = getelementptr inbounds [9 x i8], ptr @.str13, i64 0, i64 0
  %t20 = call ptr @zfy_str_concat(ptr %r72, ptr %r73)
  %r74 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r74)
  %r75 = call ptr @zfy_strdup(ptr %t20)
  store ptr %r75, ptr %v.line
  call void @zfy_free_str(ptr %t20)
  %r76 = load ptr, ptr %v.line
  %r77 = load ptr, ptr %v.cleaned
  %t21 = call ptr @zfy_str_concat(ptr %r76, ptr %r77)
  %r78 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r78)
  %r79 = call ptr @zfy_strdup(ptr %t21)
  store ptr %r79, ptr %v.line
  call void @zfy_free_str(ptr %t21)
  %r80 = load ptr, ptr %v.line
  %r81 = getelementptr inbounds [2 x i8], ptr @.str14, i64 0, i64 0
  %t22 = call ptr @zfy_str_concat(ptr %r80, ptr %r81)
  %r82 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r82)
  %r83 = call ptr @zfy_strdup(ptr %t22)
  store ptr %r83, ptr %v.line
  call void @zfy_free_str(ptr %t22)
  %r84 = load ptr, ptr %v.cleaned
  %t23 = call i64 @zfy_str_find(ptr %r84, i8 45, i64 1)
  %r85 = add i64 %t23, 0
  store i64 %r85, ptr %v.dash_pos
  %r86 = load ptr, ptr %v.line
  %r87 = getelementptr inbounds [26 x i8], ptr @.str15, i64 0, i64 0
  %t25 = call ptr @zfy_str_concat(ptr %r86, ptr %r87)
  %r88 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r88)
  %r89 = call ptr @zfy_strdup(ptr %t25)
  store ptr %r89, ptr %v.line
  call void @zfy_free_str(ptr %t25)
  %r90 = load i64, ptr %v.dash_pos
  %r91 = call ptr @zfy_tostr_i64(i64 %r90)
  %t26 = call ptr @zfy_prec_str(ptr %r91, i64 4)
  %r92 = load ptr, ptr %v.line
  %t27 = call ptr @zfy_str_concat(ptr %r92, ptr %t26)
  %r93 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r93)
  %r94 = call ptr @zfy_strdup(ptr %t27)
  store ptr %r94, ptr %v.line
  call void @zfy_free_str(ptr %t26)
  call void @zfy_free_str(ptr %t27)
  %r95 = load ptr, ptr %v.line
  %r96 = getelementptr inbounds [2 x i8], ptr @.str16, i64 0, i64 0
  %t28 = call ptr @zfy_str_concat(ptr %r95, ptr %r96)
  %r97 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r97)
  %r98 = call ptr @zfy_strdup(ptr %t28)
  store ptr %r98, ptr %v.line
  call void @zfy_free_str(ptr %t28)
  %r99 = add i64 0, 0
  %r100 = add i64 2, 0
  %r101 = load ptr, ptr %v.cleaned
  %r102 = getelementptr inbounds [4 x i8], ptr @.str17, i64 0, i64 0
  %t31 = call ptr @zfy_str_replace(ptr %r101, i64 %r99, i64 %r100, ptr %r102)
  %r103 = load ptr, ptr %v.replaced
  call void @zfy_free_str(ptr %r103)
  %r104 = call ptr @zfy_strdup(ptr %t31)
  store ptr %r104, ptr %v.replaced
  call void @zfy_free_str(ptr %t31)
  %r105 = load ptr, ptr %v.line
  %r106 = getelementptr inbounds [12 x i8], ptr @.str18, i64 0, i64 0
  %t32 = call ptr @zfy_str_concat(ptr %r105, ptr %r106)
  %r107 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r107)
  %r108 = call ptr @zfy_strdup(ptr %t32)
  store ptr %r108, ptr %v.line
  call void @zfy_free_str(ptr %t32)
  %r109 = load ptr, ptr %v.line
  %r110 = load ptr, ptr %v.replaced
  %t33 = call ptr @zfy_str_concat(ptr %r109, ptr %r110)
  %r111 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r111)
  %r112 = call ptr @zfy_strdup(ptr %t33)
  store ptr %r112, ptr %v.line
  call void @zfy_free_str(ptr %t33)
  %r113 = load ptr, ptr %v.line
  %r114 = getelementptr inbounds [2 x i8], ptr @.str19, i64 0, i64 0
  %t34 = call ptr @zfy_str_concat(ptr %r113, ptr %r114)
  %r115 = load ptr, ptr %v.line
  call void @zfy_free_str(ptr %r115)
  %r116 = call ptr @zfy_strdup(ptr %t34)
  store ptr %r116, ptr %v.line
  call void @zfy_free_str(ptr %t34)
  %r117 = load ptr, ptr %v.replaced
  call void @zfy_free_str(ptr %r117)
  store ptr null, ptr %v.replaced
  %r118 = load ptr, ptr %v.cleaned
  call void @zfy_free_str(ptr %r118)
  store ptr null, ptr %v.cleaned
  %r119 = load ptr, ptr %v.raw
  call void @zfy_free_str(ptr %r119)
  store ptr null, ptr %v.raw
  %r120 = load ptr, ptr %v.name
  call void @zfy_free_str(ptr %r120)
  store ptr null, ptr %v.name
  %r121 = load ptr, ptr %v.line
  ret ptr %r121
}
define void @zfy.main() {
  %v.acc = alloca i64
  %v.k2 = alloca i32
  %v.t = alloca i32
  %v.r = alloca %frac.i64
  %v.f = alloca float
  %v.small = alloca i32
  %v.big = alloca i64
  %v.replaced = alloca ptr
  %v.pos = alloca i64
  %v.s = alloca ptr
  %v.pass_rate = alloca %frac.i32
  %v.passed_count = alloca i32
  %v.passed = alloca ptr
  %v.report = alloca ptr
  %v.best = alloca i64
  %v.idx = alloca i32
  %v.avg_den = alloca i64
  %v.avg_num = alloca i64
  %v.avg = alloca %frac.i64
  %v.total = alloca i64
  %v.name = alloca ptr
  %v.n = alloca i32
  %v.scores = alloca ptr
  %r134 = alloca %frac.i64
  %r225 = alloca i128
  %r249 = alloca %frac.i32
  %r293 = alloca %frac.i64
  store i64 zeroinitializer, ptr %v.acc
  store i32 zeroinitializer, ptr %v.k2
  store i32 zeroinitializer, ptr %v.t
  store %frac.i64 zeroinitializer, ptr %v.r
  store float zeroinitializer, ptr %v.f
  store i32 zeroinitializer, ptr %v.small
  store i64 zeroinitializer, ptr %v.big
  store ptr null, ptr %v.replaced
  store i64 zeroinitializer, ptr %v.pos
  store ptr null, ptr %v.s
  store %frac.i32 zeroinitializer, ptr %v.pass_rate
  store i32 zeroinitializer, ptr %v.passed_count
  store ptr null, ptr %v.passed
  store ptr null, ptr %v.report
  store i64 zeroinitializer, ptr %v.best
  store i32 zeroinitializer, ptr %v.idx
  store i64 zeroinitializer, ptr %v.avg_den
  store i64 zeroinitializer, ptr %v.avg_num
  store %frac.i64 zeroinitializer, ptr %v.avg
  store i64 zeroinitializer, ptr %v.total
  store ptr null, ptr %v.name
  store i32 zeroinitializer, ptr %v.n
  store ptr null, ptr %v.scores
  %r1 = call ptr @zfy_seq_new(i64 6, i64 6, i32 4)
  store ptr %r1, ptr %v.scores
  %r2 = load ptr, ptr %v.scores
  %r3 = getelementptr inbounds %zfy.seq, ptr %r2, i32 0, i32 2
  %r4 = load i64, ptr %r3
  %r5 = icmp ult i64 0, %r4
  br i1 %r5, label %L1, label %L2
L2:
  call void @zfy_bounds_fail()
  unreachable
L1:
  %r6 = load ptr, ptr %r2
  %r7 = mul i64 0, 4
  %r8 = getelementptr inbounds i8, ptr %r6, i64 %r7
  %r9 = sext i32 88 to i128
  %r10 = trunc i128 %r9 to i32
  store i32 %r10, ptr %r8, align 1
  br label %L3
L3:
  %r11 = load ptr, ptr %v.scores
  %r12 = getelementptr inbounds %zfy.seq, ptr %r11, i32 0, i32 2
  %r13 = load i64, ptr %r12
  %r14 = icmp ult i64 1, %r13
  br i1 %r14, label %L4, label %L5
L5:
  call void @zfy_bounds_fail()
  unreachable
L4:
  %r15 = load ptr, ptr %r11
  %r16 = mul i64 1, 4
  %r17 = getelementptr inbounds i8, ptr %r15, i64 %r16
  %r18 = sext i32 92 to i128
  %r19 = trunc i128 %r18 to i32
  store i32 %r19, ptr %r17, align 1
  br label %L6
L6:
  %r20 = load ptr, ptr %v.scores
  %r21 = getelementptr inbounds %zfy.seq, ptr %r20, i32 0, i32 2
  %r22 = load i64, ptr %r21
  %r23 = icmp ult i64 2, %r22
  br i1 %r23, label %L7, label %L8
L8:
  call void @zfy_bounds_fail()
  unreachable
L7:
  %r24 = load ptr, ptr %r20
  %r25 = mul i64 2, 4
  %r26 = getelementptr inbounds i8, ptr %r24, i64 %r25
  %r27 = sext i32 79 to i128
  %r28 = trunc i128 %r27 to i32
  store i32 %r28, ptr %r26, align 1
  br label %L9
L9:
  %r29 = load ptr, ptr %v.scores
  %r30 = getelementptr inbounds %zfy.seq, ptr %r29, i32 0, i32 2
  %r31 = load i64, ptr %r30
  %r32 = icmp ult i64 3, %r31
  br i1 %r32, label %L10, label %L11
L11:
  call void @zfy_bounds_fail()
  unreachable
L10:
  %r33 = load ptr, ptr %r29
  %r34 = mul i64 3, 4
  %r35 = getelementptr inbounds i8, ptr %r33, i64 %r34
  %r36 = sext i32 95 to i128
  %r37 = trunc i128 %r36 to i32
  store i32 %r37, ptr %r35, align 1
  br label %L12
L12:
  %r38 = load ptr, ptr %v.scores
  %r39 = getelementptr inbounds %zfy.seq, ptr %r38, i32 0, i32 2
  %r40 = load i64, ptr %r39
  %r41 = icmp ult i64 4, %r40
  br i1 %r41, label %L13, label %L14
L14:
  call void @zfy_bounds_fail()
  unreachable
L13:
  %r42 = load ptr, ptr %r38
  %r43 = mul i64 4, 4
  %r44 = getelementptr inbounds i8, ptr %r42, i64 %r43
  %r45 = sext i32 67 to i128
  %r46 = trunc i128 %r45 to i32
  store i32 %r46, ptr %r44, align 1
  br label %L15
L15:
  %r47 = load ptr, ptr %v.scores
  %r48 = getelementptr inbounds %zfy.seq, ptr %r47, i32 0, i32 2
  %r49 = load i64, ptr %r48
  %r50 = icmp ult i64 5, %r49
  br i1 %r50, label %L16, label %L17
L17:
  call void @zfy_bounds_fail()
  unreachable
L16:
  %r51 = load ptr, ptr %r47
  %r52 = mul i64 5, 4
  %r53 = getelementptr inbounds i8, ptr %r51, i64 %r52
  %r54 = sext i32 84 to i128
  %r55 = trunc i128 %r54 to i32
  store i32 %r55, ptr %r53, align 1
  br label %L18
L18:
  %r56 = load ptr, ptr %v.scores
  %r57 = getelementptr inbounds %zfy.seq, ptr %r56, i32 0, i32 2
  %r58 = load i64, ptr %r57
  %r59 = trunc i64 %r58 to i32
  store i32 %r59, ptr %v.n
  %r60 = load ptr, ptr %v.name
  call void @zfy_free_str(ptr %r60)
  %r61 = getelementptr inbounds [1 x i8], ptr @.str20, i64 0, i64 0
  %r62 = call ptr @zfy_strdup(ptr %r61)
  store ptr %r62, ptr %v.name
  %r63 = getelementptr inbounds [25 x i8], ptr @.str21, i64 0, i64 0
  call void @zfy_print_str(ptr %r63)
  %r64 = getelementptr inbounds [1 x i8], ptr @.str22, i64 0, i64 0
  call void @zfy_print_str(ptr %r64)
  %r65 = getelementptr inbounds [2 x i8], ptr @.str23, i64 0, i64 0
  call void @zfy_input_str(ptr %v.name, ptr %r65)
  %r66 = add i64 0, 0
  %r67 = load ptr, ptr %v.scores
  %r68 = getelementptr inbounds %zfy.seq, ptr %r67, i32 0, i32 2
  %r69 = load i64, ptr %r68
  %r70 = icmp ult i64 %r66, %r69
  br i1 %r70, label %L19, label %L20
L20:
  call void @zfy_bounds_fail()
  unreachable
L19:
  %r71 = load ptr, ptr %r67
  %r72 = mul i64 %r66, 4
  %r73 = getelementptr inbounds i8, ptr %r71, i64 %r72
  %r74 = load i32, ptr %r73, align 1
  %r75 = sext i32 %r74 to i128
  br label %L21
L21:
  %r76 = trunc i128 %r75 to i32
  %r77 = add i64 1, 0
  %r78 = load ptr, ptr %v.scores
  %r79 = getelementptr inbounds %zfy.seq, ptr %r78, i32 0, i32 2
  %r80 = load i64, ptr %r79
  %r81 = icmp ult i64 %r77, %r80
  br i1 %r81, label %L22, label %L23
L23:
  call void @zfy_bounds_fail()
  unreachable
L22:
  %r82 = load ptr, ptr %r78
  %r83 = mul i64 %r77, 4
  %r84 = getelementptr inbounds i8, ptr %r82, i64 %r83
  %r85 = load i32, ptr %r84, align 1
  %r86 = sext i32 %r85 to i128
  br label %L24
L24:
  %r87 = trunc i128 %r86 to i32
  %r88 = add i64 2, 0
  %r89 = load ptr, ptr %v.scores
  %r90 = getelementptr inbounds %zfy.seq, ptr %r89, i32 0, i32 2
  %r91 = load i64, ptr %r90
  %r92 = icmp ult i64 %r88, %r91
  br i1 %r92, label %L25, label %L26
L26:
  call void @zfy_bounds_fail()
  unreachable
L25:
  %r93 = load ptr, ptr %r89
  %r94 = mul i64 %r88, 4
  %r95 = getelementptr inbounds i8, ptr %r93, i64 %r94
  %r96 = load i32, ptr %r95, align 1
  %r97 = sext i32 %r96 to i128
  br label %L27
L27:
  %r98 = trunc i128 %r97 to i32
  %r99 = add i64 3, 0
  %r100 = load ptr, ptr %v.scores
  %r101 = getelementptr inbounds %zfy.seq, ptr %r100, i32 0, i32 2
  %r102 = load i64, ptr %r101
  %r103 = icmp ult i64 %r99, %r102
  br i1 %r103, label %L28, label %L29
L29:
  call void @zfy_bounds_fail()
  unreachable
L28:
  %r104 = load ptr, ptr %r100
  %r105 = mul i64 %r99, 4
  %r106 = getelementptr inbounds i8, ptr %r104, i64 %r105
  %r107 = load i32, ptr %r106, align 1
  %r108 = sext i32 %r107 to i128
  br label %L30
L30:
  %r109 = trunc i128 %r108 to i32
  %r110 = add i64 4, 0
  %r111 = load ptr, ptr %v.scores
  %r112 = getelementptr inbounds %zfy.seq, ptr %r111, i32 0, i32 2
  %r113 = load i64, ptr %r112
  %r114 = icmp ult i64 %r110, %r113
  br i1 %r114, label %L31, label %L32
L32:
  call void @zfy_bounds_fail()
  unreachable
L31:
  %r115 = load ptr, ptr %r111
  %r116 = mul i64 %r110, 4
  %r117 = getelementptr inbounds i8, ptr %r115, i64 %r116
  %r118 = load i32, ptr %r117, align 1
  %r119 = sext i32 %r118 to i128
  br label %L33
L33:
  %r120 = trunc i128 %r119 to i32
  %r121 = add i64 5, 0
  %r122 = load ptr, ptr %v.scores
  %r123 = getelementptr inbounds %zfy.seq, ptr %r122, i32 0, i32 2
  %r124 = load i64, ptr %r123
  %r125 = icmp ult i64 %r121, %r124
  br i1 %r125, label %L34, label %L35
L35:
  call void @zfy_bounds_fail()
  unreachable
L34:
  %r126 = load ptr, ptr %r122
  %r127 = mul i64 %r121, 4
  %r128 = getelementptr inbounds i8, ptr %r126, i64 %r127
  %r129 = load i32, ptr %r128, align 1
  %r130 = sext i32 %r129 to i128
  br label %L36
L36:
  %r131 = trunc i128 %r130 to i32
  %t15 = call i64 @sum_int(i32 %r76, i32 %r87, i32 %r98, i32 %r109, i32 %r120, i32 %r131)
  store i64 %t15, ptr %v.total
  %r133 = load i32, ptr %v.n
  %r132 = sext i32 %r133 to i64
  %r135 = getelementptr inbounds %frac.i64, ptr %r134, i32 0, i32 0
  %r136 = load i64, ptr %v.total
  store i64 %r136, ptr %r135
  %r137 = getelementptr inbounds %frac.i64, ptr %r134, i32 0, i32 1
  store i64 %r132, ptr %r137
  call void @llvm.memcpy.p0.p0.i64(ptr %v.avg, ptr %r134, i64 16, i1 false)
  call void @zfy_frac_norm_i64(ptr %v.avg)
  store i64 0, ptr %v.avg_num
  store i64 1, ptr %v.avg_den
  store i32 0, ptr %v.idx
  store i64 0, ptr %v.best
  br label %b1
b1:
  %r139 = load i32, ptr %v.idx
  %r140 = load i32, ptr %v.n
  %r138 = icmp slt i32 %r139, %r140
  br i1 %r138, label %b2, label %b3
b2:
  %r142 = load i32, ptr %v.idx
  %r141 = sext i32 %r142 to i64
  %r143 = load ptr, ptr %v.scores
  %r144 = getelementptr inbounds %zfy.seq, ptr %r143, i32 0, i32 2
  %r145 = load i64, ptr %r144
  %r146 = icmp ult i64 %r141, %r145
  br i1 %r146, label %L37, label %L38
L38:
  call void @zfy_bounds_fail()
  unreachable
L37:
  %r147 = load ptr, ptr %r143
  %r148 = mul i64 %r141, 4
  %r149 = getelementptr inbounds i8, ptr %r147, i64 %r148
  %r150 = load i32, ptr %r149, align 1
  %r151 = sext i32 %r150 to i128
  br label %L39
L39:
  %r152 = trunc i128 %r151 to i32
  %r154 = load i64, ptr %v.best
  %r153 = trunc i64 %r154 to i32
  %r155 = sext i32 %r153 to i64
  %r156 = load ptr, ptr %v.scores
  %r157 = getelementptr inbounds %zfy.seq, ptr %r156, i32 0, i32 2
  %r158 = load i64, ptr %r157
  %r159 = icmp ult i64 %r155, %r158
  br i1 %r159, label %L40, label %L41
L41:
  call void @zfy_bounds_fail()
  unreachable
L40:
  %r160 = load ptr, ptr %r156
  %r161 = mul i64 %r155, 4
  %r162 = getelementptr inbounds i8, ptr %r160, i64 %r161
  %r163 = load i32, ptr %r162, align 1
  %r164 = sext i32 %r163 to i128
  br label %L42
L42:
  %r165 = trunc i128 %r164 to i32
  %r166 = icmp sgt i32 %r152, %r165
  br i1 %r166, label %b4, label %b5
b3:
  %r167 = load ptr, ptr %v.name
  %r168 = load i64, ptr %v.total
  %r169 = load i64, ptr %v.avg_num
  %r170 = load i64, ptr %v.avg_den
  %r171 = load i64, ptr %v.best
  %t27 = call ptr @make_report(ptr %r167, i64 %r168, i64 %r169, i64 %r170, i64 %r171)
  %r172 = load ptr, ptr %v.report
  call void @zfy_free_str(ptr %r172)
  %r173 = call ptr @zfy_strdup(ptr %t27)
  store ptr %r173, ptr %v.report
  call void @zfy_free_str(ptr %t27)
  %r174 = load ptr, ptr %v.report
  call void @zfy_print_str(ptr %r174)
  %r175 = getelementptr inbounds [1 x i8], ptr @.str24, i64 0, i64 0
  call void @zfy_print_str(ptr %r175)
  %r176 = call ptr @zfy_seq_new(i64 0, i64 8, i32 4)
  store ptr %r176, ptr %v.passed
  store i32 0, ptr %v.idx
  br label %b7
b4:
  %r178 = load i32, ptr %v.idx
  %r177 = sext i32 %r178 to i64
  store i64 %r177, ptr %v.best
  br label %b6
b5:
  br label %b6
b6:
  %r180 = load i32, ptr %v.idx
  %r179 = add i32 %r180, 1
  store i32 %r179, ptr %v.idx
  br label %b1
b7:
  %r182 = load i32, ptr %v.idx
  %r183 = load i32, ptr %v.n
  %r181 = icmp slt i32 %r182, %r183
  br i1 %r181, label %b8, label %b9
b8:
  %r185 = load i32, ptr %v.idx
  %r184 = sext i32 %r185 to i64
  %r186 = load ptr, ptr %v.scores
  %r187 = getelementptr inbounds %zfy.seq, ptr %r186, i32 0, i32 2
  %r188 = load i64, ptr %r187
  %r189 = icmp ult i64 %r184, %r188
  br i1 %r189, label %L43, label %L44
L44:
  call void @zfy_bounds_fail()
  unreachable
L43:
  %r190 = load ptr, ptr %r186
  %r191 = mul i64 %r184, 4
  %r192 = getelementptr inbounds i8, ptr %r190, i64 %r191
  %r193 = load i32, ptr %r192, align 1
  %r194 = sext i32 %r193 to i128
  br label %L45
L45:
  %r195 = trunc i128 %r194 to i32
  %r196 = icmp sge i32 %r195, 60
  br i1 %r196, label %b10, label %b11
b9:
  %r197 = load ptr, ptr %v.passed
  %r198 = getelementptr inbounds %zfy.seq, ptr %r197, i32 0, i32 2
  %r199 = load i64, ptr %r198
  %r200 = trunc i64 %r199 to i32
  store i32 %r200, ptr %v.passed_count
  %r201 = getelementptr inbounds [15 x i8], ptr @.str25, i64 0, i64 0
  call void @zfy_print_str(ptr %r201)
  %r202 = getelementptr inbounds [1 x i8], ptr @.str26, i64 0, i64 0
  call void @zfy_print_str(ptr %r202)
  %r203 = load i32, ptr %v.passed_count
  %r204 = sext i32 %r203 to i64
  call void @zfy_print_i64(i64 %r204)
  %r205 = getelementptr inbounds [2 x i8], ptr @.str27, i64 0, i64 0
  call void @zfy_print_str(ptr %r205)
  %r206 = getelementptr inbounds [15 x i8], ptr @.str28, i64 0, i64 0
  call void @zfy_print_str(ptr %r206)
  %r207 = getelementptr inbounds [1 x i8], ptr @.str29, i64 0, i64 0
  call void @zfy_print_str(ptr %r207)
  store i32 0, ptr %v.idx
  br label %b13
b10:
  %r208 = load ptr, ptr %v.passed
  %r209 = getelementptr inbounds %zfy.seq, ptr %r208, i32 0, i32 2
  %r210 = load i64, ptr %r209
  %r212 = load i32, ptr %v.idx
  %r211 = sext i32 %r212 to i64
  %r213 = load ptr, ptr %v.scores
  %r214 = getelementptr inbounds %zfy.seq, ptr %r213, i32 0, i32 2
  %r215 = load i64, ptr %r214
  %r216 = icmp ult i64 %r211, %r215
  br i1 %r216, label %L46, label %L47
L47:
  call void @zfy_bounds_fail()
  unreachable
L46:
  %r217 = load ptr, ptr %r213
  %r218 = mul i64 %r211, 4
  %r219 = getelementptr inbounds i8, ptr %r217, i64 %r218
  %r220 = load i32, ptr %r219, align 1
  %r221 = sext i32 %r220 to i128
  br label %L48
L48:
  %r222 = trunc i128 %r221 to i32
  %r223 = load ptr, ptr %v.passed
  %r224 = sext i32 %r222 to i128
  store i128 %r224, ptr %r225
  call void @zfy_seq_set_w(ptr %r223, i64 %r210, ptr %r225, i32 4, i8 1)
  br label %b12
b11:
  br label %b12
b12:
  %r227 = load i32, ptr %v.idx
  %r226 = add i32 %r227, 1
  store i32 %r226, ptr %v.idx
  br label %b7
b13:
  %r229 = load i32, ptr %v.idx
  %r230 = load i32, ptr %v.passed_count
  %r228 = icmp slt i32 %r229, %r230
  br i1 %r228, label %b14, label %b15
b14:
  %r232 = load i32, ptr %v.idx
  %r231 = sext i32 %r232 to i64
  %r233 = load ptr, ptr %v.passed
  %r234 = getelementptr inbounds %zfy.seq, ptr %r233, i32 0, i32 2
  %r235 = load i64, ptr %r234
  %r236 = icmp ult i64 %r231, %r235
  br i1 %r236, label %L49, label %L50
L50:
  call void @zfy_bounds_fail()
  unreachable
L49:
  %r237 = load ptr, ptr %r233
  %r238 = mul i64 %r231, 4
  %r239 = getelementptr inbounds i8, ptr %r237, i64 %r238
  %r240 = load i32, ptr %r239, align 1
  %r241 = sext i32 %r240 to i128
  br label %L51
L51:
  %r242 = trunc i128 %r241 to i32
  %r243 = sext i32 %r242 to i64
  call void @zfy_print_i64(i64 %r243)
  %r244 = getelementptr inbounds [1 x i8], ptr @.str30, i64 0, i64 0
  call void @zfy_print_str(ptr %r244)
  %r246 = load i32, ptr %v.idx
  %r245 = add i32 %r246, 1
  store i32 %r245, ptr %v.idx
  br label %b13
b15:
  %r247 = getelementptr inbounds [1 x i8], ptr @.str31, i64 0, i64 0
  call void @zfy_print_str(ptr %r247)
  %r248 = getelementptr inbounds [2 x i8], ptr @.str32, i64 0, i64 0
  call void @zfy_print_str(ptr %r248)
  %r250 = getelementptr inbounds %frac.i32, ptr %r249, i32 0, i32 0
  %r251 = load i32, ptr %v.passed_count
  store i32 %r251, ptr %r250
  %r252 = getelementptr inbounds %frac.i32, ptr %r249, i32 0, i32 1
  %r253 = load i32, ptr %v.n
  store i32 %r253, ptr %r252
  call void @llvm.memcpy.p0.p0.i64(ptr %v.pass_rate, ptr %r249, i64 8, i1 false)
  call void @zfy_frac_norm_i32(ptr %v.pass_rate)
  %r254 = getelementptr inbounds [20 x i8], ptr @.str33, i64 0, i64 0
  call void @zfy_print_str(ptr %r254)
  %r255 = getelementptr inbounds [1 x i8], ptr @.str34, i64 0, i64 0
  call void @zfy_print_str(ptr %r255)
  call void @zfy_frac_print_i32(ptr %v.pass_rate)
  %r256 = getelementptr inbounds [2 x i8], ptr @.str35, i64 0, i64 0
  call void @zfy_print_str(ptr %r256)
  %r257 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r257)
  %r258 = getelementptr inbounds [10 x i8], ptr @.str36, i64 0, i64 0
  %r259 = call ptr @zfy_strdup(ptr %r258)
  store ptr %r259, ptr %v.s
  %r260 = add i64 2, 0
  %r261 = load ptr, ptr %v.s
  %t44 = call i64 @zfy_str_find(ptr %r261, i8 108, i64 %r260)
  %r262 = add i64 %t44, 0
  store i64 %r262, ptr %v.pos
  %r263 = getelementptr inbounds [24 x i8], ptr @.str37, i64 0, i64 0
  call void @zfy_print_str(ptr %r263)
  %r264 = getelementptr inbounds [1 x i8], ptr @.str38, i64 0, i64 0
  call void @zfy_print_str(ptr %r264)
  %r265 = load i64, ptr %v.pos
  call void @zfy_print_i64(i64 %r265)
  %r266 = getelementptr inbounds [2 x i8], ptr @.str39, i64 0, i64 0
  call void @zfy_print_str(ptr %r266)
  %r267 = add i64 0, 0
  %r268 = add i64 4, 0
  %r269 = load ptr, ptr %v.s
  %r270 = getelementptr inbounds [6 x i8], ptr @.str40, i64 0, i64 0
  %t48 = call ptr @zfy_str_replace(ptr %r269, i64 %r267, i64 %r268, ptr %r270)
  %r271 = load ptr, ptr %v.replaced
  call void @zfy_free_str(ptr %r271)
  %r272 = call ptr @zfy_strdup(ptr %t48)
  store ptr %r272, ptr %v.replaced
  call void @zfy_free_str(ptr %t48)
  %r273 = getelementptr inbounds [12 x i8], ptr @.str41, i64 0, i64 0
  call void @zfy_print_str(ptr %r273)
  %r274 = getelementptr inbounds [1 x i8], ptr @.str42, i64 0, i64 0
  call void @zfy_print_str(ptr %r274)
  %r275 = load ptr, ptr %v.replaced
  call void @zfy_print_str(ptr %r275)
  %r276 = getelementptr inbounds [2 x i8], ptr @.str43, i64 0, i64 0
  call void @zfy_print_str(ptr %r276)
  store i64 123456, ptr %v.big
  %r278 = load i64, ptr %v.big
  %r277 = trunc i64 %r278 to i32
  store i32 %r277, ptr %v.small
  %r280 = load i32, ptr %v.small
  %r279 = sitofp i32 %r280 to float
  store float %r279, ptr %v.f
  %r281 = getelementptr inbounds [12 x i8], ptr @.str44, i64 0, i64 0
  call void @zfy_print_str(ptr %r281)
  %r282 = getelementptr inbounds [1 x i8], ptr @.str45, i64 0, i64 0
  call void @zfy_print_str(ptr %r282)
  %r283 = load i32, ptr %v.small
  %r284 = sext i32 %r283 to i64
  call void @zfy_print_i64(i64 %r284)
  %r285 = getelementptr inbounds [1 x i8], ptr @.str46, i64 0, i64 0
  call void @zfy_print_str(ptr %r285)
  %r286 = getelementptr inbounds [13 x i8], ptr @.str47, i64 0, i64 0
  call void @zfy_print_str(ptr %r286)
  %r287 = getelementptr inbounds [1 x i8], ptr @.str48, i64 0, i64 0
  call void @zfy_print_str(ptr %r287)
  %r288 = load float, ptr %v.f
  %r289 = fpext float %r288 to double
  call void @zfy_print_f64(double %r289)
  %r290 = getelementptr inbounds [2 x i8], ptr @.str49, i64 0, i64 0
  call void @zfy_print_str(ptr %r290)
  %r291 = add i64 8, 0
  %r292 = add i64 12, 0
  %r294 = getelementptr inbounds %frac.i64, ptr %r293, i32 0, i32 0
  store i64 %r291, ptr %r294
  %r295 = getelementptr inbounds %frac.i64, ptr %r293, i32 0, i32 1
  store i64 %r292, ptr %r295
  call void @llvm.memcpy.p0.p0.i64(ptr %v.r, ptr %r293, i64 16, i1 false)
  call void @zfy_frac_norm_i64(ptr %v.r)
  %r296 = add i64 1, 0
  %r297 = add i64 2, 0
  call void @zfy_frac_reduce_i64(ptr %v.r, i64 %r296, i64 %r297)
  %r298 = getelementptr inbounds [12 x i8], ptr @.str50, i64 0, i64 0
  call void @zfy_print_str(ptr %r298)
  %r299 = getelementptr inbounds [1 x i8], ptr @.str51, i64 0, i64 0
  call void @zfy_print_str(ptr %r299)
  call void @zfy_frac_print_i64(ptr %v.r)
  %r300 = getelementptr inbounds [2 x i8], ptr @.str52, i64 0, i64 0
  call void @zfy_print_str(ptr %r300)
  %r302 = load i32, ptr %v.passed_count
  %r301 = icmp sgt i32 %r302, 0
  br i1 %r301, label %b16, label %b17
b16:
  %r303 = add i64 0, 0
  %r304 = load ptr, ptr %v.passed
  call void @zfy_seq_remove(ptr %r304, i64 %r303, i8 0)
  %r305 = load ptr, ptr %v.passed
  %r306 = getelementptr inbounds %zfy.seq, ptr %r305, i32 0, i32 2
  %r307 = load i64, ptr %r306
  %r308 = trunc i64 %r307 to i32
  store i32 %r308, ptr %v.passed_count
  %r309 = getelementptr inbounds [42 x i8], ptr @.str53, i64 0, i64 0
  call void @zfy_print_str(ptr %r309)
  %r310 = getelementptr inbounds [1 x i8], ptr @.str54, i64 0, i64 0
  call void @zfy_print_str(ptr %r310)
  %r311 = load i32, ptr %v.passed_count
  %r312 = sext i32 %r311 to i64
  call void @zfy_print_i64(i64 %r312)
  %r313 = getelementptr inbounds [2 x i8], ptr @.str55, i64 0, i64 0
  call void @zfy_print_str(ptr %r313)
  br label %b18
b17:
  br label %b18
b18:
  %r314 = getelementptr inbounds [12 x i8], ptr @.str56, i64 0, i64 0
  call void @zfy_print_str(ptr %r314)
  %r315 = getelementptr inbounds [1 x i8], ptr @.str57, i64 0, i64 0
  call void @zfy_print_str(ptr %r315)
  store i32 5, ptr %v.t
  br label %b19
b19:
  %r317 = load i32, ptr %v.t
  %r316 = icmp sgt i32 %r317, 0
  br i1 %r316, label %b20, label %b21
b20:
  %r318 = load i32, ptr %v.t
  %r319 = sext i32 %r318 to i64
  call void @zfy_print_i64(i64 %r319)
  %r320 = getelementptr inbounds [1 x i8], ptr @.str58, i64 0, i64 0
  call void @zfy_print_str(ptr %r320)
  %r322 = load i32, ptr %v.t
  %r321 = sub i32 %r322, 1
  store i32 %r321, ptr %v.t
  br label %b19
b21:
  %r323 = getelementptr inbounds [1 x i8], ptr @.str59, i64 0, i64 0
  call void @zfy_print_str(ptr %r323)
  %r324 = getelementptr inbounds [2 x i8], ptr @.str60, i64 0, i64 0
  call void @zfy_print_str(ptr %r324)
  store i32 0, ptr %v.k2
  store i64 0, ptr %v.acc
  br label %b22
b22:
  %r326 = load i32, ptr %v.k2
  %r325 = icmp slt i32 %r326, 10
  br i1 %r325, label %b23, label %b24
b23:
  %r328 = load i32, ptr %v.k2
  %r327 = sext i32 %r328 to i64
  %r330 = load i64, ptr %v.acc
  %r329 = add i64 %r330, %r327
  store i64 %r329, ptr %v.acc
  %r332 = load i32, ptr %v.k2
  %r331 = add i32 %r332, 1
  store i32 %r331, ptr %v.k2
  br label %b22
b24:
  %r333 = getelementptr inbounds [17 x i8], ptr @.str61, i64 0, i64 0
  call void @zfy_print_str(ptr %r333)
  %r334 = getelementptr inbounds [1 x i8], ptr @.str62, i64 0, i64 0
  call void @zfy_print_str(ptr %r334)
  %r335 = load i64, ptr %v.acc
  call void @zfy_print_i64(i64 %r335)
  %r336 = getelementptr inbounds [2 x i8], ptr @.str63, i64 0, i64 0
  call void @zfy_print_str(ptr %r336)
  %r337 = add i64 100, 0
  %r339 = load i64, ptr %v.acc
  %r338 = icmp sgt i64 %r339, %r337
  br i1 %r338, label %b25, label %b26
b25:
  %r340 = getelementptr inbounds [20 x i8], ptr @.str64, i64 0, i64 0
  call void @zfy_print_str(ptr %r340)
  %r341 = getelementptr inbounds [2 x i8], ptr @.str65, i64 0, i64 0
  call void @zfy_print_str(ptr %r341)
  br label %b27
b26:
  %r342 = add i64 45, 0
  %r344 = load i64, ptr %v.acc
  %r343 = icmp eq i64 %r344, %r342
  br i1 %r343, label %b28, label %b29
b27:
  %r345 = load ptr, ptr %v.replaced
  call void @zfy_free_str(ptr %r345)
  store ptr null, ptr %v.replaced
  %r346 = load ptr, ptr %v.s
  call void @zfy_free_str(ptr %r346)
  store ptr null, ptr %v.s
  %r347 = load ptr, ptr %v.passed
  call void @zfy_seq_free(ptr %r347, i8 0)
  store ptr null, ptr %v.passed
  %r348 = load ptr, ptr %v.report
  call void @zfy_free_str(ptr %r348)
  store ptr null, ptr %v.report
  %r349 = load ptr, ptr %v.name
  call void @zfy_free_str(ptr %r349)
  store ptr null, ptr %v.name
  %r350 = load ptr, ptr %v.scores
  call void @zfy_seq_free(ptr %r350, i8 0)
  store ptr null, ptr %v.scores
  ret void
b28:
  %r351 = getelementptr inbounds [19 x i8], ptr @.str66, i64 0, i64 0
  call void @zfy_print_str(ptr %r351)
  %r352 = getelementptr inbounds [2 x i8], ptr @.str67, i64 0, i64 0
  call void @zfy_print_str(ptr %r352)
  br label %b30
b29:
  %r353 = getelementptr inbounds [14 x i8], ptr @.str68, i64 0, i64 0
  call void @zfy_print_str(ptr %r353)
  %r354 = getelementptr inbounds [1 x i8], ptr @.str69, i64 0, i64 0
  call void @zfy_print_str(ptr %r354)
  %r355 = load i64, ptr %v.acc
  call void @zfy_print_i64(i64 %r355)
  %r356 = getelementptr inbounds [2 x i8], ptr @.str70, i64 0, i64 0
  call void @zfy_print_str(ptr %r356)
  br label %b30
b30:
  br label %b27
}
define i32 @main() {
  call void @zfy.main()
  ret i32 0
}
