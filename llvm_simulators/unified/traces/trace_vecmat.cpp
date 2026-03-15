// trace_vecmat.cpp -- C++ trace output for comparison with Prolog simulator
//
// Compile:
//   clang++ -O1 -std=c++17 trace_vecmat.cpp -o trace_vecmat -lm
//
// Run:
//   ./trace_vecmat
//
// Compare:
//   diff <(swipl -g "main,halt" traces/trace_vecmat.pl) <(./trace_vecmat)

#include <cstdio>
#include <cmath>

typedef double REAL;
static const REAL PI = atan(1.0) * 4.0;
static const REAL DEFAULT_EPSILON = 1e-5;

extern "C" {

int IsApproxEqual_double(double r1, double r2, double epsilon) {
    return (fabs(r1 - r2) < epsilon) ? 1 : 0;
}

double Gauss_double(double x, double s) {
    double d = (x * x) / (2.0 * s * s);
    return exp(-d) / sqrt(2.0 * PI * s);
}

double Gauss2D_double(double x, double y, double sx, double sy) {
    double d = (x * x) / (2.0 * sx * sx) + (y * y) / (2.0 * sy * sy);
    return exp(-d) / sqrt(2.0 * PI * sx * sy);
}

double dGauss2D_dx_double(double x, double y, double sx, double sy) {
    double dx = -(2.0 * x) / (2.0 * sx * sx);
    return dx * Gauss2D_double(x, y, sx, sy);
}

double dGauss2D_dy_double(double x, double y, double sx, double sy) {
    double dy = -(2.0 * y) / (2.0 * sy * sy);
    return dy * Gauss2D_double(x, y, sx, sy);
}

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

#define TRACE1(fn, a) printf("CALL " #fn "(%g) -> %g\n", (double)(a), (double)fn(a))
#define TRACE2(fn, a, b) printf("CALL " #fn "(%g, %g) -> %g\n", (double)(a), (double)(b), (double)fn(a, b))
#define TRACE3(fn, a, b, c) printf("CALL " #fn "(%g, %g, %g) -> %d\n", (double)(a), (double)(b), (double)(c), fn(a, b, c))
#define TRACE4(fn, a, b, c, d) printf("CALL " #fn "(%g, %g, %g, %g) -> %g\n", (double)(a), (double)(b), (double)(c), (double)(d), fn(a, b, c, d))

int main() {
    // IsApproxEqual
    TRACE3(IsApproxEqual_double, 1.0, 1.000001, 1e-5);
    TRACE3(IsApproxEqual_double, 1.0, 2.0, 1e-5);
    TRACE3(IsApproxEqual_double, 3.14, 3.14, 1e-5);

    // Gauss
    TRACE2(Gauss_double, 0.0, 1.0);
    TRACE2(Gauss_double, 1.0, 1.0);
    TRACE2(Gauss_double, -1.0, 1.0);
    TRACE2(Gauss_double, 0.0, 0.5);

    // Gauss2D
    TRACE4(Gauss2D_double, 0.0, 0.0, 1.0, 1.0);
    TRACE4(Gauss2D_double, 1.0, 1.0, 1.0, 1.0);
    TRACE4(Gauss2D_double, 0.0, 0.0, 2.0, 3.0);

    // dGauss2D_dx
    TRACE4(dGauss2D_dx_double, 0.0, 0.0, 1.0, 1.0);
    TRACE4(dGauss2D_dx_double, 1.0, 0.0, 1.0, 1.0);

    // dGauss2D_dy
    TRACE4(dGauss2D_dy_double, 0.0, 0.0, 1.0, 1.0);
    TRACE4(dGauss2D_dy_double, 0.0, 1.0, 1.0, 1.0);

    // AngleFromSinCos
    TRACE2(AngleFromSinCos_double, 0.0, 1.0);
    TRACE2(AngleFromSinCos_double, 1.0, 0.0);
    TRACE2(AngleFromSinCos_double, 0.0, -1.0);
    TRACE2(AngleFromSinCos_double, -1.0, 0.0);

    return 0;
}
