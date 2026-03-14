; Simple test functions for Phase 1 LLVM IR simulator

define double @add(double %a, double %b) {
entry:
  %result = fadd double %a, %b
  ret double %result
}

define double @multiply(double %a, double %b) {
entry:
  %result = fmul double %a, %b
  ret double %result
}

define double @quadratic(double %x) {
entry:
  %x2 = fmul double %x, %x
  %term1 = fmul double 3.0, %x2
  %term2 = fmul double 2.0, %x
  %sum1 = fadd double %term1, %term2
  %result = fadd double %sum1, 1.0
  ret double %result
}

define i32 @abs_i32(i32 %x) {
entry:
  %is_neg = icmp slt i32 %x, 0
  br i1 %is_neg, label %negate, label %done

negate:
  %neg = sub i32 0, %x
  br label %done

done:
  %result = phi i32 [ %neg, %negate ], [ %x, %entry ]
  ret i32 %result
}

define double @max_double(double %a, double %b) {
entry:
  %cmp = fcmp ogt double %a, %b
  %result = select i1 %cmp, double %a, double %b
  ret double %result
}

declare double @sqrt(double)

define double @distance(double %x, double %y) {
entry:
  %x2 = fmul double %x, %x
  %y2 = fmul double %y, %y
  %sum = fadd double %x2, %y2
  %result = call double @sqrt(double %sum)
  ret double %result
}

define i32 @factorial(i32 %n) {
entry:
  %cmp = icmp sle i32 %n, 1
  br i1 %cmp, label %base, label %recurse

base:
  ret i32 1

recurse:
  %n_minus_1 = sub i32 %n, 1
  %sub_result = call i32 @factorial(i32 %n_minus_1)
  %result = mul i32 %n, %sub_result
  ret i32 %result
}
