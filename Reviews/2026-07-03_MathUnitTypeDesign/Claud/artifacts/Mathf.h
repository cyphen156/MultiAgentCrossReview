#pragma once

#include <cmath>

// ============================================================================
// Mathf
// ----------------------------------------------------------------------------
// float 기반 스칼라 수학 유틸리티입니다.
//
// Unity Mathf 모델을 따라 월드 수학의 기본 스칼라 연산을 float로 고정합니다.
// 좌표/벡터 타입은 이 클래스에 넣지 않고 별도 값 타입으로 둡니다.
// ============================================================================

class Mathf final
{
public:
	static constexpr float Pi = 3.14159265358979323846f;
	static constexpr float HalfPi = Pi * 0.5f;
	static constexpr float TwoPi = Pi * 2.0f;
	static constexpr float DegToRad = Pi / 180.0f;
	static constexpr float RadToDeg = 180.0f / Pi;
	static constexpr float Epsilon = 0.000001f;

	static float Abs(float value)
	{
		return std::fabs(value);
	}

	static float Min(float left, float right)
	{
		return left < right ? left : right;
	}

	static float Max(float left, float right)
	{
		return left > right ? left : right;
	}

	static float Clamp(float value, float min, float max)
	{
		if (value < min)
		{
			return min;
		}

		if (value > max)
		{
			return max;
		}

		return value;
	}

	static float Saturate(float value)
	{
		return Clamp(value, 0.0f, 1.0f);
	}

	static float Lerp(float from, float to, float t)
	{
		return from + (to - from) * t;
	}

	static float Sqrt(float value)
	{
		return std::sqrt(value);
	}

	static float Sin(float radians)
	{
		return std::sin(radians);
	}

	static float Cos(float radians)
	{
		return std::cos(radians);
	}

	static float Tan(float radians)
	{
		return std::tan(radians);
	}

	// y/x의 아크탄젠트를 라디안으로 돌려줍니다. 방향 벡터에서 각도를 구할 때 씁니다.
	static float Atan2(float y, float x)
	{
		return std::atan2(y, x);
	}

	static float Floor(float value)
	{
		return std::floor(value);
	}

	static float Ceil(float value)
	{
		return std::ceil(value);
	}

	static float Round(float value)
	{
		return std::round(value);
	}

	// 상대 허용오차 기반 근사 동등 비교입니다. 정확한 ==의 float 함정을 피할 때 씁니다.
	static bool Approximately(float left, float right)
	{
		return Abs(right - left) <= Epsilon * Max(1.0f, Max(Abs(left), Abs(right)));
	}

	static float ToRadians(float degrees)
	{
		return degrees * DegToRad;
	}

	static float ToDegrees(float radians)
	{
		return radians * RadToDeg;
	}

private:
	Mathf() = delete;
	~Mathf() = delete;

	Mathf(const Mathf& other) = delete;
	Mathf& operator=(const Mathf& other) = delete;

	Mathf(Mathf&& other) = delete;
	Mathf& operator=(Mathf&& other) = delete;
};
