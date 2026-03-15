// mathutil_wrapper.cpp -- Wrapper to generate LLVM IR for MathUtil.h functions
//
// Compile with:
//   clang -S -emit-llvm -O1 -std=c++17 -I E:/github_dg1an3/dH/VecMat mathutil_wrapper.cpp -o mathutil.ll
//
// We use -O1 to eliminate redundant alloca/load/store from -O0 while keeping
// the code structure readable. Functions are marked noinline to prevent
// inlining so each function appears as a separate define in the IR.

#include <cmath>

// Inline the relevant parts of MathUtil.h to avoid BOOL/Windows dependencies
typedef double REAL;
const REAL PI = (atan(1.0) * 4.0);
const REAL DEFAULT_EPSILON = 1e-5;

// Force template instantiations as non-inlined functions via extern "C"
// so they get clean export names in the LLVM IR.

extern "C" {

__attribute__((noinline))
int IsApproxEqual_double(double r1, double r2, double epsilon) {
    return (fabs(r1 - r2) < epsilon) ? 1 : 0;
}

__attribute__((noinline))
double Gauss_double(double x, double s) {
    double d = (x * x) / (2.0 * s * s);
    return exp(-d) / sqrt(2.0 * PI * s);
}

__attribute__((noinline))
double Gauss2D_double(double x, double y, double sx, double sy) {
    double d = (x * x) / (2.0 * sx * sx)
             + (y * y) / (2.0 * sy * sy);
    return exp(-d) / sqrt(2.0 * PI * sx * sy);
}

__attribute__((noinline))
double dGauss2D_dx_double(double x, double y, double sx, double sy) {
    double dx = -(2.0 * x) / (2.0 * sx * sx);
    return dx * Gauss2D_double(x, y, sx, sy);
}

__attribute__((noinline))
double dGauss2D_dy_double(double x, double y, double sx, double sy) {
    double dy = -(2.0 * y) / (2.0 * sy * sy);
    return dy * Gauss2D_double(x, y, sx, sy);
}

__attribute__((noinline))
double AngleFromSinCos_double(double sin_angle, double cos_angle) {
    double angle = 0.0;
    const double TWO_PI = 2.0 * PI;

    if (sin_angle >= 0.0) {
        angle = acos(cos_angle);
    } else if (cos_angle >= 0.0) {
        angle = asin(sin_angle);
    } else {
        angle = TWO_PI - acos(cos_angle);
    }

    if (angle < 0.0) {
        angle += TWO_PI;
    }

    return angle;
}

} // extern "C"
