/*
 * Phoenix-RTOS
 *
 * libphoenix
 *
 * exp, frexp, ldexp, log, log10, modf, ceil, floor, fmod, fabs
 *
 * Copyright 2017 Phoenix Systems
 * Author: Aleksander Kaminski
 *
 * This file is part of Phoenix-RTOS.
 *
 * %LICENSE%
 */

#include <errno.h>
#include "consts.h"
#include "common.h"


double frexp(double x, int* exp)
{
	conv_t *conv = (conv_t *)&x;

	*exp = 0;

	if (x == 0.0)
		return 0.0;

	if (conv->i.exponent == 0)
		normalizeSub(&x, exp);

	*exp += conv->i.exponent - 1022;
	conv->i.exponent = 1022;

	return x;
}


double ldexp(double x, int exp)
{
	conv_t *conv = (conv_t *)&x;
	int exponent = 0;

	if (x == 0.0)
		return 0.0;

	if (conv->i.exponent == 0)
		normalizeSub(&x, &exponent);

	exponent += conv->i.exponent + exp;

	if (exponent > 2046) {
		errno = ERANGE;
		return conv->i.sign ? -HUGE_VAL : HUGE_VAL;
	}

	/* If result is subnormal */
	if (exponent < 0) {
		createSub(&x, exponent);
		conv->i.exponent = 0;
	}
	else {
		conv->i.exponent = exponent;
	}

	return x;
}


double log(double x)
{
	double tmp, pow, res;
	conv_t *conv = (conv_t *)&tmp;
	int exp = 0, i;

	if (x < 0) {
		errno = EDOM;
		return NAN;
	}
	else if (x == 0) {
		errno = ERANGE;
		return -HUGE_VAL;
	}
	else if (x == 1.0) {
		return 0.0;
	}

	tmp = x;

	exp = conv->i.exponent - 1022;

	if (conv->i.exponent == 0)
		normalizeSub(&tmp, &exp);

	conv->i.exponent = 1022;

	tmp -= 1.0;

	for (i = 1, res = 0, pow = tmp; i < 16; ++i, pow *= tmp) {
		if (i & 1)
			res += pow / i;
		else
			res -= pow / i;
	}

	return res + (exp / M_LOG2E);
}


/* Uses log10(x) = ln(x) / ln(10) identity */
double log10(double x)
{
	return log(x) / M_LN10;
}


double modf(double x, double* intpart)
{
	conv_t *conv = (conv_t *)&x;
	double tmp = x;
	int exp = conv->i.exponent - 1023;
	u64 m, mask = 0xfffffffffffffLL;

	if (exp > 52) {
		*intpart = x;
		return conv->i.sign? -0.0 : 0.0;
	}
	else if (exp < 0) {
		*intpart = conv->i.sign? -0.0 : 0.0;
		return x;
	}

	conv->i.mantisa = conv->i.mantisa & ~(mask >> exp);
	*intpart = x;
	x = tmp;

	m = conv->i.mantisa;
	m &= mask >> exp;

	if (m == 0) {
		return 0.0;
	}

	conv->i.mantisa = m & mask;
	normalizeSub(&x, &exp);

	conv->i.exponent = exp + 1023;

	return x;
}

float modff(float x, float* intpart)
{
	double ret, tmp;

	ret = modf(x, &tmp);
	*intpart = tmp;

	return ret;
}

/* Uses quick powering and Maclaurin series to calculate value of e^x */
double exp(double x)
{
	double res, resi, powx, e, strong;
	int i;

	if (x > 710.0)
		return HUGE_VAL;

	/* Get floor of exponent */
	x = modf(x, &e);

	/* Calculate most of the result */
	resi = quickPow(M_E, (int)e);

	/* Calculate rest of the result using Maclaurin series */
	strong = 1.0;
	powx = x;
	res = 1.0;

	for (i = 2; i < 13; ++i) {
		if (powx == 0.0)
			break;
		res += powx / strong;
		strong *= i;
		powx *= x;
	}

	return res * resi;
}


double ceil(double x)
{
	double tmp;

	x = modf(x, &tmp);

	if (x != 0.0)
		tmp += 1.0;

	return tmp;
}


double floor(double x)
{
	double tmp;

	modf(x, &tmp);

	return tmp;
}


double fmod(double numer, double denom)
{
	double result, tquot;

	if (denom == 0)
		return 0.0;

	modf(numer / denom, &tquot);
	result = tquot * denom;

	return numer - result;
}


double round(double x)
{
	double ret, frac;

	frac = modf(x, &ret);

	if (frac >= 0.5)
		ret += 1.0;
	else if (frac <= -0.5)
		ret -= 1.0;

	return ret;
}


double trunc(double x)
{
	double ret;

	modf(x, &ret);

	return ret;
}


double fabs(double x)
{
	conv_t *conv = (conv_t *)&x;

	conv->i.sign = 0;

	return x;
}
