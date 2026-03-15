; ModuleID = 'mathutil_wrapper.cpp'
source_filename = "mathutil_wrapper.cpp"
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.44.35223"

@llvm.global_ctors = appending global [0 x { i32, ptr, ptr }] zeroinitializer

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i32 0, 2) i32 @IsApproxEqual_double(double noundef %0, double noundef %1, double noundef %2) local_unnamed_addr #0 {
  %4 = fsub double %0, %1
  %5 = tail call double @llvm.fabs.f64(double %4)
  %6 = fcmp olt double %5, %2
  %7 = zext i1 %6 to i32
  ret i32 %7
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.fabs.f64(double) #1

; Function Attrs: mustprogress nofree noinline norecurse nounwind willreturn memory(errnomem: write) uwtable
define dso_local double @Gauss_double(double noundef %0, double noundef %1) local_unnamed_addr #2 {
  %3 = fmul double %1, 2.000000e+00
  %4 = fmul double %1, %3
  %5 = fneg double %0
  %6 = fmul double %0, %5
  %7 = fdiv double %6, %4
  %8 = tail call double @exp(double noundef %7) #4
  %9 = fmul double %1, 0x401921FB54442D18
  %10 = tail call double @sqrt(double noundef %9) #4
  %11 = fdiv double %8, %10
  ret double %11
}

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(errnomem: write)
declare dso_local double @exp(double noundef) local_unnamed_addr #3

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(errnomem: write)
declare dso_local double @sqrt(double noundef) local_unnamed_addr #3

; Function Attrs: mustprogress nofree noinline norecurse nounwind willreturn memory(errnomem: write) uwtable
define dso_local double @Gauss2D_double(double noundef %0, double noundef %1, double noundef %2, double noundef %3) local_unnamed_addr #2 {
  %5 = fmul double %0, %0
  %6 = fmul double %2, 2.000000e+00
  %7 = fmul double %2, %6
  %8 = fdiv double %5, %7
  %9 = fmul double %1, %1
  %10 = fmul double %3, 2.000000e+00
  %11 = fmul double %3, %10
  %12 = fdiv double %9, %11
  %13 = fadd double %8, %12
  %14 = fneg double %13
  %15 = tail call double @exp(double noundef %14) #4
  %16 = fmul double %2, 0x401921FB54442D18
  %17 = fmul double %16, %3
  %18 = tail call double @sqrt(double noundef %17) #4
  %19 = fdiv double %15, %18
  ret double %19
}

; Function Attrs: mustprogress nofree noinline norecurse nounwind willreturn memory(errnomem: write) uwtable
define dso_local double @dGauss2D_dx_double(double noundef %0, double noundef %1, double noundef %2, double noundef %3) local_unnamed_addr #2 {
  %5 = fmul double %0, -2.000000e+00
  %6 = fmul double %2, 2.000000e+00
  %7 = fmul double %2, %6
  %8 = fdiv double %5, %7
  %9 = tail call double @Gauss2D_double(double noundef %0, double noundef %1, double noundef %2, double noundef %3)
  %10 = fmul double %8, %9
  ret double %10
}

; Function Attrs: mustprogress nofree noinline norecurse nounwind willreturn memory(errnomem: write) uwtable
define dso_local double @dGauss2D_dy_double(double noundef %0, double noundef %1, double noundef %2, double noundef %3) local_unnamed_addr #2 {
  %5 = fmul double %1, -2.000000e+00
  %6 = fmul double %3, 2.000000e+00
  %7 = fmul double %3, %6
  %8 = fdiv double %5, %7
  %9 = tail call double @Gauss2D_double(double noundef %0, double noundef %1, double noundef %2, double noundef %3)
  %10 = fmul double %8, %9
  ret double %10
}

; Function Attrs: mustprogress nofree noinline norecurse nounwind willreturn memory(errnomem: write) uwtable
define dso_local double @AngleFromSinCos_double(double noundef %0, double noundef %1) local_unnamed_addr #2 {
  %3 = fcmp ult double %0, 0.000000e+00
  br i1 %3, label %6, label %4

4:                                                ; preds = %2
  %5 = tail call double @acos(double noundef %1) #4
  br label %13

6:                                                ; preds = %2
  %7 = fcmp ult double %1, 0.000000e+00
  br i1 %7, label %10, label %8

8:                                                ; preds = %6
  %9 = tail call double @asin(double noundef %0) #4
  br label %13

10:                                               ; preds = %6
  %11 = tail call double @acos(double noundef %1) #4
  %12 = fsub double 0x401921FB54442D18, %11
  br label %13

13:                                               ; preds = %8, %10, %4
  %14 = phi double [ %5, %4 ], [ %9, %8 ], [ %12, %10 ]
  %15 = fcmp olt double %14, 0.000000e+00
  %16 = fadd double %14, 0x401921FB54442D18
  %17 = select i1 %15, double %16, double %14
  ret double %17
}

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(errnomem: write)
declare dso_local double @acos(double noundef) local_unnamed_addr #3

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(errnomem: write)
declare dso_local double @asin(double noundef) local_unnamed_addr #3

attributes #0 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { mustprogress nofree noinline norecurse nounwind willreturn memory(errnomem: write) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #3 = { mustprogress nocallback nofree nounwind willreturn memory(errnomem: write) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { nounwind }

!llvm.dbg.cu = !{!0}
!llvm.linker.options = !{!2, !3, !4, !5}
!llvm.module.flags = !{!6, !7, !8, !9, !10}
!llvm.ident = !{!11}

!0 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus_14, file: !1, producer: "clang version 21.1.8", isOptimized: true, runtimeVersion: 0, emissionKind: NoDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "mathutil_wrapper.cpp", directory: "D:\\MUSIQ\\ALGT\\llvm_simulators\\unified\\samples")
!2 = !{!"/FAILIFMISMATCH:\22_MSC_VER=1900\22"}
!3 = !{!"/FAILIFMISMATCH:\22_ITERATOR_DEBUG_LEVEL=0\22"}
!4 = !{!"/FAILIFMISMATCH:\22RuntimeLibrary=MT_StaticRelease\22"}
!5 = !{!"/DEFAULTLIB:libcpmt.lib"}
!6 = !{i32 2, !"Debug Info Version", i32 3}
!7 = !{i32 1, !"wchar_size", i32 2}
!8 = !{i32 8, !"PIC Level", i32 2}
!9 = !{i32 7, !"uwtable", i32 2}
!10 = !{i32 1, !"MaxTLSAlign", i32 65536}
!11 = !{!"clang version 21.1.8"}
